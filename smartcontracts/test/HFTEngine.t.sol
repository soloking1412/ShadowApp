// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/HFTEngine.sol";

contract HFTEngineTest is Test {
    HFTEngine public engine;

    address public owner   = address(1);
    address public trader  = address(2);
    address public trader2 = address(3);
    address public executor = address(4);
    address public unauthorized = address(5);

    // ─── Setup ────────────────────────────────────────────────────────────────

    function setUp() public {
        HFTEngine impl = new HFTEngine();
        bytes memory init = abi.encodeCall(HFTEngine.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        engine = HFTEngine(address(proxy));
    }

    // ─── Initialization ───────────────────────────────────────────────────────

    function test_Initialize_SetsOwner() public view {
        assertEq(engine.owner(), owner);
    }

    function test_Initialize_DefaultGLTEParameters() public view {
        HFTEngine.GLTEParameters memory p = engine.getGLTEParams();
        assertEq(p.W_t, 1_000_000 * 1e18);
        assertEq(p.OICD, 197 * 1e18);
        assertEq(p.yuan_OICD_peg, 1e18);
        assertGt(p.chi_in, 0);
        assertGt(p.chi_out, 0);
        assertGt(p.updatedAt, 0);
    }

    function test_Initialize_CountersAtZero() public view {
        assertEq(engine.orderCounter(), 0);
        assertEq(engine.signalCounter(), 0);
        assertEq(engine.totalOrdersProcessed(), 0);
        assertEq(engine.totalVolumeTraded(), 0);
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        engine.initialize(owner);
    }

    // ─── GLTE Computation ─────────────────────────────────────────────────────

    function test_ComputeGLTE_ReturnsNonZeroValues() public view {
        (uint256 L_in, uint256 L_out) = engine.computeGLTE();
        assertGt(L_in, 0, "L_in should be non-zero");
        assertGt(L_out, 0, "L_out should be non-zero");
    }

    function test_ComputeGLTE_LInIncludesBSEAndBursa() public view {
        HFTEngine.GLTEParameters memory p = engine.getGLTEParams();
        (uint256 L_in, ) = engine.computeGLTE();
        // L_in >= r_BSE_Delhi + r_Bursa_Malaysia
        assertGe(L_in, p.r_BSE_Delhi + p.r_Bursa_Malaysia);
    }

    function test_ComputeGLTE_DeterministicView() public view {
        (uint256 L_in1, uint256 L_out1) = engine.computeGLTE();
        (uint256 L_in2, uint256 L_out2) = engine.computeGLTE();
        assertEq(L_in1, L_in2);
        assertEq(L_out1, L_out2);
    }

    // ─── Emit GLTE Signal ─────────────────────────────────────────────────────

    function test_EmitGLTESignal_ByOwner() public {
        vm.prank(owner);
        uint256 signalId = engine.emitGLTESignal();
        assertEq(signalId, 1);
        assertEq(engine.signalCounter(), 1);
    }

    function test_EmitGLTESignal_ByAuthorizedExecutor() public {
        vm.prank(owner);
        engine.setExecutor(executor, true);

        vm.prank(executor);
        uint256 signalId = engine.emitGLTESignal();
        assertEq(signalId, 1);
    }

    function test_EmitGLTESignal_PopulatesLatestSignal() public {
        vm.prank(owner);
        engine.emitGLTESignal();

        HFTEngine.GLTESignal memory sig = engine.getLatestSignal();
        assertEq(sig.timestamp, block.timestamp);
        assertGt(sig.L_in, 0);
        assertGt(sig.L_out, 0);
    }

    function test_EmitGLTESignal_EmitsEvent() public {
        (uint256 L_in, uint256 L_out) = engine.computeGLTE();
        bool expectedBullish = L_out > L_in;

        vm.expectEmit(true, false, false, false);
        emit HFTEngine.GLTESignalEmitted(1, L_in, L_out, expectedBullish, 0);

        vm.prank(owner);
        engine.emitGLTESignal();
    }

    function test_EmitGLTESignal_RevertsUnauthorized() public {
        vm.prank(unauthorized);
        vm.expectRevert("Not authorised");
        engine.emitGLTESignal();
    }

    function test_EmitGLTESignal_StrengthCappedAt100() public {
        vm.prank(owner);
        engine.emitGLTESignal();

        HFTEngine.GLTESignal memory sig = engine.getLatestSignal();
        assertLe(sig.strength, 100);
    }

    // ─── Place Order ──────────────────────────────────────────────────────────

    function test_PlaceOrder_MarketBuy() public {
        vm.prank(trader);
        uint256 orderId = engine.placeOrder(
            HFTEngine.OrderType.Market,
            HFTEngine.Direction.Buy,
            "USD",
            "EUR",
            1000 * 1e18,
            0,
            0,
            3600,
            false
        );

        assertEq(orderId, 1);
        assertEq(engine.orderCounter(), 1);
    }

    function test_PlaceOrder_SetsOrderFields() public {
        vm.prank(trader);
        uint256 orderId = engine.placeOrder(
            HFTEngine.OrderType.Limit,
            HFTEngine.Direction.Sell,
            "BTC",
            "USD",
            5 * 1e18,
            50_000 * 1e18,
            0,
            7200,
            false
        );

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertEq(o.trader, trader);
        assertEq(o.quantity, 5 * 1e18);
        assertEq(o.limitPrice, 50_000 * 1e18);
        assertEq(uint8(o.orderType), uint8(HFTEngine.OrderType.Limit));
        assertEq(uint8(o.direction), uint8(HFTEngine.Direction.Sell));
        assertEq(uint8(o.status), uint8(HFTEngine.OrderStatus.Open));
    }

    function test_PlaceOrder_UpdatesTraderStats() public {
        vm.prank(trader);
        engine.placeOrder(
            HFTEngine.OrderType.Market,
            HFTEngine.Direction.Buy,
            "USD",
            "EUR",
            100 * 1e18,
            0, 0, 3600, false
        );

        HFTEngine.TraderStats memory ts = engine.getTraderStats(trader);
        assertEq(ts.totalOrders, 1);
        assertEq(ts.lastActivity, block.timestamp);
    }

    function test_PlaceOrder_AppendsToTraderOrders() public {
        vm.prank(trader);
        engine.placeOrder(
            HFTEngine.OrderType.Market,
            HFTEngine.Direction.Buy,
            "USD", "EUR",
            100 * 1e18,
            0, 0, 3600, false
        );

        uint256[] memory ids = engine.getTraderOrders(trader);
        assertEq(ids.length, 1);
        assertEq(ids[0], 1);
    }

    function test_PlaceOrder_WithGLTE_SetsTargetLOut() public {
        vm.prank(trader);
        uint256 orderId = engine.placeOrder(
            HFTEngine.OrderType.GLTE,
            HFTEngine.Direction.Buy,
            "USD", "EUR",
            100 * 1e18,
            0, 0, 3600,
            true  // useGLTE
        );

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertGt(o.glteTargetL_out, 0);
    }

    function test_PlaceOrder_EmitsOrderPlacedEvent() public {
        vm.expectEmit(true, true, false, false);
        emit HFTEngine.OrderPlaced(1, trader, HFTEngine.OrderType.Market, HFTEngine.Direction.Buy, "USD/EUR", 100 * 1e18);

        vm.prank(trader);
        engine.placeOrder(
            HFTEngine.OrderType.Market,
            HFTEngine.Direction.Buy,
            "USD", "EUR",
            100 * 1e18,
            0, 0, 3600, false
        );
    }

    function test_PlaceOrder_RevertsZeroQuantity() public {
        vm.prank(trader);
        vm.expectRevert("Quantity required");
        engine.placeOrder(
            HFTEngine.OrderType.Market,
            HFTEngine.Direction.Buy,
            "USD", "EUR",
            0,          // zero quantity
            0, 0, 3600, false
        );
    }

    function test_PlaceOrder_ExpiryMaxWhenZeroSeconds() public {
        vm.prank(trader);
        uint256 orderId = engine.placeOrder(
            HFTEngine.OrderType.Market,
            HFTEngine.Direction.Buy,
            "USD", "EUR",
            100 * 1e18,
            0, 0,
            0,  // zero expirySeconds -> max expiry
            false
        );

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertEq(o.expiryTime, type(uint256).max);
    }

    // ─── Fill Order ───────────────────────────────────────────────────────────

    function _placeBasicOrder() internal returns (uint256 orderId) {
        vm.prank(trader);
        orderId = engine.placeOrder(
            HFTEngine.OrderType.Market,
            HFTEngine.Direction.Buy,
            "USD", "EUR",
            1000 * 1e18,
            0, 0, 0, false
        );
    }

    function test_FillOrder_ByOwner_FullFill() public {
        uint256 orderId = _placeBasicOrder();

        vm.prank(owner);
        engine.fillOrder(orderId, 1 * 1e18, 1000 * 1e18);

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertEq(uint8(o.status), uint8(HFTEngine.OrderStatus.Filled));
        assertEq(o.filledQuantity, 1000 * 1e18);
    }

    function test_FillOrder_ByExecutor() public {
        vm.prank(owner);
        engine.setExecutor(executor, true);

        uint256 orderId = _placeBasicOrder();

        vm.prank(executor);
        engine.fillOrder(orderId, 1 * 1e18, 500 * 1e18);

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertEq(uint8(o.status), uint8(HFTEngine.OrderStatus.PartialFill));
    }

    function test_FillOrder_PartialFill_ThenFullFill() public {
        uint256 orderId = _placeBasicOrder();

        vm.startPrank(owner);
        engine.fillOrder(orderId, 1 * 1e18, 400 * 1e18);
        engine.fillOrder(orderId, 1 * 1e18, 600 * 1e18);
        vm.stopPrank();

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertEq(uint8(o.status), uint8(HFTEngine.OrderStatus.Filled));
    }

    function test_FillOrder_UpdatesGlobalCounters() public {
        uint256 orderId = _placeBasicOrder();

        vm.prank(owner);
        engine.fillOrder(orderId, 2 * 1e18, 1000 * 1e18);

        assertEq(engine.totalOrdersProcessed(), 1);
        assertGt(engine.totalVolumeTraded(), 0);
    }

    function test_FillOrder_RevertsWhenUnauthorized() public {
        uint256 orderId = _placeBasicOrder();

        vm.prank(unauthorized);
        vm.expectRevert("Not authorised");
        engine.fillOrder(orderId, 1 * 1e18, 100 * 1e18);
    }

    function test_FillOrder_RevertsWhenExpired() public {
        vm.prank(trader);
        uint256 orderId = engine.placeOrder(
            HFTEngine.OrderType.Market,
            HFTEngine.Direction.Buy,
            "USD", "EUR",
            100 * 1e18,
            0, 0,
            3600,  // 1 hour expiry
            false
        );

        // Warp past expiry
        vm.warp(block.timestamp + 7200);

        vm.prank(owner);
        vm.expectRevert("Expired");
        engine.fillOrder(orderId, 1 * 1e18, 100 * 1e18);
    }

    function test_FillOrder_RevertsOverFill() public {
        uint256 orderId = _placeBasicOrder();

        vm.prank(owner);
        vm.expectRevert("Over-fill");
        engine.fillOrder(orderId, 1 * 1e18, 2000 * 1e18);  // exceeds 1000
    }

    function test_FillOrder_EmitsOrderFilledEvent() public {
        uint256 orderId = _placeBasicOrder();

        vm.expectEmit(true, false, false, true);
        emit HFTEngine.OrderFilled(orderId, 1 * 1e18, 1000 * 1e18);

        vm.prank(owner);
        engine.fillOrder(orderId, 1 * 1e18, 1000 * 1e18);
    }

    function test_FillOrder_WeightedAvgFillPrice() public {
        uint256 orderId = _placeBasicOrder();

        vm.startPrank(owner);
        // First fill: 500 @ price 2e18
        engine.fillOrder(orderId, 2 * 1e18, 500 * 1e18);
        // Second fill: 500 @ price 4e18
        engine.fillOrder(orderId, 4 * 1e18, 500 * 1e18);
        vm.stopPrank();

        HFTEngine.Order memory o = engine.getOrder(orderId);
        // Weighted avg = (500*2 + 500*4) / 1000 = 3
        assertEq(o.avgFillPrice, 3 * 1e18);
    }

    // ─── Cancel Order ─────────────────────────────────────────────────────────

    function test_CancelOrder_ByTrader() public {
        uint256 orderId = _placeBasicOrder();

        vm.prank(trader);
        engine.cancelOrder(orderId);

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertEq(uint8(o.status), uint8(HFTEngine.OrderStatus.Cancelled));
    }

    function test_CancelOrder_ByOwner() public {
        uint256 orderId = _placeBasicOrder();

        vm.prank(owner);
        engine.cancelOrder(orderId);

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertEq(uint8(o.status), uint8(HFTEngine.OrderStatus.Cancelled));
    }

    function test_CancelOrder_EmitsEvent() public {
        uint256 orderId = _placeBasicOrder();

        vm.expectEmit(true, false, false, true);
        emit HFTEngine.OrderCancelled(orderId, trader);

        vm.prank(trader);
        engine.cancelOrder(orderId);
    }

    function test_CancelOrder_RevertsUnauthorized() public {
        uint256 orderId = _placeBasicOrder();

        vm.prank(unauthorized);
        vm.expectRevert("Not authorised");
        engine.cancelOrder(orderId);
    }

    function test_CancelOrder_RevertsIfAlreadyCancelled() public {
        uint256 orderId = _placeBasicOrder();

        vm.startPrank(trader);
        engine.cancelOrder(orderId);

        vm.expectRevert("Not cancellable");
        engine.cancelOrder(orderId);
        vm.stopPrank();
    }

    function test_CancelOrder_CanCancelPartialFill() public {
        uint256 orderId = _placeBasicOrder();

        // Partial fill first
        vm.prank(owner);
        engine.fillOrder(orderId, 1 * 1e18, 400 * 1e18);

        // Then cancel the remaining
        vm.prank(trader);
        engine.cancelOrder(orderId);

        HFTEngine.Order memory o = engine.getOrder(orderId);
        assertEq(uint8(o.status), uint8(HFTEngine.OrderStatus.Cancelled));
    }

    // ─── Admin: Update GLTE Parameters ────────────────────────────────────────

    function test_UpdateGLTEParameters_ByOwner() public {
        vm.prank(owner);
        engine.updateGLTEParameters(
            2_000_000 * 1e18, // W_t
            5_000_000 * 1e14, // chi_in
            8_000_000 * 1e14, // chi_out
            600 * 1e14,        // r_LIBOR
            1_200_000 * 1e18, // r_BSE_Delhi
            900_000 * 1e18,   // r_Bursa_Malaysia
            200 * 1e18,        // OICD
            15 * 1e17,         // B_Bolsaro
            600_000 * 1e18,   // B_Tirana
            15 * 1e17,         // F_Tadawul
            30 * 1e16,         // sigma_VIX
            20 * 1e12,         // derivativeSpread
            11 * 1e16,         // gamma
            1e18               // yuan_OICD_peg
        );

        HFTEngine.GLTEParameters memory p = engine.getGLTEParams();
        assertEq(p.W_t, 2_000_000 * 1e18);
        assertEq(p.OICD, 200 * 1e18);
    }

    function test_UpdateGLTEParameters_EmitsEvent() public {
        vm.expectEmit(false, false, false, false);
        emit HFTEngine.GLTEParametersUpdated(2_000_000 * 1e18, 11 * 1e16, block.timestamp);

        vm.prank(owner);
        engine.updateGLTEParameters(
            2_000_000 * 1e18, 5_000_000 * 1e14, 8_000_000 * 1e14,
            600 * 1e14, 1_200_000 * 1e18, 900_000 * 1e18,
            200 * 1e18, 15 * 1e17, 600_000 * 1e18, 15 * 1e17,
            30 * 1e16, 20 * 1e12, 11 * 1e16, 1e18
        );
    }

    function test_UpdateGLTEParameters_RevertsNonOwner() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        engine.updateGLTEParameters(
            2_000_000 * 1e18, 5_000_000 * 1e14, 8_000_000 * 1e14,
            600 * 1e14, 1_200_000 * 1e18, 900_000 * 1e18,
            200 * 1e18, 15 * 1e17, 600_000 * 1e18, 15 * 1e17,
            30 * 1e16, 20 * 1e12, 11 * 1e16, 1e18
        );
    }

    // ─── Executor Management ──────────────────────────────────────────────────

    function test_SetExecutor_ByOwner() public {
        vm.prank(owner);
        engine.setExecutor(executor, true);
        assertTrue(engine.authorizedExecutors(executor));
    }

    function test_SetExecutor_Revoke() public {
        vm.startPrank(owner);
        engine.setExecutor(executor, true);
        engine.setExecutor(executor, false);
        vm.stopPrank();

        assertFalse(engine.authorizedExecutors(executor));
    }

    function test_SetExecutor_RevertsNonOwner() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        engine.setExecutor(executor, true);
    }

    // ─── Multiple Orders / Trader Views ───────────────────────────────────────

    function test_MultipleOrders_TraderStatsAccumulate() public {
        vm.startPrank(trader);
        engine.placeOrder(HFTEngine.OrderType.Market, HFTEngine.Direction.Buy, "USD", "EUR", 100 * 1e18, 0, 0, 0, false);
        engine.placeOrder(HFTEngine.OrderType.Limit,  HFTEngine.Direction.Sell, "GBP", "USD", 200 * 1e18, 1e18, 0, 0, false);
        engine.placeOrder(HFTEngine.OrderType.Market, HFTEngine.Direction.Buy, "JPY", "USD", 300 * 1e18, 0, 0, 0, false);
        vm.stopPrank();

        HFTEngine.TraderStats memory ts = engine.getTraderStats(trader);
        assertEq(ts.totalOrders, 3);

        uint256[] memory ids = engine.getTraderOrders(trader);
        assertEq(ids.length, 3);
    }

    function test_MultipleTraders_IsolatedStats() public {
        vm.prank(trader);
        engine.placeOrder(HFTEngine.OrderType.Market, HFTEngine.Direction.Buy, "USD", "EUR", 100 * 1e18, 0, 0, 0, false);

        vm.prank(trader2);
        engine.placeOrder(HFTEngine.OrderType.Market, HFTEngine.Direction.Sell, "USD", "EUR", 200 * 1e18, 0, 0, 0, false);

        assertEq(engine.getTraderStats(trader).totalOrders, 1);
        assertEq(engine.getTraderStats(trader2).totalOrders, 1);

        uint256[] memory ids1 = engine.getTraderOrders(trader);
        uint256[] memory ids2 = engine.getTraderOrders(trader2);
        assertEq(ids1.length, 1);
        assertEq(ids2.length, 1);
    }

    // ─── GLTE Signal incrementing ──────────────────────────────────────────────

    function test_SignalCounter_Increments() public {
        vm.startPrank(owner);
        engine.emitGLTESignal();
        engine.emitGLTESignal();
        engine.emitGLTESignal();
        vm.stopPrank();

        assertEq(engine.signalCounter(), 3);
    }
}
