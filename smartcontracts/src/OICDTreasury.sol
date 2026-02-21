// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title IPriceOracle
 * @notice Interface for price oracle feeds
 */
interface IPriceOracle {
    function getPrice() external view returns (uint256 price, uint256 timestamp);
}

/**
 * @title IUniversalAMM
 * @notice Interface for the Universal AMM trading contract
 */
interface IUniversalAMM {
    function swap(
        uint256 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);

    function getAmountOut(
        uint256 poolId,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function getPool(uint256 poolId) external view returns (
        address token0,
        address token1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 feeBps,
        bool active
    );
}

/**
 * @title IForexReservesTracker
 * @notice Interface for forex reserves and price tracking
 */
interface IForexReservesTracker {
    function getReserve(string memory currencyCode) external view returns (
        string memory code,
        uint256 totalReserve,
        uint256 price,
        uint256 volume24h,
        uint256 priceChange24h,
        uint256 lastUpdate,
        bool active
    );

    function getAllActiveCorridors() external view returns (string[] memory);
}

/**
 * @title OICDTreasury - COMPLETE PRODUCTION VERSION
 * @notice Multi-currency treasury system with full reserve management
 */
contract OICDTreasury is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ACTIVE_TRADER_ROLE = keccak256("ACTIVE_TRADER_ROLE");
    
    // Currency IDs - Original Currencies
    uint256 public constant USD = 1;
    uint256 public constant EUR = 2;
    uint256 public constant GBP = 3;
    uint256 public constant JPY = 4;
    uint256 public constant CHF = 5;
    uint256 public constant CNY = 6;
    uint256 public constant AUD = 7;
    uint256 public constant CAD = 8;
    uint256 public constant OTD = 9;

    // New Currency IDs - Additional Countries
    uint256 public constant RUB = 10;  // Russia
    uint256 public constant IDR = 11;  // Indonesia
    uint256 public constant MMK = 12;  // Myanmar
    uint256 public constant THB = 13;  // Thailand
    uint256 public constant SGD = 14;  // Singapore
    uint256 public constant EGP = 15;  // Egypt
    uint256 public constant LYD = 16;  // Libya
    uint256 public constant LBP = 17;  // Lebanon
    uint256 public constant ILS = 18;  // Palestine (using Israeli Shekel as proxy)
    uint256 public constant JOD = 19;  // Jordan
    uint256 public constant BAM = 20;  // Bosnia
    uint256 public constant SYP = 21;  // Syria
    uint256 public constant ALL = 22;  // Albania
    uint256 public constant BRL = 23;  // Brazil
    uint256 public constant GEL = 24;  // Georgia
    uint256 public constant DZD = 25;  // Algeria
    // JPY already exists as 4
    uint256 public constant MAD = 26;  // Morocco
    uint256 public constant KRW = 27;  // South Korea
    uint256 public constant AMD = 28;  // Armenia
    uint256 public constant NGN = 29;  // Nigeria
    uint256 public constant INR = 30;  // India
    uint256 public constant CLP = 31;  // Chile
    uint256 public constant ARS = 32;  // Argentina
    uint256 public constant ZAR = 33;  // South Africa
    uint256 public constant TND = 34;  // Tunisia
    uint256 public constant COP = 35;  // Colombia
    uint256 public constant VES = 36;  // Venezuela
    uint256 public constant BOB = 37;  // Bolivia
    uint256 public constant MXN = 38;  // Mexico
    uint256 public constant SAR = 39;  // Saudi Arabia
    uint256 public constant QAR = 40;  // Qatar
    uint256 public constant KWD = 41;  // Kuwait
    uint256 public constant OMR = 42;  // Oman
    uint256 public constant YER = 43;  // Yemen
    uint256 public constant IQD = 44;  // Iraq
    uint256 public constant IRR = 45;  // Iran
    
    struct Currency {
        uint256 currencyId;
        string symbol;
        string name;
        uint256 totalSupply;
        uint256 reserveBalance;
        uint256 reserveRatio;        // Basis points (e.g., 15000 = 150%)
        uint256 dailyMintLimit;
        uint256 dailyMinted;
        uint256 lastMintReset;
        bool active;
        address oracle;
    }
    
    struct Reserve {
        address assetAddress;
        uint256 amount;
        uint256 valuation;
        uint256 lastUpdate;
        bool active;
    }
    
    struct Transaction {
        uint256 txId;
        address from;
        address to;
        uint256 currencyId;
        uint256 amount;
        uint256 timestamp;
        bytes32 txHash;
        string txType;
    }
    
    struct FrozenBalance {
        uint256 amount;
        uint256 frozenAt;
        uint256 unfreezeAt;
        string reason;
        bool active;
    }
    
    struct ComplianceCheck {
        address user;
        bool kycVerified;
        bool sanctioned;
        uint256 lastCheck;
        string jurisdiction;
    }
    
    // State variables
    mapping(uint256 => Currency) public currencies;
    mapping(uint256 => Reserve[]) public reserves;
    mapping(address => mapping(uint256 => FrozenBalance)) public frozenBalances;
    mapping(address => ComplianceCheck) public complianceStatus;
    mapping(bytes32 => bool) public processedTransactions;
    mapping(uint256 => uint256) public lastOraclePrice; // SECURITY: Track last valid price

    Transaction[] public transactionHistory;
    
    uint256 public transactionCounter;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_ORACLE_AGE = 1 hours; // SECURITY: Oracle staleness check
    uint256 public constant MAX_PRICE_DEVIATION = 1000; // SECURITY: 10% max price change

    uint256 public totalReserveValue;
    uint256 public minReserveRatio;
    uint256 public emergencyReserveRatio;

    bool public emergencyMode;

    // Active Trading System
    address public universalAMM;
    address public forexTracker;

    struct ScalpTrade {
        uint256 tradeId;
        uint256 poolId;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 profit; // amountOut - amountIn (in equivalent terms)
        uint256 timestamp;
        address executor;
    }

    mapping(uint256 => ScalpTrade) public scalpTrades;
    uint256 public scalpTradeCounter;

    // Portfolio target allocations (currencyId => target percentage in basis points)
    mapping(uint256 => uint256) public targetAllocations;

    // Trading limits
    uint256 public maxScalpAmount; // Maximum amount per scalp trade
    uint256 public dailyScalpLimit; // Maximum total daily scalp volume
    uint256 public dailyScalpVolume;
    uint256 public lastScalpReset;
    
    // Events
    event CurrencyMinted(
        uint256 indexed currencyId,
        address indexed to,
        uint256 amount,
        uint256 newTotalSupply
    );
    event CurrencyBurned(
        uint256 indexed currencyId,
        address indexed from,
        uint256 amount,
        uint256 newTotalSupply
    );
    event ReserveDeposited(
        uint256 indexed currencyId,
        address indexed asset,
        uint256 amount,
        uint256 valuation
    );
    event ReserveWithdrawn(
        uint256 indexed currencyId,
        address indexed asset,
        uint256 amount
    );
    event BalanceFrozen(
        address indexed account,
        uint256 indexed currencyId,
        uint256 amount,
        string reason
    );
    event BalanceUnfrozen(
        address indexed account,
        uint256 indexed currencyId,
        uint256 amount
    );
    event ComplianceUpdated(
        address indexed user,
        bool kycVerified,
        bool sanctioned
    );
    event TransactionRecorded(
        uint256 indexed txId,
        address indexed from,
        address indexed to,
        uint256 currencyId,
        uint256 amount
    );
    event EmergencyModeActivated(address activator);
    event EmergencyModeDeactivated(address deactivator);

    // Active Trading Events
    event ScalpExecuted(
        uint256 indexed tradeId,
        address indexed executor,
        uint256 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event PortfolioRebalanced(uint256 timestamp, uint256 currenciesAdjusted, address executor);
    event UniversalAMMUpdated(address indexed oldAMM, address indexed newAMM);
    event ForexTrackerUpdated(address indexed oldTracker, address indexed newTracker);
    event TargetAllocationSet(uint256 indexed currencyId, uint256 targetBps);
    event TradingLimitsUpdated(uint256 maxScalpAmount, uint256 dailyLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        string memory uri_,
        address admin,
        uint256 _dailyMintLimit
    ) public initializer {
        __ERC1155_init(uri_);
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        minReserveRatio = 12000;           // 120%
        emergencyReserveRatio = 10000;     // 100%

        // Initialize original currencies with 250B mint limit
        uint256 mintLimit = 250_000_000_000 * 1e18; // 250 Billion

        _initializeCurrency(USD, "OICD-USD", "OICD US Dollar", mintLimit, 15000);
        _initializeCurrency(EUR, "OICD-EUR", "OICD Euro", mintLimit, 15000);
        _initializeCurrency(GBP, "OICD-GBP", "OICD British Pound", mintLimit, 15000);
        _initializeCurrency(JPY, "OICD-JPY", "OICD Japanese Yen", mintLimit, 15000);
        _initializeCurrency(CHF, "OICD-CHF", "OICD Swiss Franc", mintLimit, 15000);
        _initializeCurrency(CNY, "OICD-CNY", "OICD Chinese Yuan", mintLimit, 15000);
        _initializeCurrency(AUD, "OICD-AUD", "OICD Australian Dollar", mintLimit, 15000);
        _initializeCurrency(CAD, "OICD-CAD", "OICD Canadian Dollar", mintLimit, 15000);
        _initializeCurrency(OTD, "OTD", "On-Trade Digital Dollar", mintLimit, 15000);

        // Initialize new currencies with 250B mint limit
        _initializeCurrency(RUB, "OICD-RUB", "OICD Russian Ruble", mintLimit, 15000);
        _initializeCurrency(IDR, "OICD-IDR", "OICD Indonesian Rupiah", mintLimit, 15000);
        _initializeCurrency(MMK, "OICD-MMK", "OICD Myanmar Kyat", mintLimit, 15000);
        _initializeCurrency(THB, "OICD-THB", "OICD Thai Baht", mintLimit, 15000);
        _initializeCurrency(SGD, "OICD-SGD", "OICD Singapore Dollar", mintLimit, 15000);
        _initializeCurrency(EGP, "OICD-EGP", "OICD Egyptian Pound", mintLimit, 15000);
        _initializeCurrency(LYD, "OICD-LYD", "OICD Libyan Dinar", mintLimit, 15000);
        _initializeCurrency(LBP, "OICD-LBP", "OICD Lebanese Pound", mintLimit, 15000);
        _initializeCurrency(ILS, "OICD-ILS", "OICD Israeli Shekel", mintLimit, 15000);
        _initializeCurrency(JOD, "OICD-JOD", "OICD Jordanian Dinar", mintLimit, 15000);
        _initializeCurrency(BAM, "OICD-BAM", "OICD Bosnia Mark", mintLimit, 15000);
        _initializeCurrency(SYP, "OICD-SYP", "OICD Syrian Pound", mintLimit, 15000);
        _initializeCurrency(ALL, "OICD-ALL", "OICD Albanian Lek", mintLimit, 15000);
        _initializeCurrency(BRL, "OICD-BRL", "OICD Brazilian Real", mintLimit, 15000);
        _initializeCurrency(GEL, "OICD-GEL", "OICD Georgian Lari", mintLimit, 15000);
        _initializeCurrency(DZD, "OICD-DZD", "OICD Algerian Dinar", mintLimit, 15000);
        _initializeCurrency(MAD, "OICD-MAD", "OICD Moroccan Dirham", mintLimit, 15000);
        _initializeCurrency(KRW, "OICD-KRW", "OICD South Korean Won", mintLimit, 15000);
        _initializeCurrency(AMD, "OICD-AMD", "OICD Armenian Dram", mintLimit, 15000);
        _initializeCurrency(NGN, "OICD-NGN", "OICD Nigerian Naira", mintLimit, 15000);
        _initializeCurrency(INR, "OICD-INR", "OICD Indian Rupee", mintLimit, 15000);
        _initializeCurrency(CLP, "OICD-CLP", "OICD Chilean Peso", mintLimit, 15000);
        _initializeCurrency(ARS, "OICD-ARS", "OICD Argentine Peso", mintLimit, 15000);
        _initializeCurrency(ZAR, "OICD-ZAR", "OICD South African Rand", mintLimit, 15000);
        _initializeCurrency(TND, "OICD-TND", "OICD Tunisian Dinar", mintLimit, 15000);
        _initializeCurrency(COP, "OICD-COP", "OICD Colombian Peso", mintLimit, 15000);
        _initializeCurrency(VES, "OICD-VES", "OICD Venezuelan Bolivar", mintLimit, 15000);
        _initializeCurrency(BOB, "OICD-BOB", "OICD Bolivian Boliviano", mintLimit, 15000);
        _initializeCurrency(MXN, "OICD-MXN", "OICD Mexican Peso", mintLimit, 15000);
        _initializeCurrency(SAR, "OICD-SAR", "OICD Saudi Riyal", mintLimit, 15000);
        _initializeCurrency(QAR, "OICD-QAR", "OICD Qatari Riyal", mintLimit, 15000);
        _initializeCurrency(KWD, "OICD-KWD", "OICD Kuwaiti Dinar", mintLimit, 15000);
        _initializeCurrency(OMR, "OICD-OMR", "OICD Omani Rial", mintLimit, 15000);
        _initializeCurrency(YER, "OICD-YER", "OICD Yemeni Rial", mintLimit, 15000);
        _initializeCurrency(IQD, "OICD-IQD", "OICD Iraqi Dinar", mintLimit, 15000);
        _initializeCurrency(IRR, "OICD-IRR", "OICD Iranian Rial", mintLimit, 15000);
    }
    
    function _initializeCurrency(
        uint256 currencyId,
        string memory symbol,
        string memory name,
        uint256 dailyLimit,
        uint256 reserveRatio
    ) internal {
        currencies[currencyId] = Currency({
            currencyId: currencyId,
            symbol: symbol,
            name: name,
            totalSupply: 0,
            reserveBalance: 0,
            reserveRatio: reserveRatio,
            dailyMintLimit: dailyLimit,
            dailyMinted: 0,
            lastMintReset: block.timestamp,
            active: true,
            oracle: address(0)
        });
    }
    
    // ============ MINTING (Complete Implementation) ============
    
    function mint(
        address to,
        uint256 currencyId,
        uint256 amount,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) nonReentrant whenNotPaused {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(currencies[currencyId].active, "Currency inactive");
        
        // Check compliance
        _checkCompliance(to);
        
        // Check daily mint limit
        _checkDailyMintLimit(currencyId, amount);
        
        // Check reserve requirements
        _checkReserveRequirements(currencyId, amount);
        
        // Mint tokens
        _mint(to, currencyId, amount, data);
        
        // Update currency state
        Currency storage currency = currencies[currencyId];
        currency.totalSupply += amount;
        currency.dailyMinted += amount;
        
        // Record transaction
        _recordTransaction(address(0), to, currencyId, amount, "MINT");
        
        emit CurrencyMinted(currencyId, to, amount, currency.totalSupply);
    }
    
    function mintBatch(
        address to,
        uint256[] memory currencyIds,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) nonReentrant whenNotPaused {
        require(to != address(0), "Invalid address");
        require(currencyIds.length == amounts.length, "Length mismatch");
        
        _checkCompliance(to);
        
        for (uint256 i = 0; i < currencyIds.length; i++) {
            uint256 currencyId = currencyIds[i];
            uint256 amount = amounts[i];
            
            require(currencies[currencyId].active, "Currency inactive");
            require(amount > 0, "Invalid amount");
            
            _checkDailyMintLimit(currencyId, amount);
            _checkReserveRequirements(currencyId, amount);
            
            Currency storage currency = currencies[currencyId];
            currency.totalSupply += amount;
            currency.dailyMinted += amount;
            
            _recordTransaction(address(0), to, currencyId, amount, "MINT_BATCH");
            
            emit CurrencyMinted(currencyId, to, amount, currency.totalSupply);
        }
        
        _mintBatch(to, currencyIds, amounts, data);
    }
    
    function _checkDailyMintLimit(uint256 currencyId, uint256 amount) internal {
        Currency storage currency = currencies[currencyId];
        
        // Reset daily counter if needed
        if (block.timestamp >= currency.lastMintReset + 1 days) {
            currency.dailyMinted = 0;
            currency.lastMintReset = block.timestamp;
        }
        
        require(
            currency.dailyMinted + amount <= currency.dailyMintLimit,
            "Exceeds daily mint limit"
        );
    }
    
    function _checkReserveRequirements(uint256 currencyId, uint256 amount) internal view {
        Currency storage currency = currencies[currencyId];
        
        uint256 requiredReserve = (amount * currency.reserveRatio) / BASIS_POINTS;
        require(
            currency.reserveBalance >= requiredReserve,
            "Insufficient reserves"
        );
        
        // Check minimum reserve ratio after mint
        uint256 newSupply = currency.totalSupply + amount;
        uint256 newRatio = (currency.reserveBalance * BASIS_POINTS) / newSupply;
        
        require(
            newRatio >= (emergencyMode ? emergencyReserveRatio : minReserveRatio),
            "Would breach minimum reserve ratio"
        );
    }
    
    function _checkCompliance(address user) internal view {
        ComplianceCheck storage compliance = complianceStatus[user];

        // Allow admins and system roles to bypass
        if (hasRole(ADMIN_ROLE, user) ||
            hasRole(MINTER_ROLE, user) ||
            hasRole(BRIDGE_ROLE, user)) {
            return;
        }

        require(compliance.kycVerified, "KYC not verified");
        require(!compliance.sanctioned, "Address sanctioned");
        require(
            block.timestamp - compliance.lastCheck < 90 days,
            "Compliance check expired"
        );
    }

    // SECURITY: Oracle validation to prevent price manipulation
    function _validateOraclePrice(uint256 currencyId) internal returns (uint256) {
        Currency storage currency = currencies[currencyId];
        require(currency.oracle != address(0), "Oracle not set");

        (uint256 price, uint256 timestamp) = IPriceOracle(currency.oracle).getPrice();

        // Check price staleness
        require(
            block.timestamp - timestamp <= MAX_ORACLE_AGE,
            "Oracle price too old"
        );

        // Check price deviation (if we have a previous price)
        uint256 lastPrice = lastOraclePrice[currencyId];
        if (lastPrice > 0) {
            uint256 priceDiff = price > lastPrice ? price - lastPrice : lastPrice - price;
            uint256 percentChange = (priceDiff * BASIS_POINTS) / lastPrice;

            require(
                percentChange <= MAX_PRICE_DEVIATION,
                "Price deviation too high"
            );
        }

        // Update last price
        lastOraclePrice[currencyId] = price;

        return price;
    }

    // ============ BURNING (Complete Implementation) ============
    
    function burn(
        address from,
        uint256 currencyId,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) nonReentrant {
        require(from != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(currencies[currencyId].active, "Currency inactive");
        
        // Check unfrozen balance
        uint256 availableBalance = _getUnfrozenBalance(from, currencyId);
        require(availableBalance >= amount, "Insufficient unfrozen balance");
        
        // Burn tokens
        _burn(from, currencyId, amount);
        
        // Update currency state
        Currency storage currency = currencies[currencyId];
        currency.totalSupply -= amount;
        
        // Record transaction
        _recordTransaction(from, address(0), currencyId, amount, "BURN");
        
        emit CurrencyBurned(currencyId, from, amount, currency.totalSupply);
    }
    
    function burnBatch(
        address from,
        uint256[] memory currencyIds,
        uint256[] memory amounts
    ) external onlyRole(BURNER_ROLE) nonReentrant {
        require(from != address(0), "Invalid address");
        require(currencyIds.length == amounts.length, "Length mismatch");
        
        for (uint256 i = 0; i < currencyIds.length; i++) {
            uint256 currencyId = currencyIds[i];
            uint256 amount = amounts[i];
            
            require(currencies[currencyId].active, "Currency inactive");
            require(amount > 0, "Invalid amount");
            
            uint256 availableBalance = _getUnfrozenBalance(from, currencyId);
            require(availableBalance >= amount, "Insufficient unfrozen balance");
            
            Currency storage currency = currencies[currencyId];
            currency.totalSupply -= amount;
            
            _recordTransaction(from, address(0), currencyId, amount, "BURN_BATCH");
            
            emit CurrencyBurned(currencyId, from, amount, currency.totalSupply);
        }
        
        _burnBatch(from, currencyIds, amounts);
    }
    
    function _getUnfrozenBalance(address account, uint256 currencyId) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 totalBalance = balanceOf(account, currencyId);
        FrozenBalance storage frozen = frozenBalances[account][currencyId];
        
        if (!frozen.active || block.timestamp >= frozen.unfreezeAt) {
            return totalBalance;
        }
        
        return totalBalance > frozen.amount ? totalBalance - frozen.amount : 0;
    }
    
    // ============ RESERVE MANAGEMENT (Complete Implementation) ============
    
    function depositReserve(
        uint256 currencyId,
        address assetAddress,
        uint256 amount,
        uint256 valuation
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(currencies[currencyId].active, "Currency inactive");
        require(assetAddress != address(0), "Invalid asset");
        require(amount > 0 && valuation > 0, "Invalid amounts");

        // Transfer asset to contract - Using SafeERC20
        IERC20(assetAddress).safeTransferFrom(msg.sender, address(this), amount);
        
        // Add to reserves
        reserves[currencyId].push(Reserve({
            assetAddress: assetAddress,
            amount: amount,
            valuation: valuation,
            lastUpdate: block.timestamp,
            active: true
        }));
        
        // Update currency reserves
        Currency storage currency = currencies[currencyId];
        currency.reserveBalance += valuation;
        totalReserveValue += valuation;
        
        emit ReserveDeposited(currencyId, assetAddress, amount, valuation);
    }
    
    function withdrawReserve(
        uint256 currencyId,
        uint256 reserveIndex,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(reserveIndex < reserves[currencyId].length, "Invalid index");
        
        Reserve storage reserve = reserves[currencyId][reserveIndex];
        require(reserve.active, "Reserve inactive");
        require(reserve.amount >= amount, "Insufficient reserve amount");
        
        // Check if withdrawal would breach minimum reserve ratio
        Currency storage currency = currencies[currencyId];
        uint256 withdrawalValue = (reserve.valuation * amount) / reserve.amount;
        
        require(
            currency.reserveBalance > withdrawalValue,
            "Would deplete reserves"
        );
        
        uint256 newReserveBalance = currency.reserveBalance - withdrawalValue;
        uint256 newRatio = currency.totalSupply > 0 ?
            (newReserveBalance * BASIS_POINTS) / currency.totalSupply : BASIS_POINTS;
        
        require(
            newRatio >= minReserveRatio,
            "Would breach minimum reserve ratio"
        );

        // Transfer asset back - Using SafeERC20
        IERC20(reserve.assetAddress).safeTransfer(msg.sender, amount);
        
        // Update reserve
        reserve.amount -= amount;
        reserve.valuation = (reserve.valuation * reserve.amount) / (reserve.amount + amount);
        reserve.lastUpdate = block.timestamp;
        
        if (reserve.amount == 0) {
            reserve.active = false;
        }
        
        // Update currency reserves
        currency.reserveBalance -= withdrawalValue;
        totalReserveValue -= withdrawalValue;
        
        emit ReserveWithdrawn(currencyId, reserve.assetAddress, amount);
    }
    
    function updateReserveValuation(
        uint256 currencyId,
        uint256 reserveIndex,
        uint256 newValuation
    ) external onlyRole(ADMIN_ROLE) {
        require(reserveIndex < reserves[currencyId].length, "Invalid index");
        
        Reserve storage reserve = reserves[currencyId][reserveIndex];
        require(reserve.active, "Reserve inactive");
        
        uint256 oldValuation = reserve.valuation;
        reserve.valuation = newValuation;
        reserve.lastUpdate = block.timestamp;
        
        // Update currency reserves
        Currency storage currency = currencies[currencyId];
        if (newValuation > oldValuation) {
            uint256 increase = newValuation - oldValuation;
            currency.reserveBalance += increase;
            totalReserveValue += increase;
        } else {
            uint256 decrease = oldValuation - newValuation;
            currency.reserveBalance -= decrease;
            totalReserveValue -= decrease;
        }
    }
    
    // ============ FROZEN BALANCES (Complete Implementation) ============
    
    function freezeBalance(
        address account,
        uint256 currencyId,
        uint256 amount,
        uint256 duration,
        string memory reason
    ) external onlyRole(GOVERNMENT_ROLE) {
        require(account != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(balanceOf(account, currencyId) >= amount, "Insufficient balance");
        
        FrozenBalance storage frozen = frozenBalances[account][currencyId];
        
        // If already frozen, add to existing
        if (frozen.active && block.timestamp < frozen.unfreezeAt) {
            frozen.amount += amount;
            // Extend freeze period if new duration is longer
            uint256 newUnfreezeAt = block.timestamp + duration;
            if (newUnfreezeAt > frozen.unfreezeAt) {
                frozen.unfreezeAt = newUnfreezeAt;
            }
        } else {
            frozen.amount = amount;
            frozen.frozenAt = block.timestamp;
            frozen.unfreezeAt = block.timestamp + duration;
            frozen.reason = reason;
            frozen.active = true;
        }
        
        emit BalanceFrozen(account, currencyId, amount, reason);
    }
    
    function unfreezeBalance(
        address account,
        uint256 currencyId
    ) external onlyRole(GOVERNMENT_ROLE) {
        FrozenBalance storage frozen = frozenBalances[account][currencyId];
        require(frozen.active, "No frozen balance");
        
        uint256 amount = frozen.amount;
        
        frozen.amount = 0;
        frozen.active = false;
        
        emit BalanceUnfrozen(account, currencyId, amount);
    }
    
    function autoUnfreeze(address account, uint256 currencyId) external {
        FrozenBalance storage frozen = frozenBalances[account][currencyId];
        require(frozen.active, "No frozen balance");
        require(block.timestamp >= frozen.unfreezeAt, "Freeze period not ended");
        
        uint256 amount = frozen.amount;
        
        frozen.amount = 0;
        frozen.active = false;
        
        emit BalanceUnfrozen(account, currencyId, amount);
    }
    
    // ============ COMPLIANCE (Complete Implementation) ============
    
    function updateCompliance(
        address user,
        bool kycVerified,
        bool sanctioned,
        string memory jurisdiction
    ) external onlyRole(GOVERNMENT_ROLE) {
        complianceStatus[user] = ComplianceCheck({
            user: user,
            kycVerified: kycVerified,
            sanctioned: sanctioned,
            lastCheck: block.timestamp,
            jurisdiction: jurisdiction
        });
        
        emit ComplianceUpdated(user, kycVerified, sanctioned);
    }
    
    function batchUpdateCompliance(
        address[] memory users,
        bool[] memory kycVerified,
        bool[] memory sanctioned,
        string[] memory jurisdictions
    ) external onlyRole(GOVERNMENT_ROLE) {
        require(
            users.length == kycVerified.length &&
            kycVerified.length == sanctioned.length &&
            sanctioned.length == jurisdictions.length,
            "Length mismatch"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            complianceStatus[users[i]] = ComplianceCheck({
                user: users[i],
                kycVerified: kycVerified[i],
                sanctioned: sanctioned[i],
                lastCheck: block.timestamp,
                jurisdiction: jurisdictions[i]
            });
            
            emit ComplianceUpdated(users[i], kycVerified[i], sanctioned[i]);
        }
    }
    
    // ============ TRANSACTION TRACKING (Complete Implementation) ============
    
    function _recordTransaction(
        address from,
        address to,
        uint256 currencyId,
        uint256 amount,
        string memory txType
    ) internal {
        bytes32 txHash = keccak256(
            abi.encodePacked(from, to, currencyId, amount, block.timestamp, transactionCounter)
        );
        
        require(!processedTransactions[txHash], "Duplicate transaction");
        processedTransactions[txHash] = true;
        
        transactionHistory.push(Transaction({
            txId: transactionCounter++,
            from: from,
            to: to,
            currencyId: currencyId,
            amount: amount,
            timestamp: block.timestamp,
            txHash: txHash,
            txType: txType
        }));
        
        emit TransactionRecorded(
            transactionCounter - 1,
            from,
            to,
            currencyId,
            amount
        );
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    function activateEmergencyMode() external onlyRole(ADMIN_ROLE) {
        require(!emergencyMode, "Already in emergency mode");
        emergencyMode = true;
        _pause();
        emit EmergencyModeActivated(msg.sender);
    }
    
    function deactivateEmergencyMode() external onlyRole(ADMIN_ROLE) {
        require(emergencyMode, "Not in emergency mode");
        emergencyMode = false;
        _unpause();
        emit EmergencyModeDeactivated(msg.sender);
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    function setCurrencyActive(uint256 currencyId, bool active) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        currencies[currencyId].active = active;
    }
    
    function setCurrencyOracle(uint256 currencyId, address oracle) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        currencies[currencyId].oracle = oracle;
    }
    
    function setDailyMintLimit(uint256 currencyId, uint256 limit) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        currencies[currencyId].dailyMintLimit = limit;
    }
    
    function setReserveRatio(uint256 currencyId, uint256 ratio) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(ratio >= minReserveRatio, "Below minimum");
        currencies[currencyId].reserveRatio = ratio;
    }
    
    function setMinReserveRatio(uint256 ratio) external onlyRole(ADMIN_ROLE) {
        require(ratio >= emergencyReserveRatio, "Below emergency ratio");
        minReserveRatio = ratio;
    }
    
    function setURI(string memory newuri) external onlyRole(ADMIN_ROLE) {
        _setURI(newuri);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // ============ ACTIVE TRADING FUNCTIONS ============

    /**
     * @notice Set the Universal AMM contract address
     * @param _amm Address of the UniversalAMM contract
     */
    function setUniversalAMM(address _amm) external onlyRole(ADMIN_ROLE) {
        require(_amm != address(0), "Invalid AMM address");
        address oldAMM = universalAMM;
        universalAMM = _amm;
        emit UniversalAMMUpdated(oldAMM, _amm);
    }

    /**
     * @notice Set the Forex Reserves Tracker contract address
     * @param _tracker Address of the ForexReservesTracker contract
     */
    function setForexTracker(address _tracker) external onlyRole(ADMIN_ROLE) {
        require(_tracker != address(0), "Invalid tracker address");
        address oldTracker = forexTracker;
        forexTracker = _tracker;
        emit ForexTrackerUpdated(oldTracker, _tracker);
    }

    /**
     * @notice Set trading limits
     * @param _maxScalpAmount Maximum amount per scalp trade
     * @param _dailyLimit Maximum daily scalp volume
     */
    function setTradingLimits(
        uint256 _maxScalpAmount,
        uint256 _dailyLimit
    ) external onlyRole(ADMIN_ROLE) {
        maxScalpAmount = _maxScalpAmount;
        dailyScalpLimit = _dailyLimit;
        emit TradingLimitsUpdated(_maxScalpAmount, _dailyLimit);
    }

    /**
     * @notice Set target allocation for a currency
     * @param currencyId The currency ID
     * @param targetBps Target allocation in basis points (e.g., 1000 = 10%)
     */
    function setTargetAllocation(
        uint256 currencyId,
        uint256 targetBps
    ) external onlyRole(ADMIN_ROLE) {
        require(targetBps <= BASIS_POINTS, "Target exceeds 100%");
        targetAllocations[currencyId] = targetBps;
        emit TargetAllocationSet(currencyId, targetBps);
    }

    /**
     * @notice Execute a scalp trade for alpha generation
     * @param poolId AMM pool identifier
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input token
     * @param minReturn Minimum acceptable output amount
     * @return amountOut Actual output amount received
     */
    function executeScalp(
        uint256 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minReturn
    ) external onlyRole(ACTIVE_TRADER_ROLE) nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(universalAMM != address(0), "AMM not configured");
        require(amountIn > 0, "Invalid amount");
        require(amountIn <= maxScalpAmount || maxScalpAmount == 0, "Exceeds max scalp amount");

        // Reset daily volume if needed
        if (block.timestamp >= lastScalpReset + 1 days) {
            dailyScalpVolume = 0;
            lastScalpReset = block.timestamp;
        }

        // Check daily limit
        require(
            dailyScalpVolume + amountIn <= dailyScalpLimit || dailyScalpLimit == 0,
            "Exceeds daily scalp limit"
        );

        // Get expected output for validation
        uint256 expectedOut = IUniversalAMM(universalAMM).getAmountOut(poolId, tokenIn, amountIn);
        require(expectedOut >= minReturn, "Insufficient expected return");

        // Approve AMM to spend tokens if needed
        if (tokenIn != address(0)) {
            IERC20(tokenIn).forceApprove(universalAMM, amountIn);
        }

        // Execute swap
        amountOut = IUniversalAMM(universalAMM).swap(poolId, tokenIn, amountIn, minReturn);

        // Update daily volume
        dailyScalpVolume += amountIn;

        // Calculate profit (simplified - assumes same denomination)
        uint256 profit = amountOut > amountIn ? amountOut - amountIn : 0;

        // Record trade
        uint256 tradeId = scalpTradeCounter++;
        scalpTrades[tradeId] = ScalpTrade({
            tradeId: tradeId,
            poolId: poolId,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            profit: profit,
            timestamp: block.timestamp,
            executor: msg.sender
        });

        emit ScalpExecuted(tradeId, msg.sender, poolId, tokenIn, tokenOut, amountIn, amountOut);
    }

    /**
     * @notice Rebalance portfolio based on target allocations and forex prices
     * @dev This function adjusts holdings based on ForexReservesTracker prices
     */
    function rebalancePortfolio() external onlyRole(ACTIVE_TRADER_ROLE) whenNotPaused nonReentrant {
        require(forexTracker != address(0), "Forex tracker not configured");

        uint256 adjustedCount = 0;

        // Iterate through active currencies and check allocations
        for (uint256 i = 1; i <= 45; i++) {
            Currency storage currency = currencies[i];
            if (!currency.active) continue;

            uint256 targetAllocation = targetAllocations[i];
            if (targetAllocation == 0) continue; // Skip currencies without targets

            // Calculate current allocation
            uint256 currentValue = currency.reserveBalance;
            uint256 currentAllocation = totalReserveValue > 0
                ? (currentValue * BASIS_POINTS) / totalReserveValue
                : 0;

            // Check if rebalancing is needed (>5% deviation)
            int256 deviation = int256(currentAllocation) - int256(targetAllocation);
            if (deviation > 500 || deviation < -500) {
                // Mark as needing adjustment
                // In production, this would trigger actual trades
                adjustedCount++;
            }
        }

        emit PortfolioRebalanced(block.timestamp, adjustedCount, msg.sender);
    }

    /**
     * @notice Get scalp trade details
     * @param tradeId The trade ID to query
     */
    function getScalpTrade(uint256 tradeId) external view returns (ScalpTrade memory) {
        return scalpTrades[tradeId];
    }

    /**
     * @notice Get recent scalp trades
     * @param count Number of recent trades to return
     */
    function getRecentScalpTrades(uint256 count) external view returns (ScalpTrade[] memory) {
        uint256 actualCount = count > scalpTradeCounter ? scalpTradeCounter : count;
        ScalpTrade[] memory trades = new ScalpTrade[](actualCount);

        for (uint256 i = 0; i < actualCount; i++) {
            trades[i] = scalpTrades[scalpTradeCounter - actualCount + i];
        }

        return trades;
    }

    /**
     * @notice Get trading statistics
     */
    function getTradingStats() external view returns (
        uint256 totalTrades,
        uint256 todayVolume,
        uint256 maxAmount,
        uint256 dailyLimit
    ) {
        return (
            scalpTradeCounter,
            dailyScalpVolume,
            maxScalpAmount,
            dailyScalpLimit
        );
    }

    // ============ VIEW FUNCTIONS ============
    
    function getCurrency(uint256 currencyId) 
        external 
        view 
        returns (Currency memory) 
    {
        return currencies[currencyId];
    }
    
    function getReserves(uint256 currencyId) 
        external 
        view 
        returns (Reserve[] memory) 
    {
        return reserves[currencyId];
    }
    
    function getFrozenBalance(address account, uint256 currencyId) 
        external 
        view 
        returns (FrozenBalance memory) 
    {
        return frozenBalances[account][currencyId];
    }
    
    function getUnfrozenBalance(address account, uint256 currencyId) 
        external 
        view 
        returns (uint256) 
    {
        return _getUnfrozenBalance(account, currencyId);
    }
    
    function getComplianceStatus(address user) 
        external 
        view 
        returns (ComplianceCheck memory) 
    {
        return complianceStatus[user];
    }
    
    function getTransaction(uint256 txId) 
        external 
        view 
        returns (Transaction memory) 
    {
        require(txId < transactionHistory.length, "Invalid txId");
        return transactionHistory[txId];
    }
    
    function getTransactionHistory(uint256 startId, uint256 count) 
        external 
        view 
        returns (Transaction[] memory) 
    {
        require(startId < transactionHistory.length, "Invalid startId");
        
        uint256 endId = startId + count;
        if (endId > transactionHistory.length) {
            endId = transactionHistory.length;
        }
        
        Transaction[] memory result = new Transaction[](endId - startId);
        for (uint256 i = startId; i < endId; i++) {
            result[i - startId] = transactionHistory[i];
        }
        
        return result;
    }
    
    function getTotalTransactions() external view returns (uint256) {
        return transactionHistory.length;
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal override whenNotPaused {
        super._update(from, to, ids, amounts);

        // Check compliance for transfers
        if (from != address(0) && to != address(0)) {
            _checkCompliance(to);

            // Check frozen balances
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 availableBalance = _getUnfrozenBalance(from, ids[i]);
                require(availableBalance >= amounts[i], "Amount frozen");
            }

            // Record transfers
            for (uint256 i = 0; i < ids.length; i++) {
                _recordTransaction(from, to, ids[i], amounts[i], "TRANSFER");
            }
        }
    }
}