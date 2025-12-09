// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title LiquidityAsAService - COMPLETE PRODUCTION VERSION
 * @notice Managed liquidity pools with automated yield distribution
 */
contract LiquidityAsAService is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    enum PoolType {
        BondBacked,
        Forex,
        SovereignReserve,
        Infrastructure,
        Stability,
        YieldOptimization,
        Carbon
    }
    
    enum SubscriptionTier {
        Basic,
        Premium,
        Institutional,
        Sovereign
    }
    
    struct LiquidityPool {
        uint256 poolId;
        PoolType poolType;
        string name;
        address manager;
        uint256 totalLiquidity;
        uint256 totalShares;
        uint256 performanceFee;
        uint256 managementFee;
        uint256 minDeposit;
        uint256 lockupPeriod;
        bool active;
        uint256 createdAt;
    }
    
    struct PoolAsset {
        address assetAddress;
        uint256 amount;
        uint256 targetAllocation;
        uint256 currentAllocation;
    }
    
    struct LiquidityPosition {
        uint256 positionId;
        uint256 poolId;
        address provider;
        uint256 shares;
        uint256 depositAmount;
        uint256 depositTime;
        uint256 lastClaimTime;
        uint256 yieldEarned;
        bool active;
    }
    
    struct Subscription {
        SubscriptionTier tier;
        uint256 startDate;
        uint256 endDate;
        uint256 fee;
        bool active;
        bool autoRenew;
    }
    
    struct PerformanceMetrics {
        uint256 totalReturn;
        uint256 sharpeRatio;
        uint256 volatility;
        uint256 maxDrawdown;
        uint256 lastUpdate;
    }
    
    mapping(uint256 => LiquidityPool) public pools;
    mapping(uint256 => PoolAsset[]) public poolAssets;
    mapping(uint256 => LiquidityPosition[]) public poolPositions;
    mapping(address => uint256[]) public providerPositions;
    mapping(address => Subscription) public subscriptions;
    mapping(uint256 => PerformanceMetrics) public poolMetrics;
    
    uint256 public poolCounter;
    uint256 public positionCounter;
    
    mapping(SubscriptionTier => uint256) public tierFees;
    mapping(SubscriptionTier => uint256) public tierMultipliers;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public totalFeesCollected;
    
    event PoolCreated(uint256 indexed poolId, PoolType poolType, address indexed manager);
    event LiquidityAdded(
        uint256 indexed poolId,
        uint256 indexed positionId,
        address indexed provider,
        uint256 amount
    );
    event LiquidityRemoved(
        uint256 indexed poolId,
        uint256 indexed positionId,
        uint256 amount
    );
    event YieldDistributed(uint256 indexed poolId, uint256 totalYield);
    event SubscriptionPurchased(address indexed user, SubscriptionTier tier);
    event PoolRebalanced(uint256 indexed poolId);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        // Initialize tier fees
        tierFees[SubscriptionTier.Basic] = 100e18;
        tierFees[SubscriptionTier.Premium] = 500e18;
        tierFees[SubscriptionTier.Institutional] = 2000e18;
        tierFees[SubscriptionTier.Sovereign] = 10000e18;
        
        // Initialize tier multipliers (yield bonus)
        tierMultipliers[SubscriptionTier.Basic] = 10000;      // 100%
        tierMultipliers[SubscriptionTier.Premium] = 11000;    // 110%
        tierMultipliers[SubscriptionTier.Institutional] = 12000; // 120%
        tierMultipliers[SubscriptionTier.Sovereign] = 13000;  // 130%
    }
    
    function createPool(
        PoolType poolType,
        string memory name,
        uint256 performanceFee,
        uint256 managementFee,
        uint256 minDeposit,
        uint256 lockupPeriod
    ) external onlyRole(MANAGER_ROLE) returns (uint256) {
        require(performanceFee <= 2000, "Performance fee too high"); // Max 20%
        require(managementFee <= 200, "Management fee too high"); // Max 2%
        
        uint256 poolId = ++poolCounter;
        
        pools[poolId] = LiquidityPool({
            poolId: poolId,
            poolType: poolType,
            name: name,
            manager: msg.sender,
            totalLiquidity: 0,
            totalShares: 0,
            performanceFee: performanceFee,
            managementFee: managementFee,
            minDeposit: minDeposit,
            lockupPeriod: lockupPeriod,
            active: true,
            createdAt: block.timestamp
        });
        
        emit PoolCreated(poolId, poolType, msg.sender);
        
        return poolId;
    }
    
    function addLiquidity(uint256 poolId) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        returns (uint256) 
    {
        LiquidityPool storage pool = pools[poolId];
        require(pool.active, "Pool not active");
        require(msg.value >= pool.minDeposit, "Below minimum deposit");
        
        Subscription storage sub = subscriptions[msg.sender];
        require(sub.active && block.timestamp < sub.endDate, "No active subscription");
        
        // Calculate shares
        uint256 shares;
        if (pool.totalLiquidity == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * pool.totalShares) / pool.totalLiquidity;
        }
        
        uint256 positionId = positionCounter++;
        
        poolPositions[poolId].push(LiquidityPosition({
            positionId: positionId,
            poolId: poolId,
            provider: msg.sender,
            shares: shares,
            depositAmount: msg.value,
            depositTime: block.timestamp,
            lastClaimTime: block.timestamp,
            yieldEarned: 0,
            active: true
        }));
        
        providerPositions[msg.sender].push(positionId);
        
        pool.totalLiquidity += msg.value;
        pool.totalShares += shares;
        
        emit LiquidityAdded(poolId, positionId, msg.sender, msg.value);
        
        return positionId;
    }
    
    function removeLiquidity(uint256 poolId, uint256 positionId) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        LiquidityPool storage pool = pools[poolId];
        LiquidityPosition storage position = _findPosition(poolId, positionId);
        
        require(position.provider == msg.sender, "Not position owner");
        require(position.active, "Position not active");
        require(
            block.timestamp >= position.depositTime + pool.lockupPeriod,
            "Lockup period not ended"
        );
        
        // Calculate withdrawal amount
        uint256 withdrawAmount = (position.shares * pool.totalLiquidity) / pool.totalShares;
        
        // Apply management fee
        uint256 timeHeld = block.timestamp - position.depositTime;
        uint256 managementFeeAmount = (withdrawAmount * pool.managementFee * timeHeld) / 
                                      (BASIS_POINTS * 365 days);
        
        uint256 netAmount = withdrawAmount - managementFeeAmount;
        
        // Update pool
        pool.totalLiquidity -= withdrawAmount;
        pool.totalShares -= position.shares;
        position.active = false;
        
        // Transfer funds
        (bool success, ) = msg.sender.call{value: netAmount}("");
        require(success, "Transfer failed");
        
        // Collect fee
        if (managementFeeAmount > 0) {
            totalFeesCollected += managementFeeAmount;
        }
        
        emit LiquidityRemoved(poolId, positionId, netAmount);
        
        return netAmount;
    }
    
    function distributeYield(uint256 poolId, uint256 yieldAmount) 
        external 
        payable 
        onlyRole(MANAGER_ROLE) 
        nonReentrant 
    {
        LiquidityPool storage pool = pools[poolId];
        require(pool.active, "Pool not active");
        require(msg.value >= yieldAmount, "Insufficient yield");
        
        // Deduct performance fee
        uint256 performanceFeeAmount = (yieldAmount * pool.performanceFee) / BASIS_POINTS;
        uint256 netYield = yieldAmount - performanceFeeAmount;
        
        // Distribute to providers
        LiquidityPosition[] storage positions = poolPositions[poolId];
        
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].active) {
                uint256 providerShare = (netYield * positions[i].shares) / pool.totalShares;
                
                // Apply tier multiplier
                Subscription storage sub = subscriptions[positions[i].provider];
                if (sub.active) {
                    providerShare = (providerShare * tierMultipliers[sub.tier]) / BASIS_POINTS;
                }
                
                positions[i].yieldEarned += providerShare;
            }
        }
        
        totalFeesCollected += performanceFeeAmount;
        
        emit YieldDistributed(poolId, netYield);
    }
    
    function claimYield(uint256 poolId, uint256 positionId) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        LiquidityPosition storage position = _findPosition(poolId, positionId);
        require(position.provider == msg.sender, "Not position owner");
        require(position.yieldEarned > 0, "No yield to claim");
        
        uint256 yieldAmount = position.yieldEarned;
        position.yieldEarned = 0;
        position.lastClaimTime = block.timestamp;
        
        (bool success, ) = msg.sender.call{value: yieldAmount}("");
        require(success, "Transfer failed");
        
        return yieldAmount;
    }
    
    function purchaseSubscription(SubscriptionTier tier, uint256 duration) 
        external 
        payable 
        nonReentrant 
    {
        require(duration >= 30 days && duration <= 365 days, "Invalid duration");
        
        uint256 fee = (tierFees[tier] * duration) / 365 days;
        require(msg.value >= fee, "Insufficient payment");
        
        Subscription storage sub = subscriptions[msg.sender];
        
        uint256 startDate = block.timestamp;
        if (sub.active && block.timestamp < sub.endDate) {
            startDate = sub.endDate;
        }
        
        sub.tier = tier;
        sub.startDate = startDate;
        sub.endDate = startDate + duration;
        sub.fee = fee;
        sub.active = true;
        sub.autoRenew = false;
        
        totalFeesCollected += fee;
        
        emit SubscriptionPurchased(msg.sender, tier);
        
        // Refund excess
        if (msg.value > fee) {
            (bool success, ) = msg.sender.call{value: msg.value - fee}("");
            require(success, "Refund failed");
        }
    }
    
    function rebalancePool(
        uint256 poolId,
        address[] memory assets,
        uint256[] memory targetAllocations
    ) external onlyRole(MANAGER_ROLE) {
        require(assets.length == targetAllocations.length, "Length mismatch");
        
        LiquidityPool storage pool = pools[poolId];
        require(msg.sender == pool.manager, "Not pool manager");
        
        // Validate allocations sum to 100%
        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < targetAllocations.length; i++) {
            totalAllocation += targetAllocations[i];
        }
        require(totalAllocation == BASIS_POINTS, "Invalid allocations");
        
        // Clear existing assets
        delete poolAssets[poolId];
        
        // Add new asset allocations
        for (uint256 i = 0; i < assets.length; i++) {
            poolAssets[poolId].push(PoolAsset({
                assetAddress: assets[i],
                amount: 0,
                targetAllocation: targetAllocations[i],
                currentAllocation: 0
            }));
        }
        
        emit PoolRebalanced(poolId);
    }
    
    function updatePerformance(
        uint256 poolId,
        uint256 totalReturn,
        uint256 sharpeRatio,
        uint256 volatility,
        uint256 maxDrawdown
    ) external onlyRole(MANAGER_ROLE) {
        poolMetrics[poolId] = PerformanceMetrics({
            totalReturn: totalReturn,
            sharpeRatio: sharpeRatio,
            volatility: volatility,
            maxDrawdown: maxDrawdown,
            lastUpdate: block.timestamp
        });
    }
    
    function _findPosition(uint256 poolId, uint256 positionId) 
        internal 
        view 
        returns (LiquidityPosition storage) 
    {
        LiquidityPosition[] storage positions = poolPositions[poolId];
        
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].positionId == positionId) {
                return positions[i];
            }
        }
        
        revert("Position not found");
    }
    
    function setTierFee(SubscriptionTier tier, uint256 fee) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        tierFees[tier] = fee;
    }
    
    function setTierMultiplier(SubscriptionTier tier, uint256 multiplier) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(multiplier >= BASIS_POINTS && multiplier <= 15000, "Invalid multiplier");
        tierMultipliers[tier] = multiplier;
    }
    
    function deactivatePool(uint256 poolId) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        pools[poolId].active = false;
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getPool(uint256 poolId) 
        external 
        view 
        returns (LiquidityPool memory) 
    {
        return pools[poolId];
    }
    
    function getPoolAssets(uint256 poolId) 
        external 
        view 
        returns (PoolAsset[] memory) 
    {
        return poolAssets[poolId];
    }
    
    function getPoolPositions(uint256 poolId) 
        external 
        view 
        returns (LiquidityPosition[] memory) 
    {
        return poolPositions[poolId];
    }
    
    function getProviderPositions(address provider) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return providerPositions[provider];
    }
    
    function getSubscription(address user) 
        external 
        view 
        returns (Subscription memory) 
    {
        return subscriptions[user];
    }
    
    function getPerformanceMetrics(uint256 poolId) 
        external 
        view 
        returns (PerformanceMetrics memory) 
    {
        return poolMetrics[poolId];
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    receive() external payable {}
}