// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniversalAMM is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct LiquidityPool {
        uint256 poolId;
        address token0;
        uint256 tokenId0;
        address token1;
        uint256 tokenId1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalShares;
        uint256 feeBasisPoints;
        uint256 lastK;
        bool active;
    }

    struct PoolShare {
        uint256 shares;
        uint256 depositTime;
    }

    mapping(uint256 => LiquidityPool) public pools;
    mapping(uint256 => mapping(address => PoolShare)) public liquidityShares;
    mapping(bytes32 => uint256) public poolLookup;
    uint256 public poolCounter;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant BASIS_POINTS = 10000;

    event PoolCreated(
        uint256 indexed poolId,
        address indexed token0,
        uint256 tokenId0,
        address indexed token1,
        uint256 tokenId1,
        uint256 fee
    );
    event LiquidityAdded(
        uint256 indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event LiquidityRemoved(
        uint256 indexed poolId,
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event Swap(
        uint256 indexed poolId,
        address indexed trader,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function createPool(
        address token0,
        uint256 tokenId0,
        address token1,
        uint256 tokenId1,
        uint256 initialAmount0,
        uint256 initialAmount1,
        uint256 feeBasisPoints
    ) external nonReentrant whenNotPaused returns (uint256 poolId) {
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        require(initialAmount0 > 0 && initialAmount1 > 0, "Invalid amounts");
        require(feeBasisPoints <= 100, "Fee too high");

        bytes32 poolKey = keccak256(abi.encodePacked(token0, tokenId0, token1, tokenId1));
        require(poolLookup[poolKey] == 0, "Pool exists");

        poolId = ++poolCounter;

        pools[poolId] = LiquidityPool({
            poolId: poolId,
            token0: token0,
            tokenId0: tokenId0,
            token1: token1,
            tokenId1: tokenId1,
            reserve0: initialAmount0,
            reserve1: initialAmount1,
            totalShares: 0,
            feeBasisPoints: feeBasisPoints,
            lastK: 0,
            active: true
        });

        poolLookup[poolKey] = poolId;

        uint256 shares = _sqrt(initialAmount0 * initialAmount1);
        require(shares > MINIMUM_LIQUIDITY, "Insufficient liquidity");

        shares -= MINIMUM_LIQUIDITY;
        pools[poolId].totalShares = shares + MINIMUM_LIQUIDITY;
        pools[poolId].lastK = initialAmount0 * initialAmount1;

        liquidityShares[poolId][msg.sender] = PoolShare({
            shares: shares,
            depositTime: block.timestamp
        });

        IERC1155(token0).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId0,
            initialAmount0,
            ""
        );
        IERC1155(token1).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId1,
            initialAmount1,
            ""
        );

        emit PoolCreated(poolId, token0, tokenId0, token1, tokenId1, feeBasisPoints);
        emit LiquidityAdded(poolId, msg.sender, initialAmount0, initialAmount1, shares);
    }

    function addLiquidity(
        uint256 poolId,
        uint256 amount0,
        uint256 amount1,
        uint256 minShares
    ) external nonReentrant whenNotPaused returns (uint256 shares) {
        LiquidityPool storage pool = pools[poolId];
        require(pool.active, "Pool not active");
        require(amount0 > 0 && amount1 > 0, "Invalid amounts");

        uint256 amount0Optimal = (amount1 * pool.reserve0) / pool.reserve1;
        uint256 amount1Optimal = (amount0 * pool.reserve1) / pool.reserve0;

        require(
            amount0 >= amount0Optimal || amount1 >= amount1Optimal,
            "Insufficient amounts"
        );

        if (amount0Optimal <= amount0) {
            amount0 = amount0Optimal;
        } else {
            amount1 = amount1Optimal;
        }

        shares = _min(
            (amount0 * pool.totalShares) / pool.reserve0,
            (amount1 * pool.totalShares) / pool.reserve1
        );

        require(shares >= minShares, "Slippage exceeded");

        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalShares += shares;
        pool.lastK = pool.reserve0 * pool.reserve1;

        liquidityShares[poolId][msg.sender].shares += shares;
        liquidityShares[poolId][msg.sender].depositTime = block.timestamp;

        IERC1155(pool.token0).safeTransferFrom(
            msg.sender,
            address(this),
            pool.tokenId0,
            amount0,
            ""
        );
        IERC1155(pool.token1).safeTransferFrom(
            msg.sender,
            address(this),
            pool.tokenId1,
            amount1,
            ""
        );

        emit LiquidityAdded(poolId, msg.sender, amount0, amount1, shares);
    }

    function removeLiquidity(
        uint256 poolId,
        uint256 shares,
        uint256 minAmount0,
        uint256 minAmount1
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        LiquidityPool storage pool = pools[poolId];
        PoolShare storage userShare = liquidityShares[poolId][msg.sender];

        require(shares > 0 && shares <= userShare.shares, "Invalid shares");

        amount0 = (shares * pool.reserve0) / pool.totalShares;
        amount1 = (shares * pool.reserve1) / pool.totalShares;

        require(amount0 >= minAmount0 && amount1 >= minAmount1, "Slippage exceeded");

        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalShares -= shares;
        pool.lastK = pool.reserve0 * pool.reserve1;

        userShare.shares -= shares;

        IERC1155(pool.token0).safeTransferFrom(
            address(this),
            msg.sender,
            pool.tokenId0,
            amount0,
            ""
        );
        IERC1155(pool.token1).safeTransferFrom(
            address(this),
            msg.sender,
            pool.tokenId1,
            amount1,
            ""
        );

        emit LiquidityRemoved(poolId, msg.sender, amount0, amount1, shares);
    }

    function swap(
        uint256 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        LiquidityPool storage pool = pools[poolId];
        require(pool.active, "Pool not active");
        require(amountIn > 0, "Invalid amount");

        bool isToken0 = tokenIn == pool.token0;
        require(isToken0 || tokenIn == pool.token1, "Invalid token");

        (uint256 reserveIn, uint256 reserveOut, uint256 tokenIdIn, uint256 tokenIdOut, address tokenOut) = isToken0
            ? (pool.reserve0, pool.reserve1, pool.tokenId0, pool.tokenId1, pool.token1)
            : (pool.reserve1, pool.reserve0, pool.tokenId1, pool.tokenId0, pool.token0);

        uint256 amountInWithFee = amountIn * (BASIS_POINTS - pool.feeBasisPoints);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * BASIS_POINTS + amountInWithFee);

        require(amountOut >= minAmountOut, "Slippage exceeded");
        require(amountOut < reserveOut, "Insufficient liquidity");

        if (isToken0) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        require(pool.reserve0 * pool.reserve1 >= pool.lastK, "K invariant violated");
        pool.lastK = pool.reserve0 * pool.reserve1;

        IERC1155(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            tokenIdIn,
            amountIn,
            ""
        );
        IERC1155(tokenOut).safeTransferFrom(
            address(this),
            msg.sender,
            tokenIdOut,
            amountOut,
            ""
        );

        emit Swap(poolId, msg.sender, tokenIn, amountIn, amountOut);
    }

    function getAmountOut(
        uint256 poolId,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        LiquidityPool storage pool = pools[poolId];
        require(pool.active, "Pool not active");

        bool isToken0 = tokenIn == pool.token0;
        (uint256 reserveIn, uint256 reserveOut) = isToken0
            ? (pool.reserve0, pool.reserve1)
            : (pool.reserve1, pool.reserve0);

        uint256 amountInWithFee = amountIn * (BASIS_POINTS - pool.feeBasisPoints);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * BASIS_POINTS + amountInWithFee);
    }

    function getPoolId(
        address token0,
        uint256 tokenId0,
        address token1,
        uint256 tokenId1
    ) external view returns (uint256) {
        bytes32 poolKey = keccak256(abi.encodePacked(token0, tokenId0, token1, tokenId1));
        return poolLookup[poolKey];
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
