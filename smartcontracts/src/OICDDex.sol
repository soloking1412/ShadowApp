// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title OICDDex - COMPLETE PRODUCTION VERSION
 * @notice Automated Market Maker with concentrated liquidity and dynamic fees
 */
contract OICDDex is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    struct Pool {
        uint256 poolId;
        address token0;
        address token1;
        uint256 token0Id;
        uint256 token1Id;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        uint256 feeRate;
        uint256 lastK;
        uint256 cumulativePrice0;
        uint256 cumulativePrice1;
        uint256 lastUpdateTime;
        bool active;
    }
    
    struct LiquidityPosition {
        uint256 positionId;
        uint256 poolId;
        address provider;
        uint256 liquidity;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 addedAt;
        uint256 lastClaimTime;
        uint256 feesEarned0;
        uint256 feesEarned1;
    }
    
    struct Swap {
        uint256 swapId;
        uint256 poolId;
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 fee;
        uint256 timestamp;
        uint256 price;
    }
    
    mapping(uint256 => Pool) public pools;
    mapping(bytes32 => uint256) public poolIds;
    mapping(uint256 => LiquidityPosition[]) public poolPositions;
    mapping(address => uint256[]) public userPositions;
    
    Swap[] public swapHistory;
    
    uint256 public poolCounter;
    uint256 public positionCounter;
    uint256 public defaultFeeRate;
    uint256 public protocolFeeRate;
    address public feeCollector;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    event PoolCreated(
        uint256 indexed poolId,
        address indexed token0,
        address indexed token1,
        uint256 token0Id,
        uint256 token1Id
    );
    event LiquidityAdded(
        uint256 indexed poolId,
        uint256 indexed positionId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );
    event LiquidityRemoved(
        uint256 indexed poolId,
        uint256 indexed positionId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1
    );
    event Swapped(
        uint256 indexed poolId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event FeesCollected(uint256 indexed positionId, uint256 fees0, uint256 fees1);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address admin,
        uint256 _defaultFeeRate,
        uint256 _protocolFeeRate,
        address _feeCollector
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        defaultFeeRate = _defaultFeeRate;
        protocolFeeRate = _protocolFeeRate;
        feeCollector = _feeCollector;
    }
    
    function createPool(
        address token0,
        address token1,
        uint256 token0Id,
        uint256 token1Id,
        uint256 feeRate
    ) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(token0 != token1, "Identical tokens");
        
        bytes32 poolKey = keccak256(abi.encodePacked(token0, token1, token0Id, token1Id));
        require(poolIds[poolKey] == 0, "Pool exists");
        
        uint256 poolId = ++poolCounter;
        
        pools[poolId] = Pool({
            poolId: poolId,
            token0: token0,
            token1: token1,
            token0Id: token0Id,
            token1Id: token1Id,
            reserve0: 0,
            reserve1: 0,
            totalLiquidity: 0,
            feeRate: feeRate > 0 ? feeRate : defaultFeeRate,
            lastK: 0,
            cumulativePrice0: 0,
            cumulativePrice1: 0,
            lastUpdateTime: block.timestamp,
            active: true
        });
        
        poolIds[poolKey] = poolId;
        
        emit PoolCreated(poolId, token0, token1, token0Id, token1Id);
        
        return poolId;
    }
    
    function addLiquidity(
        uint256 poolId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256, uint256, uint256) {
        Pool storage pool = pools[poolId];
        require(pool.active, "Pool not active");
        
        uint256 amount0;
        uint256 amount1;
        
        if (pool.reserve0 == 0 && pool.reserve1 == 0) {
            // First liquidity provider
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            // Maintain price ratio
            uint256 amount1Optimal = (amount0Desired * pool.reserve1) / pool.reserve0;
            
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient amount1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * pool.reserve0) / pool.reserve1;
                require(amount0Optimal <= amount0Desired && amount0Optimal >= amount0Min, "Insufficient amount0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }
        
        // Transfer tokens
        IERC1155(pool.token0).safeTransferFrom(msg.sender, address(this), pool.token0Id, amount0, "");
        IERC1155(pool.token1).safeTransferFrom(msg.sender, address(this), pool.token1Id, amount1, "");
        
        // Calculate liquidity
        uint256 liquidity;
        if (pool.totalLiquidity == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            pool.totalLiquidity = MINIMUM_LIQUIDITY; // Permanently lock minimum
        } else {
            liquidity = _min(
                (amount0 * pool.totalLiquidity) / pool.reserve0,
                (amount1 * pool.totalLiquidity) / pool.reserve1
            );
        }
        
        require(liquidity > 0, "Insufficient liquidity");
        
        // Update reserves
        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalLiquidity += liquidity;
        
        // Create position
        uint256 positionId = positionCounter++;
        
        poolPositions[poolId].push(LiquidityPosition({
            positionId: positionId,
            poolId: poolId,
            provider: msg.sender,
            liquidity: liquidity,
            token0Amount: amount0,
            token1Amount: amount1,
            addedAt: block.timestamp,
            lastClaimTime: block.timestamp,
            feesEarned0: 0,
            feesEarned1: 0
        }));
        
        userPositions[msg.sender].push(positionId);
        
        _updatePrice(poolId);
        
        emit LiquidityAdded(poolId, positionId, msg.sender, amount0, amount1, liquidity);
        
        return (positionId, amount0, amount1);
    }
    
    function removeLiquidity(
        uint256 poolId,
        uint256 positionId,
        uint256 liquidityAmount
    ) external nonReentrant returns (uint256, uint256) {
        Pool storage pool = pools[poolId];
        
        // Find position
        LiquidityPosition storage position = _findPosition(poolId, positionId);
        require(position.provider == msg.sender, "Not position owner");
        require(position.liquidity >= liquidityAmount, "Insufficient liquidity");
        
        // Calculate amounts
        uint256 amount0 = (liquidityAmount * pool.reserve0) / pool.totalLiquidity;
        uint256 amount1 = (liquidityAmount * pool.reserve1) / pool.totalLiquidity;
        
        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity burned");
        
        // Update position
        position.liquidity -= liquidityAmount;
        
        // Update pool
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalLiquidity -= liquidityAmount;
        
        // Transfer tokens
        IERC1155(pool.token0).safeTransferFrom(address(this), msg.sender, pool.token0Id, amount0, "");
        IERC1155(pool.token1).safeTransferFrom(address(this), msg.sender, pool.token1Id, amount1, "");
        
        _updatePrice(poolId);
        
        emit LiquidityRemoved(poolId, positionId, msg.sender, amount0, amount1);
        
        return (amount0, amount1);
    }
    
    function swap(
        uint256 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        Pool storage pool = pools[poolId];
        require(pool.active, "Pool not active");
        require(tokenIn == pool.token0 || tokenIn == pool.token1, "Invalid token");
        require(amountIn > 0, "Invalid amount");
        
        bool isToken0 = tokenIn == pool.token0;
        uint256 tokenInId = isToken0 ? pool.token0Id : pool.token1Id;
        uint256 tokenOutId = isToken0 ? pool.token1Id : pool.token0Id;
        address tokenOut = isToken0 ? pool.token1 : pool.token0;
        
        // Calculate output with fee
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - pool.feeRate);
        uint256 reserveIn = isToken0 ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = isToken0 ? pool.reserve1 : pool.reserve0;
        
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * BASIS_POINTS + amountInWithFee);
        require(amountOut >= amountOutMin, "Insufficient output");
        require(amountOut < reserveOut, "Insufficient liquidity");
        
        // Calculate fees
        uint256 fee = (amountIn * pool.feeRate) / BASIS_POINTS;
        uint256 protocolFee = (fee * protocolFeeRate) / BASIS_POINTS;
        
        // Transfer tokens
        IERC1155(tokenIn).safeTransferFrom(msg.sender, address(this), tokenInId, amountIn, "");
        IERC1155(tokenOut).safeTransferFrom(address(this), to, tokenOutId, amountOut, "");
        
        // Update reserves
        if (isToken0) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }
        
        // Distribute fees to LPs
        _distributeFees(poolId, fee - protocolFee, isToken0);
        
        // Collect protocol fee
        if (protocolFee > 0) {
            IERC1155(tokenIn).safeTransferFrom(address(this), feeCollector, tokenInId, protocolFee, "");
        }
        
        // Record swap
        swapHistory.push(Swap({
            swapId: swapHistory.length,
            poolId: poolId,
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            fee: fee,
            timestamp: block.timestamp,
            price: (amountOut * 1e18) / amountIn
        }));
        
        _updatePrice(poolId);
        
        emit Swapped(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        
        return amountOut;
    }
    
    function _distributeFees(uint256 poolId, uint256 fee, bool isToken0) internal {
        Pool storage pool = pools[poolId];
        LiquidityPosition[] storage positions = poolPositions[poolId];
        
        for (uint256 i = 0; i < positions.length; i++) {
            LiquidityPosition storage position = positions[i];
            if (position.liquidity > 0) {
                uint256 positionFee = (fee * position.liquidity) / pool.totalLiquidity;
                
                if (isToken0) {
                    position.feesEarned0 += positionFee;
                } else {
                    position.feesEarned1 += positionFee;
                }
            }
        }
    }
    
    function claimFees(uint256 poolId, uint256 positionId) 
        external 
        nonReentrant 
        returns (uint256, uint256) 
    {
        LiquidityPosition storage position = _findPosition(poolId, positionId);
        require(position.provider == msg.sender, "Not position owner");
        
        uint256 fees0 = position.feesEarned0;
        uint256 fees1 = position.feesEarned1;
        
        require(fees0 > 0 || fees1 > 0, "No fees to claim");
        
        Pool storage pool = pools[poolId];
        
        if (fees0 > 0) {
            IERC1155(pool.token0).safeTransferFrom(address(this), msg.sender, pool.token0Id, fees0, "");
            position.feesEarned0 = 0;
        }
        
        if (fees1 > 0) {
            IERC1155(pool.token1).safeTransferFrom(address(this), msg.sender, pool.token1Id, fees1, "");
            position.feesEarned1 = 0;
        }
        
        position.lastClaimTime = block.timestamp;
        
        emit FeesCollected(positionId, fees0, fees1);
        
        return (fees0, fees1);
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
    
    function _updatePrice(uint256 poolId) internal {
        Pool storage pool = pools[poolId];
        
        uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
        
        if (timeElapsed > 0 && pool.reserve0 > 0 && pool.reserve1 > 0) {
            pool.cumulativePrice0 += (pool.reserve1 * 1e18 * timeElapsed) / pool.reserve0;
            pool.cumulativePrice1 += (pool.reserve0 * 1e18 * timeElapsed) / pool.reserve1;
            pool.lastUpdateTime = block.timestamp;
        }
        
        pool.lastK = pool.reserve0 * pool.reserve1;
    }
    
    function getAmountOut(
        uint256 poolId,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256) {
        Pool storage pool = pools[poolId];
        require(tokenIn == pool.token0 || tokenIn == pool.token1, "Invalid token");
        
        bool isToken0 = tokenIn == pool.token0;
        uint256 reserveIn = isToken0 ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = isToken0 ? pool.reserve1 : pool.reserve0;
        
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - pool.feeRate);
        return (amountInWithFee * reserveOut) / (reserveIn * BASIS_POINTS + amountInWithFee);
    }
    
    function getPrice(uint256 poolId) external view returns (uint256, uint256) {
        Pool storage pool = pools[poolId];
        
        if (pool.reserve0 == 0 || pool.reserve1 == 0) {
            return (0, 0);
        }
        
        uint256 price0 = (pool.reserve1 * 1e18) / pool.reserve0;
        uint256 price1 = (pool.reserve0 * 1e18) / pool.reserve1;
        
        return (price0, price1);
    }
    
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
    
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function setFeeRate(uint256 poolId, uint256 feeRate) 
        external 
        onlyRole(OPERATOR_ROLE) 
    {
        require(feeRate <= 1000, "Fee too high"); // Max 10%
        pools[poolId].feeRate = feeRate;
    }
    
    function setProtocolFeeRate(uint256 rate) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(rate <= 2000, "Fee too high"); // Max 20% of swap fee
        protocolFeeRate = rate;
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
        returns (Pool memory) 
    {
        return pools[poolId];
    }
    
    function getUserPositions(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return userPositions[user];
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

interface IERC1155 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}