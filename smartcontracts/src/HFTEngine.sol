// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title HFTEngine — High-Frequency Trading engine based on the GLTE formula
/// @notice Implements the Global Liquidity Transformation Equation (GLTE):
///
///         L_in  = (W_t × χ_in × r_LIBOR) + r_BSE_Delhi + r_Bursa_Malaysia
///
///         L_out = (W_t / E[L_in]) × χ_out × (OICD/197) × B_Bolsaro
///               + [B_Tirana + (F_Tadawul × σ_VIX(Oil) × (1 + spread))] × γ × yuan_peg
///
///         Cross-market sources (OICD Models §2):
///           BSE Delhi, Bursa Malaysia (equities) → L_in
///           Brazil Bolsaro (commodities), Tirana (bonds), Tawadul (FX float) → L_out
///
///         χ_in  = 48,678.46%  (486.7846×)
///         χ_out = 75,834.34%  (758.3434×)
///         Derivative spread = 0.05–0.25 bp applied to σ_VIX(Oil)
///         Yuan peg: 1 Yuan = 1 OICD
contract HFTEngine is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    enum OrderType   { Market, Limit, StopLoss, GLTE }
    enum OrderStatus { Open, Filled, PartialFill, Cancelled, Expired }
    enum Direction   { Buy, Sell }

    struct GLTEParameters {
        // ── L_in inputs ────────────────────────────────────────────────────────
        uint256 W_t;               // Weighted global capital (£/₩/¥ multi-currency, 1e18)
        uint256 chi_in;            // χ_in — input liquidity multiplier at 48,678.46% (1e18)
        uint256 r_LIBOR;           // LIBOR reference rate (1e18)
        uint256 r_BSE_Delhi;       // Delhi Stock Exchange volume rate (1e18)
        uint256 r_Bursa_Malaysia;  // Bursa Malaysia equity sectors rate (1e18)
        // ── L_out inputs ───────────────────────────────────────────────────────
        uint256 chi_out;           // χ_out — output liquidity multiplier at 75,834.34% (1e18)
        uint256 OICD;              // OICD basket base value (normalised at 197, 1e18)
        uint256 B_Bolsaro;         // Brazil Bolsaro commodities exchange factor (1e18)
        uint256 B_Tirana;          // Tirana Stock Exchange bonds factor (1e18)
        uint256 F_Tadawul;         // Saudi Tawadul float factor (1e18)
        uint256 sigma_VIX;         // σ_VIX(Oil) volatility (1e18)
        uint256 derivativeSpread;  // OICD Treasury derivative spread 0.05–0.25 bp (1e18)
        uint256 gamma;             // γ — yuan-OICD risk coefficient (1e18)
        uint256 yuan_OICD_peg;     // 1 Yuan = 1 OICD peg rate (1e18 = parity)
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
            // ── L_in inputs ──────────────────────────────────────────────────
            W_t:               1_000_000 * 1e18,  // $1M weighted global capital
            chi_in:            4_867_846 * 1e14,  // 486.7846× (48,678.46%)
            r_LIBOR:           533 * 1e14,         // 5.33% LIBOR reference rate
            r_BSE_Delhi:       1_000_000 * 1e18,  // BSE Delhi volume component
            r_Bursa_Malaysia:  800_000 * 1e18,    // Bursa Malaysia equity sectors
            // ── L_out inputs ─────────────────────────────────────────────────
            chi_out:           7_583_434 * 1e14,  // 758.3434× (75,834.34%)
            OICD:              197 * 1e18,         // OICD basket base at 197
            B_Bolsaro:         1_2 * 1e17,         // 1.2× Brazil Bolsaro commodities
            B_Tirana:          500_000 * 1e18,     // Tirana Stock Exchange bonds
            F_Tadawul:         1_2 * 1e17,         // 1.2× Saudi Tawadul float
            sigma_VIX:         25 * 1e16,          // 25% σ_VIX oil volatility
            derivativeSpread:  15 * 1e12,          // 0.15 bp OICD Treasury derivative spread
            gamma:             1_05 * 1e16,        // γ = 1.05 yuan-OICD coefficient
            yuan_OICD_peg:     1e18,               // 1 Yuan = 1 OICD (parity)
            updatedAt:         block.timestamp
        });
    }

    // ─── GLTE COMPUTATION ─────────────────────────────────────────────────────

    /// @notice Computes GLTE output using the sovereign liquidity equation
    /// @return L_in  Expected inflow  = (W_t × χ_in × r_LIBOR) + r_BSE_Delhi + r_Bursa_Malaysia
    /// @return L_out Transformed outflow = (W_t/L_in) × χ_out × (OICD/197) × B_Bolsaro
    ///                                   + [B_Tirana + F_Tadawul × σ_VIX × (1+spread)] × γ × yuan_peg
    function computeGLTE() public view returns (uint256 L_in, uint256 L_out) {
        GLTEParameters memory p = glteParams;

        // ── L_in ─────────────────────────────────────────────────────────────
        // W_t × χ_in × r_LIBOR  (LIBOR-weighted capital inflow)
        uint256 libor_term = (p.W_t * p.chi_in / 1e18) * p.r_LIBOR / 1e18;
        // Add BSE Delhi + Bursa Malaysia equity sector volumes
        L_in = libor_term + p.r_BSE_Delhi + p.r_Bursa_Malaysia;

        // ── L_out components ─────────────────────────────────────────────────
        // OICD normalised at 197: OICD / 197 → 1e18 at base value
        uint256 oicd_norm = p.OICD / 197;

        // σ_VIX adjusted for OICD Treasury derivative spread: σ_VIX × (1 + spread)
        uint256 vix_spread = p.sigma_VIX * (1e18 + p.derivativeSpread) / 1e18;

        // χ_out × (OICD/197) × B_Bolsaro
        uint256 out_factor = (p.chi_out * oicd_norm / 1e18) * p.B_Bolsaro / 1e18;

        // W_t / E[L_in]
        uint256 W_over_Lin = L_in > 0 ? (p.W_t * 1e18 / L_in) : 1e18;

        // [B_Tirana + F_Tadawul × σ_VIX_spread]
        uint256 bracket = p.B_Tirana + (p.F_Tadawul * vix_spread / 1e18);

        // L_out = (W_t/L_in × χ_out × OICD_norm × B_Bolsaro) + bracket × γ × yuan_peg
        L_out = (W_over_Lin * out_factor / 1e18)
              + ((bracket * p.gamma / 1e18) * p.yuan_OICD_peg / 1e18);
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
        uint256 chi_in,
        uint256 chi_out,
        uint256 r_LIBOR,
        uint256 r_BSE_Delhi,
        uint256 r_Bursa_Malaysia,
        uint256 OICD,
        uint256 B_Bolsaro,
        uint256 B_Tirana,
        uint256 F_Tadawul,
        uint256 sigma_VIX,
        uint256 derivativeSpread,
        uint256 gamma,
        uint256 yuan_OICD_peg
    ) external onlyOwner {
        glteParams.W_t = W_t;
        glteParams.chi_in = chi_in;
        glteParams.chi_out = chi_out;
        glteParams.r_LIBOR = r_LIBOR;
        glteParams.r_BSE_Delhi = r_BSE_Delhi;
        glteParams.r_Bursa_Malaysia = r_Bursa_Malaysia;
        glteParams.OICD = OICD;
        glteParams.B_Bolsaro = B_Bolsaro;
        glteParams.B_Tirana = B_Tirana;
        glteParams.F_Tadawul = F_Tadawul;
        glteParams.sigma_VIX = sigma_VIX;
        glteParams.derivativeSpread = derivativeSpread;
        glteParams.gamma = gamma;
        glteParams.yuan_OICD_peg = yuan_OICD_peg;
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
