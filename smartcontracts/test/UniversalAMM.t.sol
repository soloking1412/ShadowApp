// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../src/UniversalAMM.sol";

/// @notice Minimal ERC1155 mock used as pool tokens
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }

    function setApprovalForAll(address operator, bool approved) public override {
        super.setApprovalForAll(operator, approved);
    }
}

contract UniversalAMMTest is Test {
    UniversalAMM public amm;
    MockERC1155 public tokenA;
    MockERC1155 public tokenB;

    address public admin  = address(1);
    address public lp     = address(2);
    address public trader = address(3);
    address public unauthorized = address(4);

    uint256 public constant TOKEN_ID_0 = 1;
    uint256 public constant TOKEN_ID_1 = 2;
    uint256 public constant INIT_AMOUNT_0 = 10_000 * 1e18;
    uint256 public constant INIT_AMOUNT_1 = 20_000 * 1e18;
    uint256 public constant FEE_BPS = 30; // 0.30%

    // ─── Setup ────────────────────────────────────────────────────────────────

    function setUp() public {
        UniversalAMM impl = new UniversalAMM();
        bytes memory init = abi.encodeCall(UniversalAMM.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        amm = UniversalAMM(address(proxy));

        tokenA = new MockERC1155();
        tokenB = new MockERC1155();

        // Mint tokens to liquidity provider and trader
        tokenA.mint(lp, TOKEN_ID_0, 100_000 * 1e18);
        tokenB.mint(lp, TOKEN_ID_1, 100_000 * 1e18);
        tokenA.mint(trader, TOKEN_ID_0, 10_000 * 1e18);
        tokenB.mint(trader, TOKEN_ID_1, 10_000 * 1e18);

        // Approve AMM to spend tokens
        vm.prank(lp);
        tokenA.setApprovalForAll(address(amm), true);
        vm.prank(lp);
        tokenB.setApprovalForAll(address(amm), true);
        vm.prank(trader);
        tokenA.setApprovalForAll(address(amm), true);
        vm.prank(trader);
        tokenB.setApprovalForAll(address(amm), true);
    }

    // ─── Initialization ───────────────────────────────────────────────────────

    function test_Initialize_AdminRoles() public view {
        assertTrue(amm.hasRole(amm.ADMIN_ROLE(), admin));
        assertTrue(amm.hasRole(amm.OPERATOR_ROLE(), admin));
        assertTrue(amm.hasRole(amm.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_Initialize_PoolCounterZero() public view {
        assertEq(amm.poolCounter(), 0);
    }

    function test_Initialize_Constants() public view {
        assertEq(amm.MINIMUM_LIQUIDITY(), 1000);
        assertEq(amm.BASIS_POINTS(), 10000);
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        amm.initialize(admin);
    }

    // ─── Create Pool ──────────────────────────────────────────────────────────

    function _createPool() internal returns (uint256 poolId) {
        vm.prank(lp);
        poolId = amm.createPool(
            address(tokenA), TOKEN_ID_0,
            address(tokenB), TOKEN_ID_1,
            INIT_AMOUNT_0, INIT_AMOUNT_1,
            FEE_BPS
        );
    }

    function test_CreatePool_ReturnsPoolId1() public {
        uint256 poolId = _createPool();
        assertEq(poolId, 1);
        assertEq(amm.poolCounter(), 1);
    }

    function test_CreatePool_StoresPoolData() public {
        uint256 poolId = _createPool();
        (
            uint256 pid,
            address t0,
            uint256 tid0,
            address t1,
            uint256 tid1,
            uint256 r0,
            uint256 r1,
            uint256 totalShares,
            uint256 fee,
            ,
            bool active
        ) = amm.pools(poolId);

        assertEq(pid, 1);
        assertEq(t0, address(tokenA));
        assertEq(tid0, TOKEN_ID_0);
        assertEq(t1, address(tokenB));
        assertEq(tid1, TOKEN_ID_1);
        assertEq(r0, INIT_AMOUNT_0);
        assertEq(r1, INIT_AMOUNT_1);
        assertGt(totalShares, 0);
        assertEq(fee, FEE_BPS);
        assertTrue(active);
    }

    function test_CreatePool_TransfersTokensIn() public {
        uint256 balBeforeA = tokenA.balanceOf(lp, TOKEN_ID_0);
        uint256 balBeforeB = tokenB.balanceOf(lp, TOKEN_ID_1);

        _createPool();

        assertEq(tokenA.balanceOf(lp, TOKEN_ID_0), balBeforeA - INIT_AMOUNT_0);
        assertEq(tokenB.balanceOf(lp, TOKEN_ID_1), balBeforeB - INIT_AMOUNT_1);
        assertEq(tokenA.balanceOf(address(amm), TOKEN_ID_0), INIT_AMOUNT_0);
        assertEq(tokenB.balanceOf(address(amm), TOKEN_ID_1), INIT_AMOUNT_1);
    }

    function test_CreatePool_EmitsPoolCreatedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit UniversalAMM.PoolCreated(1, address(tokenA), TOKEN_ID_0, address(tokenB), TOKEN_ID_1, FEE_BPS);

        vm.prank(lp);
        amm.createPool(
            address(tokenA), TOKEN_ID_0,
            address(tokenB), TOKEN_ID_1,
            INIT_AMOUNT_0, INIT_AMOUNT_1,
            FEE_BPS
        );
    }

    function test_CreatePool_EmitsLiquidityAddedEvent() public {
        vm.expectEmit(true, true, false, false);
        emit UniversalAMM.LiquidityAdded(1, lp, INIT_AMOUNT_0, INIT_AMOUNT_1, 0);

        _createPool();
    }

    function test_CreatePool_RevertsZeroAddress() public {
        vm.prank(lp);
        vm.expectRevert("Invalid tokens");
        amm.createPool(
            address(0), TOKEN_ID_0,
            address(tokenB), TOKEN_ID_1,
            INIT_AMOUNT_0, INIT_AMOUNT_1,
            FEE_BPS
        );
    }

    function test_CreatePool_RevertsZeroAmounts() public {
        vm.prank(lp);
        vm.expectRevert("Invalid amounts");
        amm.createPool(
            address(tokenA), TOKEN_ID_0,
            address(tokenB), TOKEN_ID_1,
            0, INIT_AMOUNT_1,
            FEE_BPS
        );
    }

    function test_CreatePool_RevertsFeeTooHigh() public {
        vm.prank(lp);
        vm.expectRevert("Fee too high");
        amm.createPool(
            address(tokenA), TOKEN_ID_0,
            address(tokenB), TOKEN_ID_1,
            INIT_AMOUNT_0, INIT_AMOUNT_1,
            101   // over 100 bps = 1%
        );
    }

    function test_CreatePool_RevertsWhenPaused() public {
        vm.prank(admin);
        amm.pause();

        vm.prank(lp);
        vm.expectRevert();
        amm.createPool(
            address(tokenA), TOKEN_ID_0,
            address(tokenB), TOKEN_ID_1,
            INIT_AMOUNT_0, INIT_AMOUNT_1,
            FEE_BPS
        );
    }

    function test_CreatePool_ReverstDuplicatePool() public {
        _createPool();

        // Attempt to create the same pool again
        vm.prank(lp);
        vm.expectRevert("Pool exists");
        amm.createPool(
            address(tokenA), TOKEN_ID_0,
            address(tokenB), TOKEN_ID_1,
            INIT_AMOUNT_0, INIT_AMOUNT_1,
            FEE_BPS
        );
    }

    function test_CreatePool_PoolLookup() public {
        _createPool();
        uint256 poolId = amm.getPoolId(address(tokenA), TOKEN_ID_0, address(tokenB), TOKEN_ID_1);
        assertEq(poolId, 1);
    }

    // ─── Add Liquidity ────────────────────────────────────────────────────────

    function test_AddLiquidity_IncreasesReserves() public {
        uint256 poolId = _createPool();

        uint256 add0 = 1_000 * 1e18;
        uint256 add1 = 2_000 * 1e18;

        vm.prank(lp);
        uint256 shares = amm.addLiquidity(poolId, add0, add1, 0);

        assertGt(shares, 0);

        (, , , , , uint256 r0, uint256 r1, , , , ) = amm.pools(poolId);
        assertGe(r0, INIT_AMOUNT_0 + add0 - 1); // allow 1 wei rounding
        assertGe(r1, INIT_AMOUNT_1 + add1 - 1);
    }

    function test_AddLiquidity_EmitsEvent() public {
        uint256 poolId = _createPool();

        vm.expectEmit(true, true, false, false);
        emit UniversalAMM.LiquidityAdded(poolId, lp, 0, 0, 0);

        vm.prank(lp);
        amm.addLiquidity(poolId, 1_000 * 1e18, 2_000 * 1e18, 0);
    }

    function test_AddLiquidity_RevertsSlippage() public {
        uint256 poolId = _createPool();

        // Request more shares than available
        vm.prank(lp);
        vm.expectRevert("Slippage exceeded");
        amm.addLiquidity(poolId, 1_000 * 1e18, 2_000 * 1e18, type(uint256).max);
    }

    function test_AddLiquidity_RevertsInactivePool() public {
        // Use a non-existent pool
        vm.prank(lp);
        vm.expectRevert("Pool not active");
        amm.addLiquidity(999, 1_000 * 1e18, 2_000 * 1e18, 0);
    }

    // ─── Remove Liquidity ─────────────────────────────────────────────────────

    function test_RemoveLiquidity_ReturnsTokens() public {
        uint256 poolId = _createPool();

        (uint256 sharesHeld, ) = amm.liquidityShares(poolId, lp);
        assertGt(sharesHeld, 0);

        uint256 balBeforeA = tokenA.balanceOf(lp, TOKEN_ID_0);
        uint256 balBeforeB = tokenB.balanceOf(lp, TOKEN_ID_1);

        vm.prank(lp);
        (uint256 amount0, uint256 amount1) = amm.removeLiquidity(poolId, sharesHeld, 0, 0);

        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(tokenA.balanceOf(lp, TOKEN_ID_0), balBeforeA + amount0);
        assertEq(tokenB.balanceOf(lp, TOKEN_ID_1), balBeforeB + amount1);
    }

    function test_RemoveLiquidity_EmitsEvent() public {
        uint256 poolId = _createPool();
        (uint256 shares, ) = amm.liquidityShares(poolId, lp);

        vm.expectEmit(true, true, false, false);
        emit UniversalAMM.LiquidityRemoved(poolId, lp, 0, 0, shares);

        vm.prank(lp);
        amm.removeLiquidity(poolId, shares, 0, 0);
    }

    function test_RemoveLiquidity_RevertsInsufficientShares() public {
        uint256 poolId = _createPool();
        (uint256 shares, ) = amm.liquidityShares(poolId, lp);

        vm.prank(lp);
        vm.expectRevert("Invalid shares");
        amm.removeLiquidity(poolId, shares + 1, 0, 0);
    }

    function test_RemoveLiquidity_RevertsSlippage() public {
        uint256 poolId = _createPool();
        (uint256 shares, ) = amm.liquidityShares(poolId, lp);

        vm.prank(lp);
        vm.expectRevert("Slippage exceeded");
        amm.removeLiquidity(poolId, shares, type(uint256).max, 0);
    }

    // ─── Swap ─────────────────────────────────────────────────────────────────

    function test_Swap_Token0ForToken1() public {
        uint256 poolId = _createPool();

        uint256 swapIn = 100 * 1e18;
        uint256 expectedOut = amm.getAmountOut(poolId, address(tokenA), swapIn);
        assertGt(expectedOut, 0);

        uint256 traderBalBefore = tokenB.balanceOf(trader, TOKEN_ID_1);

        vm.prank(trader);
        uint256 amountOut = amm.swap(poolId, address(tokenA), swapIn, 0);

        assertEq(amountOut, expectedOut);
        assertEq(tokenB.balanceOf(trader, TOKEN_ID_1), traderBalBefore + amountOut);
    }

    function test_Swap_Token1ForToken0() public {
        uint256 poolId = _createPool();

        uint256 swapIn = 200 * 1e18;
        uint256 traderBalBefore = tokenA.balanceOf(trader, TOKEN_ID_0);

        vm.prank(trader);
        uint256 amountOut = amm.swap(poolId, address(tokenB), swapIn, 0);

        assertGt(amountOut, 0);
        assertEq(tokenA.balanceOf(trader, TOKEN_ID_0), traderBalBefore + amountOut);
    }

    function test_Swap_EmitsSwapEvent() public {
        uint256 poolId = _createPool();
        uint256 swapIn = 100 * 1e18;

        vm.expectEmit(true, true, false, false);
        emit UniversalAMM.Swap(poolId, trader, address(tokenA), swapIn, 0);

        vm.prank(trader);
        amm.swap(poolId, address(tokenA), swapIn, 0);
    }

    function test_Swap_RevertsSlippage() public {
        uint256 poolId = _createPool();
        uint256 swapIn = 100 * 1e18;
        uint256 expectedOut = amm.getAmountOut(poolId, address(tokenA), swapIn);

        vm.prank(trader);
        vm.expectRevert("Slippage exceeded");
        amm.swap(poolId, address(tokenA), swapIn, expectedOut + 1);
    }

    function test_Swap_RevertsZeroAmount() public {
        uint256 poolId = _createPool();

        vm.prank(trader);
        vm.expectRevert("Invalid amount");
        amm.swap(poolId, address(tokenA), 0, 0);
    }

    function test_Swap_RevertsInvalidToken() public {
        uint256 poolId = _createPool();

        vm.prank(trader);
        vm.expectRevert("Invalid token");
        amm.swap(poolId, address(0xDEAD), 100 * 1e18, 0);
    }

    function test_Swap_RevertsWhenPaused() public {
        uint256 poolId = _createPool();

        vm.prank(admin);
        amm.pause();

        vm.prank(trader);
        vm.expectRevert();
        amm.swap(poolId, address(tokenA), 100 * 1e18, 0);
    }

    function test_Swap_FeeReducesOutput() public {
        // Create a zero-fee pool and compare output
        MockERC1155 tokenC = new MockERC1155();
        MockERC1155 tokenD = new MockERC1155();
        tokenC.mint(lp, TOKEN_ID_0, 100_000 * 1e18);
        tokenD.mint(lp, TOKEN_ID_1, 100_000 * 1e18);
        tokenC.mint(trader, TOKEN_ID_0, 10_000 * 1e18);
        vm.prank(lp);
        tokenC.setApprovalForAll(address(amm), true);
        vm.prank(lp);
        tokenD.setApprovalForAll(address(amm), true);
        vm.prank(trader);
        tokenC.setApprovalForAll(address(amm), true);

        // Pool with no fee
        vm.prank(lp);
        uint256 poolNoFee = amm.createPool(
            address(tokenC), TOKEN_ID_0,
            address(tokenD), TOKEN_ID_1,
            INIT_AMOUNT_0, INIT_AMOUNT_1,
            0 // zero fee
        );

        uint256 swapIn = 100 * 1e18;
        uint256 outNoFee = amm.getAmountOut(poolNoFee, address(tokenC), swapIn);
        uint256 outWithFee = amm.getAmountOut(1, address(tokenA), swapIn); // original 30 bps pool

        assertGt(outNoFee, outWithFee, "Zero-fee pool should give more output");
    }

    // ─── Pause / Unpause ──────────────────────────────────────────────────────

    function test_Pause_ByAdmin() public {
        vm.prank(admin);
        amm.pause();
        assertTrue(amm.paused());
    }

    function test_Unpause_ByAdmin() public {
        vm.startPrank(admin);
        amm.pause();
        amm.unpause();
        vm.stopPrank();
        assertFalse(amm.paused());
    }

    function test_Pause_RevertsNonAdmin() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        amm.pause();
    }

    // ─── Get Amount Out (view) ────────────────────────────────────────────────

    function test_GetAmountOut_MatchesSwapOutput() public {
        uint256 poolId = _createPool();
        uint256 swapIn = 500 * 1e18;
        uint256 preview = amm.getAmountOut(poolId, address(tokenA), swapIn);

        vm.prank(trader);
        uint256 actual = amm.swap(poolId, address(tokenA), swapIn, 0);

        assertEq(preview, actual);
    }

    function test_GetAmountOut_RevertsInactivePool() public {
        vm.expectRevert("Pool not active");
        amm.getAmountOut(999, address(tokenA), 100 * 1e18);
    }
}
