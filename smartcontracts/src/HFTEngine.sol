// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title HFTEngine — High-Frequency Trading engine based on the GLTE formula
/// @notice Implements the Global Liquidity Transformation Equation (GLTE):
///         L_out = (W_t / E[L_in]) × (r_cc × OICD) + [B_Tirana + (F_Tadawul × σ_VIX(Oil))] × γ
///
///         Where:
///         W_t         = Weighted global capital allocation
///         E[L_in]     = Expected liquidity inflow (chi * rate)
///         r_cc        = Cross-currency rate
///         OICD        = OICD liquidity basket value
///         B_Tirana    = Tirana Exchange base liquidity
///         F_Tadawul   = Tadawul FX factor
///         σ_VIX(Oil)  = VIX-adjusted oil volatility
///         γ           = Global gamma multiplier (risk coefficient)
contract HFTEngine is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    enum OrderType   { Market, Limit, StopLoss, GLTE }
    enum OrderStatus { Open, Filled, PartialFill, Cancelled, Expired }
    enum Direction   { Buy, Sell }

    struct GLTEParameters {
        uint256 W_t;          // Weighted capital (1e18 scale)
        uint256 chi;          // χ — liquidity multiplier (1e18)
        uint256 r_jcp;        // jcp rate component (1e18)
        uint256 r_cc;         // cross-currency rate (1e18)
        uint256 OICD;         // OICD basket value (1e18)
        uint256 B_Tirana;     // Tirana exchange base (1e18)
        uint256 F_Tadawul;    // Tadawul FX factor (1e18)
        uint256 sigma_VIX;    // σ_VIX(Oil) volatility (1e18)
        uint256 gamma;        // γ risk coefficient (1e18)
        uint256 updatedAt;
    }

    struct Order {
        uint256 orderId;
        OrderType orderType;
        OrderStatus status;
        Direction direction;
        address trader;
        string  baseCurrency;
        string  quoteCurrency;
        uint256 quantity;           // in wei units
        uint256 limitPrice;         // 0 for market orders (1e18 scale)
        uint256 stopPrice;          // for stop-loss orders
        uint256 glteTargetL_out;    // computed GLTE output target
        uint256 filledQuantity;
        uint256 avgFillPrice;
        uint256 createdAt;
        uint256 expiryTime;
        bool    useGLTE;            // execute when GLTE signal triggers
    }

    struct GLTESignal {
        uint256 timestamp;
        uint256 L_in;   // computed inflow
        uint256 L_out;  // computed outflow / target
        bool    bullish; // L_out > L_in → buy signal
        uint256 strength; // 0-100
    }

    struct TraderStats {
        uint256 totalOrders;
        uint256 filledOrders;
        uint256 totalVolume;
        uint256 pnl;         // cumulative (can be negative encoded as 0 with separate flag)
        uint256 lastActivity;
    }

    uint256 public orderCounter;
    uint256 public totalOrdersProcessed;
    uint256 public totalVolumeTraded;
    uint256 public signalCounter;

    GLTEParameters public glteParams;
    GLTESignal public latestSignal;

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public traderOrders;
    mapping(address => TraderStats) public traderStats;

    // Authorized executors (keepers / relayers)
    mapping(address => bool) public authorizedExecutors;

    event GLTEParametersUpdated(uint256 W_t, uint256 gamma, uint256 updatedAt);
    event GLTESignalEmitted(uint256 indexed signalId, uint256 L_in, uint256 L_out, bool bullish, uint256 strength);
    event OrderPlaced(uint256 indexed orderId, address indexed trader, OrderType orderType, Direction direction, string pair, uint256 quantity);
    event OrderFilled(uint256 indexed orderId, uint256 fillPrice, uint256 quantity);
    event OrderCancelled(uint256 indexed orderId, address by);
    event ArbitrageExecuted(address indexed executor, string pair, uint256 profit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        // Set default GLTE parameters (all scaled 1e18)
        glteParams = GLTEParameters({
            W_t:       1_000_000 * 1e18,  // $1M weighted capital
            chi:       1_000 * 1e18,       // χ multiplier
            r_jcp:     38 * 1e16,          // 38% jcp weight
            r_cc:      1_0 * 1e17,         // 1.0 cross-currency
            OICD:      197 * 1e18,         // OICD basket
            B_Tirana:  500_000 * 1e18,     // Tirana base
            F_Tadawul: 1_2 * 1e17,         // 1.2x Tadawul factor
            sigma_VIX: 25 * 1e16,          // 25% VIX oil vol
            gamma:     1_05 * 1e16,        // γ = 1.05
            updatedAt: block.timestamp
        });
    }

    // ─── GLTE COMPUTATION ─────────────────────────────────────────────────────

    /// @notice Computes GLTE output using the sovereign liquidity equation
    /// @return L_in  Expected inflow
    /// @return L_out Transformed outflow target
    function computeGLTE() public view returns (uint256 L_in, uint256 L_out) {
        GLTEParameters memory p = glteParams;

        // L_in = W_g × χ(r_jcp) — simplified: W_t × chi × r_jcp / 1e18
        L_in = (p.W_t * p.chi / 1e18) * p.r_jcp / 1e18;

        // r_cc × OICD
        uint256 rccOICD = p.r_cc * p.OICD / 1e18;

        // F_Tadawul × σ_VIX(Oil)
        uint256 tadawulVIX = p.F_Tadawul * p.sigma_VIX / 1e18;

        // [B_Tirana + (F_Tadawul × σ_VIX(Oil))]
        uint256 bracket = p.B_Tirana + tadawulVIX;

        // L_out = (W_t / E[L_in]) × rccOICD + bracket × γ
        uint256 W_over_Lin = L_in > 0 ? (p.W_t * 1e18 / L_in) : 1e18;
        L_out = (W_over_Lin * rccOICD / 1e18) + (bracket * p.gamma / 1e18);
    }

    // ─── EMIT SIGNAL ──────────────────────────────────────────────────────────

    function emitGLTESignal() external returns (uint256 signalId) {
        require(authorizedExecutors[msg.sender] || msg.sender == owner(), "Not authorised");

        (uint256 L_in, uint256 L_out) = computeGLTE();
        bool bullish = L_out > L_in;
        uint256 strength;
        if (L_in > 0) {
            uint256 delta = bullish ? ((L_out - L_in) * 100 / L_in) : ((L_in - L_out) * 100 / L_in);
            strength = delta > 100 ? 100 : delta;
        }

        signalId = ++signalCounter;
        latestSignal = GLTESignal({
            timestamp: block.timestamp,
            L_in: L_in,
            L_out: L_out,
            bullish: bullish,
            strength: strength
        });

        emit GLTESignalEmitted(signalId, L_in, L_out, bullish, strength);
    }

    // ─── PLACE ORDER ──────────────────────────────────────────────────────────

    function placeOrder(
        OrderType orderType,
        Direction direction,
        string calldata baseCurrency,
        string calldata quoteCurrency,
        uint256 quantity,
        uint256 limitPrice,
        uint256 stopPrice,
        uint256 expirySeconds,
        bool useGLTE
    ) external nonReentrant returns (uint256 orderId) {
        require(quantity > 0, "Quantity required");

        (uint256 L_in, uint256 L_out) = useGLTE ? computeGLTE() : (0, 0);

        orderId = ++orderCounter;
        orders[orderId] = Order({
            orderId: orderId,
            orderType: orderType,
            status: OrderStatus.Open,
            direction: direction,
            trader: msg.sender,
            baseCurrency: baseCurrency,
            quoteCurrency: quoteCurrency,
            quantity: quantity,
            limitPrice: limitPrice,
            stopPrice: stopPrice,
            glteTargetL_out: L_out,
            filledQuantity: 0,
            avgFillPrice: 0,
            createdAt: block.timestamp,
            expiryTime: expirySeconds > 0 ? block.timestamp + expirySeconds : type(uint256).max,
            useGLTE: useGLTE
        });

        traderOrders[msg.sender].push(orderId);
        TraderStats storage ts = traderStats[msg.sender];
        ts.totalOrders++;
        ts.lastActivity = block.timestamp;

        emit OrderPlaced(orderId, msg.sender, orderType, direction, string(abi.encodePacked(baseCurrency, "/", quoteCurrency)), quantity);
    }

    // ─── FILL ORDER (keeper) ──────────────────────────────────────────────────

    function fillOrder(uint256 orderId, uint256 fillPrice, uint256 fillQuantity) external {
        require(authorizedExecutors[msg.sender] || msg.sender == owner(), "Not authorised");

        Order storage o = orders[orderId];
        require(o.status == OrderStatus.Open || o.status == OrderStatus.PartialFill, "Not fillable");
        require(block.timestamp <= o.expiryTime, "Expired");
        require(fillQuantity <= o.quantity - o.filledQuantity, "Over-fill");

        // Weighted average fill price
        uint256 prevFilled = o.filledQuantity;
        o.filledQuantity += fillQuantity;
        o.avgFillPrice = ((prevFilled * o.avgFillPrice) + (fillQuantity * fillPrice)) / o.filledQuantity;

        if (o.filledQuantity >= o.quantity) {
            o.status = OrderStatus.Filled;
        } else {
            o.status = OrderStatus.PartialFill;
        }

        TraderStats storage ts = traderStats[o.trader];
        ts.filledOrders++;
        ts.totalVolume += fillQuantity * fillPrice / 1e18;
        totalVolumeTraded += fillQuantity;
        totalOrdersProcessed++;

        emit OrderFilled(orderId, fillPrice, fillQuantity);
    }

    // ─── CANCEL ORDER ─────────────────────────────────────────────────────────

    function cancelOrder(uint256 orderId) external {
        Order storage o = orders[orderId];
        require(o.status == OrderStatus.Open || o.status == OrderStatus.PartialFill, "Not cancellable");
        require(msg.sender == o.trader || msg.sender == owner(), "Not authorised");

        o.status = OrderStatus.Cancelled;
        emit OrderCancelled(orderId, msg.sender);
    }

    // ─── ADMIN ────────────────────────────────────────────────────────────────

    function updateGLTEParameters(
        uint256 W_t,
        uint256 chi,
        uint256 r_cc,
        uint256 OICD,
        uint256 B_Tirana,
        uint256 F_Tadawul,
        uint256 sigma_VIX,
        uint256 gamma
    ) external onlyOwner {
        glteParams.W_t = W_t;
        glteParams.chi = chi;
        glteParams.r_cc = r_cc;
        glteParams.OICD = OICD;
        glteParams.B_Tirana = B_Tirana;
        glteParams.F_Tadawul = F_Tadawul;
        glteParams.sigma_VIX = sigma_VIX;
        glteParams.gamma = gamma;
        glteParams.updatedAt = block.timestamp;

        emit GLTEParametersUpdated(W_t, gamma, block.timestamp);
    }

    function setExecutor(address executor, bool authorised) external onlyOwner {
        authorizedExecutors[executor] = authorised;
    }

    // ─── VIEWS ────────────────────────────────────────────────────────────────

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    function getTraderOrders(address trader) external view returns (uint256[] memory) {
        return traderOrders[trader];
    }

    function getTraderStats(address trader) external view returns (TraderStats memory) {
        return traderStats[trader];
    }

    function getGLTEParams() external view returns (GLTEParameters memory) {
        return glteParams;
    }

    function getLatestSignal() external view returns (GLTESignal memory) {
        return latestSignal;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
