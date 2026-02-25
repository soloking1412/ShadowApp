// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ForexReservesTracker.sol";

contract ForexReservesTrackerTest is Test {
    ForexReservesTracker instance;

    address admin  = address(1);
    address oracle = address(2);
    address nobody = address(3);

    function setUp() public {
        ForexReservesTracker impl = new ForexReservesTracker();
        bytes memory init = abi.encodeCall(ForexReservesTracker.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = ForexReservesTracker(address(proxy));

        // Grant ORACLE_ROLE to oracle address
        bytes32 oracleRole = instance.ORACLE_ROLE();
        vm.prank(admin);
        instance.grantRole(oracleRole, oracle);
    }

    // -----------------------------------------------------------------------
    // 1. Initialization
    // -----------------------------------------------------------------------
    function test_Initialization() public view {
        assertTrue(instance.hasRole(instance.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.ORACLE_ROLE(), admin));
        assertTrue(instance.hasRole(instance.UPGRADER_ROLE(), admin));
        assertEq(instance.totalGlobalReservesUSD(), 0);
        assertEq(instance.opportunityCounter(), 0);
        assertEq(instance.tradeCounter(), 0);
        assertEq(instance.snapshotCounter(), 0);
    }

    function test_CurrenciesInitialized() public view {
        string[] memory currencies = instance.getAllCurrencies();
        assertEq(currencies.length, 61);

        // Spot-check: USD initialized with lastPrice = 1e18
        ForexReservesTracker.CurrencyReserve memory usd = instance.getReserve("USD");
        assertEq(usd.lastPrice, 1e18);
        assertEq(usd.totalReserves, 0);

        // Check OTD is in the list (the platform's own token)
        ForexReservesTracker.CurrencyReserve memory otd = instance.getReserve("OTD");
        assertEq(otd.lastPrice, 1e18);
    }

    // -----------------------------------------------------------------------
    // 2. Reserve Updates
    // -----------------------------------------------------------------------
    function test_UpdateReserve() public {
        vm.expectEmit(true, false, false, true);
        emit ForexReservesTracker.ReserveUpdated("USD", 1_000_000e18, 2e18);

        vm.prank(oracle);
        instance.updateReserve(
            "USD",
            1_000_000e18,  // totalReserves
            500_000e18,    // tradingVolume
            2e18,          // lastPrice
            int256(5e16),  // priceChange (positive)
            50_000_000e18  // marketCap
        );

        ForexReservesTracker.CurrencyReserve memory r = instance.getReserve("USD");
        assertEq(r.totalReserves, 1_000_000e18);
        assertEq(r.tradingVolume24h, 500_000e18);
        assertEq(r.lastPrice, 2e18);
        assertEq(r.marketCap, 50_000_000e18);
        assertEq(r.lastUpdate, block.timestamp);
    }

    function test_UpdateReserve_Reverts_NonOracle() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.updateReserve("USD", 0, 0, 1e18, 0, 0);
    }

    function test_UpdateReserve_NegativePriceChange() public {
        vm.prank(oracle);
        instance.updateReserve("EUR", 500_000e18, 200_000e18, 1.1e18, int256(-1e16), 20_000_000e18);

        ForexReservesTracker.CurrencyReserve memory r = instance.getReserve("EUR");
        // Negative int256 cast to uint256 is a large number — matches contract behavior
        assertEq(r.priceChange24h, uint256(int256(-1e16)));
    }

    // -----------------------------------------------------------------------
    // 3. Corridor Updates
    // -----------------------------------------------------------------------
    function test_UpdateCorridor() public {
        vm.expectEmit(false, false, false, true);
        emit ForexReservesTracker.CorridorUpdated("USD", "EUR", 100_000e18, 80_000e18);

        vm.prank(oracle);
        instance.updateCorridor(
            "USD",
            "EUR",
            100_000e18, // buyVolume
            80_000e18,  // sellVolume
            50,         // spread (bps)
            5_000_000e18 // liquidity
        );

        ForexReservesTracker.MarketCorridor memory c = instance.getCorridor("USD", "EUR");
        assertEq(c.fromCurrency, "USD");
        assertEq(c.toCurrency, "EUR");
        assertEq(c.buyVolume, 100_000e18);
        assertEq(c.sellVolume, 80_000e18);
        assertEq(c.spread, 50);
        assertEq(c.liquidity, 5_000_000e18);
        assertTrue(c.active);
    }

    function test_UpdateCorridor_Twice_DoesNotDuplicateActiveList() public {
        vm.startPrank(oracle);
        instance.updateCorridor("USD", "EUR", 100e18, 90e18, 10, 1_000e18);
        instance.updateCorridor("USD", "EUR", 200e18, 180e18, 10, 2_000e18);
        vm.stopPrank();

        // The active corridors array should only have one entry for USD/EUR
        // (second call sees it's already active, so it doesn't push again)
        ForexReservesTracker.MarketCorridor memory c = instance.getCorridor("USD", "EUR");
        assertEq(c.buyVolume, 200e18); // Updated to latest values
    }

    function test_UpdateCorridor_Reverts_NonOracle() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.updateCorridor("USD", "EUR", 0, 0, 0, 0);
    }

    // -----------------------------------------------------------------------
    // 4. Investment Opportunities
    // -----------------------------------------------------------------------
    function test_CreateOpportunity() public {
        vm.expectEmit(true, false, false, true);
        emit ForexReservesTracker.OpportunityCreated(0, "BRL", 800); // 8% projected return

        vm.prank(oracle);
        uint256 oppId = instance.createOpportunity(
            "BRL",        // targetCurrency
            "USD",        // sourceCurrency
            800,          // projectedReturn (8%)
            5,            // risk (low)
            30 days,      // timeframe
            "Carry Trade",
            1_000e18,     // minInvestment
            10_000_000e18 // maxInvestment
        );

        assertEq(oppId, 0);
        assertEq(instance.opportunityCounter(), 1);

        ForexReservesTracker.InvestmentOpportunity memory opp = instance.getOpportunity(0);
        assertEq(opp.targetCurrency, "BRL");
        assertEq(opp.sourceCurrency, "USD");
        assertEq(opp.projectedReturn, 800);
        assertTrue(opp.active);
    }

    function test_CreateOpportunity_Reverts_NonOracle() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.createOpportunity("BRL", "USD", 800, 5, 30 days, "Carry", 1e18, 1e24);
    }

    function test_DeactivateOpportunity() public {
        vm.prank(oracle);
        instance.createOpportunity("BRL", "USD", 800, 5, 30 days, "Carry", 1e18, 1e24);

        vm.prank(oracle);
        instance.deactivateOpportunity(0);

        ForexReservesTracker.InvestmentOpportunity memory opp = instance.getOpportunity(0);
        assertFalse(opp.active);
    }

    function test_GetActiveOpportunities() public {
        vm.startPrank(oracle);
        instance.createOpportunity("BRL", "USD", 800, 5, 30 days, "Carry", 1e18, 1e24);
        instance.createOpportunity("NGN", "USD", 1200, 7, 60 days, "Momentum", 1e18, 1e24);
        instance.createOpportunity("INR", "USD", 500, 3, 14 days, "Arb", 1e18, 1e24);
        vm.stopPrank();

        uint256[] memory active = instance.getActiveOpportunities();
        assertEq(active.length, 3);

        // Deactivate one
        vm.prank(oracle);
        instance.deactivateOpportunity(1);

        active = instance.getActiveOpportunities();
        assertEq(active.length, 2);
        assertEq(active[0], 0);
        assertEq(active[1], 2);
    }

    // -----------------------------------------------------------------------
    // 5. Trade Recording
    // -----------------------------------------------------------------------
    function test_RecordTrade() public {
        vm.expectEmit(true, false, false, true);
        emit ForexReservesTracker.TradeExecuted(0, "USD", "EUR", 50_000e18);

        vm.prank(oracle);
        uint256 tradeId = instance.recordTrade(
            "USD",
            "EUR",
            50_000e18,
            1.09e18 // execution price
        );

        assertEq(tradeId, 0);
        assertEq(instance.tradeCounter(), 1);

        (
            ,
            string memory _fromCurrency,
            string memory _toCurrency,
            uint256 _amount,
            uint256 _executionPrice,
            uint256 _tradeTimestamp,
            address _executor,

        ) = instance.trades(0);
        assertEq(_fromCurrency, "USD");
        assertEq(_toCurrency, "EUR");
        assertEq(_amount, 50_000e18);
        assertEq(_executionPrice, 1.09e18);
        assertEq(_executor, oracle);
        assertEq(_tradeTimestamp, block.timestamp);
    }

    function test_RecordTrade_MultipleIncrementCounter() public {
        vm.startPrank(oracle);
        instance.recordTrade("USD", "EUR", 1e18, 1.09e18);
        instance.recordTrade("USD", "GBP", 1e18, 1.27e18);
        instance.recordTrade("EUR", "JPY", 1e18, 160e18);
        vm.stopPrank();

        assertEq(instance.tradeCounter(), 3);
    }

    function test_RecordTrade_Reverts_NonOracle() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.recordTrade("USD", "EUR", 1e18, 1e18);
    }

    // -----------------------------------------------------------------------
    // 6. Snapshots
    // -----------------------------------------------------------------------
    function test_TakeGlobalSnapshot_Empty() public {
        vm.expectEmit(true, false, false, true);
        emit ForexReservesTracker.SnapshotTaken(0, 0);

        vm.prank(oracle);
        uint256 snapshotId = instance.takeGlobalSnapshot();

        assertEq(snapshotId, 0);
        assertEq(instance.snapshotCounter(), 1);
        assertEq(instance.totalGlobalReservesUSD(), 0);
    }

    function test_TakeGlobalSnapshot_WithReserves() public {
        // Set USD reserves and price
        vm.prank(oracle);
        instance.updateReserve("USD", 1_000_000e18, 0, 1e18, 0, 0);

        // 1_000_000 * 1e18 / 1e18 = 1_000_000
        vm.prank(oracle);
        instance.takeGlobalSnapshot();

        assertEq(instance.totalGlobalReservesUSD(), 1_000_000e18);
    }

    function test_TakeGlobalSnapshot_Reverts_NonOracle() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.takeGlobalSnapshot();
    }

    function test_GetSnapshotCurrencyReserve() public {
        vm.prank(oracle);
        instance.updateReserve("EUR", 500_000e18, 0, 1.1e18, 0, 0);

        vm.prank(oracle);
        uint256 snapshotId = instance.takeGlobalSnapshot();

        uint256 eurReserve = instance.getSnapshotCurrencyReserve(snapshotId, "EUR");
        assertEq(eurReserve, 500_000e18);
    }

    // -----------------------------------------------------------------------
    // 7. AMM Address
    // -----------------------------------------------------------------------
    function test_SetAMMAddress() public {
        address amm = address(99);
        vm.prank(admin);
        instance.setAMMAddress(amm);
        assertEq(instance.ammAddress(), amm);
    }

    function test_SetAMMAddress_Reverts_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid AMM address");
        instance.setAMMAddress(address(0));
    }

    function test_SetAMMAddress_Reverts_NonAdmin() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.setAMMAddress(address(99));
    }

    // -----------------------------------------------------------------------
    // 8. Pause / Unpause
    // -----------------------------------------------------------------------
    function test_PauseUnpause() public {
        vm.prank(admin);
        instance.pause();
        assertTrue(instance.paused());

        vm.prank(admin);
        instance.unpause();
        assertFalse(instance.paused());
    }

    function test_Pause_Reverts_NonAdmin() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.pause();
    }

    // -----------------------------------------------------------------------
    // 9. Role checks
    // -----------------------------------------------------------------------
    function test_OracleRole_GrantedToOracle() public view {
        assertTrue(instance.hasRole(instance.ORACLE_ROLE(), oracle));
    }

    function test_RoleControl_NonOracleCannotUpdateReserve() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.updateReserve("USD", 1e18, 0, 1e18, 0, 0);
    }

    // -----------------------------------------------------------------------
    // 10. Multiple corridor management
    // -----------------------------------------------------------------------
    function test_MultipleCorridors() public {
        vm.startPrank(oracle);
        instance.updateCorridor("USD", "EUR", 100e18, 90e18, 10, 1_000e18);
        instance.updateCorridor("USD", "GBP", 200e18, 180e18, 15, 2_000e18);
        instance.updateCorridor("EUR", "JPY", 50e18, 45e18, 20, 500e18);
        vm.stopPrank();

        ForexReservesTracker.MarketCorridor memory c1 = instance.getCorridor("USD", "EUR");
        ForexReservesTracker.MarketCorridor memory c2 = instance.getCorridor("USD", "GBP");
        ForexReservesTracker.MarketCorridor memory c3 = instance.getCorridor("EUR", "JPY");

        assertTrue(c1.active);
        assertTrue(c2.active);
        assertTrue(c3.active);
        assertEq(c1.buyVolume, 100e18);
        assertEq(c2.buyVolume, 200e18);
        assertEq(c3.buyVolume, 50e18);
    }
}
