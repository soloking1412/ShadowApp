// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title LiquidityAsAService
 * @notice Provide liquidity services to markets, exchanges, and trading venues
 * @dev Market making, liquidity pools, cross-border liquidity provision
 */
contract LiquidityAsAService is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LIQUIDITY_PROVIDER_ROLE = keccak256("LIQUIDITY_PROVIDER_ROLE");
    bytes32 public constant MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");

    enum PoolType {
        FX,
        Commodities,
        Securities,
        Derivatives,
        CrossBorder,
        DarkPool
    }

    enum PoolStatus {
        Active,
        Paused,
        Closed,
        Rebalancing
    }

    struct LiquidityPool {
        uint256 poolId;
        PoolType poolType;
        string name;
        string[] assetPairs; // e.g., ["USD/EUR", "OICD/OTD"]
        uint256 totalLiquidity;
        uint256 utilizationRate; // Basis points
        uint256 spreadBps; // Bid-ask spread in basis points
        PoolStatus status;
        address[] providers;
        mapping(address => uint256) providerShares;
        uint256 dailyVolume;
        uint256 cumulativeVolume;
        uint256 fees;
        uint256 createdDate;
    }

    struct LiquidityPosition {
        uint256 positionId;
        uint256 poolId;
        address provider;
        uint256 amount;
        uint256 shares;
        uint256 depositDate;
        uint256 lockupEnd;
        uint256 rewardsEarned;
        bool active;
    }

    struct MarketMakingOrder {
        uint256 orderId;
        uint256 poolId;
        string assetPair;
        uint256 bidPrice;
        uint256 askPrice;
        uint256 bidSize;
        uint256 askSize;
        uint256 timestamp;
        bool active;
    }

    struct CrossBorderFlow {
        uint256 flowId;
        uint256 poolId;
        string fromCurrency;
        string toCurrency;
        string fromCountry;
        string toCountry;
        uint256 amount;
        uint256 exchangeRate;
        uint256 fee;
        uint256 timestamp;
        bool completed;
    }

    struct RewardDistribution {
        uint256 distributionId;
        uint256 poolId;
        uint256 totalRewards;
        uint256 timestamp;
        mapping(address => uint256) providerRewards;
        bool distributed;
    }

    // State variables
    mapping(uint256 => LiquidityPool) private pools;
    mapping(uint256 => LiquidityPosition) public positions;
    mapping(uint256 => MarketMakingOrder) public orders;
    mapping(uint256 => CrossBorderFlow) public flows;
    mapping(uint256 => RewardDistribution) private distributions;
    mapping(address => uint256[]) public providerPools;

    uint256 public poolCounter;
    uint256 public positionCounter;
    uint256 public orderCounter;
    uint256 public flowCounter;
    uint256 public distributionCounter;

    uint256 public totalLiquidityProvided;
    uint256 public totalVolumeTraded;
    uint256 public totalFeesCollected;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant LOCKUP_PERIOD = 30 days;

    // Events
    event PoolCreated(
        uint256 indexed poolId,
        PoolType poolType,
        string name,
        uint256 initialLiquidity
    );

    event LiquidityProvided(
        uint256 indexed positionId,
        uint256 indexed poolId,
        address indexed provider,
        uint256 amount,
        uint256 shares
    );

    event LiquidityWithdrawn(
        uint256 indexed positionId,
        address indexed provider,
        uint256 amount
    );

    event MarketOrderPlaced(
        uint256 indexed orderId,
        uint256 indexed poolId,
        string assetPair,
        uint256 bidPrice,
        uint256 askPrice
    );

    event CrossBorderFlowExecuted(
        uint256 indexed flowId,
        uint256 indexed poolId,
        string fromCurrency,
        string toCurrency,
        uint256 amount
    );

    event RewardsDistributed(
        uint256 indexed distributionId,
        uint256 indexed poolId,
        uint256 totalRewards
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(LIQUIDITY_PROVIDER_ROLE, admin);
        _grantRole(MARKET_MAKER_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    /**
     * @notice Create liquidity pool
     */
    function createPool(
        PoolType poolType,
        string memory name,
        string[] memory assetPairs,
        uint256 spreadBps
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        require(assetPairs.length > 0, "No asset pairs");
        require(spreadBps > 0 && spreadBps <= 1000, "Invalid spread");

        uint256 poolId = ++poolCounter;

        LiquidityPool storage pool = pools[poolId];
        pool.poolId = poolId;
        pool.poolType = poolType;
        pool.name = name;
        pool.assetPairs = assetPairs;
        pool.totalLiquidity = 0;
        pool.utilizationRate = 0;
        pool.spreadBps = spreadBps;
        pool.status = PoolStatus.Active;
        pool.dailyVolume = 0;
        pool.cumulativeVolume = 0;
        pool.fees = 0;
        pool.createdDate = block.timestamp;

        emit PoolCreated(poolId, poolType, name, 0);

        return poolId;
    }

    /**
     * @notice Provide liquidity to pool
     */
    function provideLiquidity(uint256 poolId)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        LiquidityPool storage pool = pools[poolId];
        require(pool.status == PoolStatus.Active, "Pool not active");
        require(msg.value > 0, "Invalid amount");

        uint256 shares;
        if (pool.totalLiquidity == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * 1e18) / pool.totalLiquidity;
        }

        uint256 positionId = ++positionCounter;

        positions[positionId] = LiquidityPosition({
            positionId: positionId,
            poolId: poolId,
            provider: msg.sender,
            amount: msg.value,
            shares: shares,
            depositDate: block.timestamp,
            lockupEnd: block.timestamp + LOCKUP_PERIOD,
            rewardsEarned: 0,
            active: true
        });

        if (pool.providerShares[msg.sender] == 0) {
            pool.providers.push(msg.sender);
            providerPools[msg.sender].push(poolId);
        }

        pool.providerShares[msg.sender] += shares;
        pool.totalLiquidity += msg.value;
        totalLiquidityProvided += msg.value;

        emit LiquidityProvided(positionId, poolId, msg.sender, msg.value, shares);

        return positionId;
    }

    /**
     * @notice Withdraw liquidity
     */
    function withdrawLiquidity(uint256 positionId)
        external
        nonReentrant
    {
        LiquidityPosition storage position = positions[positionId];
        require(position.provider == msg.sender, "Not position owner");
        require(position.active, "Position not active");
        require(block.timestamp >= position.lockupEnd, "Lockup period not ended");

        LiquidityPool storage pool = pools[position.poolId];

        uint256 withdrawAmount = (position.shares * pool.totalLiquidity) / 1e18;
        withdrawAmount += position.rewardsEarned;

        position.active = false;
        pool.totalLiquidity -= position.amount;
        pool.providerShares[msg.sender] -= position.shares;

        (bool success, ) = payable(msg.sender).call{value: withdrawAmount}("");
        require(success, "Withdrawal transfer failed");

        emit LiquidityWithdrawn(positionId, msg.sender, withdrawAmount);
    }

    /**
     * @notice Place market making order
     */
    function placeMarketOrder(
        uint256 poolId,
        string memory assetPair,
        uint256 midPrice,
        uint256 size
    ) external onlyRole(MARKET_MAKER_ROLE) returns (uint256) {
        LiquidityPool storage pool = pools[poolId];
        require(pool.status == PoolStatus.Active, "Pool not active");

        uint256 halfSpread = (midPrice * pool.spreadBps) / (2 * BASIS_POINTS);
        uint256 bidPrice = midPrice - halfSpread;
        uint256 askPrice = midPrice + halfSpread;

        uint256 orderId = ++orderCounter;

        orders[orderId] = MarketMakingOrder({
            orderId: orderId,
            poolId: poolId,
            assetPair: assetPair,
            bidPrice: bidPrice,
            askPrice: askPrice,
            bidSize: size,
            askSize: size,
            timestamp: block.timestamp,
            active: true
        });

        emit MarketOrderPlaced(orderId, poolId, assetPair, bidPrice, askPrice);

        return orderId;
    }

    /**
     * @notice Execute cross-border liquidity flow
     */
    function executeCrossBorderFlow(
        uint256 poolId,
        string memory fromCurrency,
        string memory toCurrency,
        string memory fromCountry,
        string memory toCountry,
        uint256 amount,
        uint256 exchangeRate
    ) external onlyRole(LIQUIDITY_PROVIDER_ROLE) whenNotPaused returns (uint256) {
        LiquidityPool storage pool = pools[poolId];
        require(pool.status == PoolStatus.Active, "Pool not active");
        require(pool.poolType == PoolType.CrossBorder || pool.poolType == PoolType.FX, "Wrong pool type");

        uint256 fee = (amount * pool.spreadBps) / BASIS_POINTS;
        uint256 flowId = ++flowCounter;

        flows[flowId] = CrossBorderFlow({
            flowId: flowId,
            poolId: poolId,
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            fromCountry: fromCountry,
            toCountry: toCountry,
            amount: amount,
            exchangeRate: exchangeRate,
            fee: fee,
            timestamp: block.timestamp,
            completed: true
        });

        pool.dailyVolume += amount;
        pool.cumulativeVolume += amount;
        pool.fees += fee;
        totalVolumeTraded += amount;
        totalFeesCollected += fee;

        emit CrossBorderFlowExecuted(flowId, poolId, fromCurrency, toCurrency, amount);

        return flowId;
    }

    /**
     * @notice Distribute rewards to liquidity providers
     */
    function distributeRewards(uint256 poolId)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        LiquidityPool storage pool = pools[poolId];
        require(pool.fees > 0, "No fees to distribute");

        uint256 distributionId = ++distributionCounter;
        RewardDistribution storage distribution = distributions[distributionId];
        distribution.distributionId = distributionId;
        distribution.poolId = poolId;
        distribution.totalRewards = pool.fees;
        distribution.timestamp = block.timestamp;

        uint256 totalShares = 0;
        for (uint256 i = 0; i < pool.providers.length; i++) {
            totalShares += pool.providerShares[pool.providers[i]];
        }

        for (uint256 i = 0; i < pool.providers.length; i++) {
            address provider = pool.providers[i];
            uint256 providerShare = pool.providerShares[provider];
            uint256 reward = (pool.fees * providerShare) / totalShares;
            distribution.providerRewards[provider] = reward;
        }

        distribution.distributed = true;
        pool.fees = 0;

        emit RewardsDistributed(distributionId, poolId, distribution.totalRewards);
    }

    /**
     * @notice Update pool utilization rate
     */
    function updateUtilization(uint256 poolId, uint256 utilizationRate)
        external
        onlyRole(MARKET_MAKER_ROLE)
    {
        require(utilizationRate <= BASIS_POINTS, "Invalid utilization");
        pools[poolId].utilizationRate = utilizationRate;
    }

    /**
     * @notice Get pool details
     */
    function getPool(uint256 poolId)
        external
        view
        returns (
            PoolType poolType,
            string memory name,
            uint256 totalLiquidity,
            uint256 utilizationRate,
            uint256 spreadBps,
            PoolStatus status,
            uint256 cumulativeVolume
        )
    {
        LiquidityPool storage pool = pools[poolId];
        return (
            pool.poolType,
            pool.name,
            pool.totalLiquidity,
            pool.utilizationRate,
            pool.spreadBps,
            pool.status,
            pool.cumulativeVolume
        );
    }

    /**
     * @notice Get provider's pools
     */
    function getProviderPools(address provider)
        external
        view
        returns (uint256[] memory)
    {
        return providerPools[provider];
    }

    /**
     * @notice Get pool providers
     */
    function getPoolProviders(uint256 poolId)
        external
        view
        returns (address[] memory)
    {
        return pools[poolId].providers;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    receive() external payable {}
}
