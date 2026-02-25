// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/GovernmentSecuritiesSettlement.sol";

contract GovernmentSecuritiesSettlementTest is Test {
    GovernmentSecuritiesSettlement instance;

    address admin        = address(1);
    address government   = address(2);
    address clearingHouse = address(3);
    address settler      = address(4);
    address buyer        = address(5);
    address nobody       = address(6);

    function setUp() public {
        GovernmentSecuritiesSettlement impl = new GovernmentSecuritiesSettlement();
        bytes memory init = abi.encodeCall(GovernmentSecuritiesSettlement.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = GovernmentSecuritiesSettlement(address(proxy));

        // Grant roles
        vm.startPrank(admin);
        instance.grantRole(instance.GOVERNMENT_ROLE(), government);
        instance.grantRole(instance.SETTLER_ROLE(), settler);
        vm.stopPrank();

        // Register clearing house (grants CLEARING_HOUSE_ROLE automatically)
        vm.prank(admin);
        instance.registerClearingHouse(clearingHouse, "OZF Clearing", "Sovereign");
    }

    // -----------------------------------------------------------------------
    // 1. Initialization
    // -----------------------------------------------------------------------
    function test_Initialization() public view {
        assertTrue(instance.hasRole(instance.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.SETTLER_ROLE(), admin));
        assertEq(instance.securityCounter(), 0);
        assertEq(instance.tradeCounter(), 0);
        assertEq(instance.totalSecuritiesValue(), 0);
        assertEq(instance.SETTLEMENT_PERIOD(), 1 days);
    }

    // -----------------------------------------------------------------------
    // 2. Clearing House Registration
    // -----------------------------------------------------------------------
    function test_RegisterClearingHouse() public {
        address ch2 = address(50);

        vm.expectEmit(true, false, false, true);
        emit GovernmentSecuritiesSettlement.ClearingHouseRegistered(ch2, "CH2", "EU");

        vm.prank(admin);
        instance.registerClearingHouse(ch2, "CH2", "EU");

        (
            ,
            string memory _chName,
            string memory _chJurisdiction,
            bool _chActive,
            ,

        ) = instance.clearingHouses(ch2);
        assertEq(_chName, "CH2");
        assertEq(_chJurisdiction, "EU");
        assertTrue(_chActive);
        assertTrue(instance.hasRole(instance.CLEARING_HOUSE_ROLE(), ch2));
    }

    function test_RegisterClearingHouse_Reverts_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid address");
        instance.registerClearingHouse(address(0), "CH", "US");
    }

    function test_RegisterClearingHouse_Reverts_NonAdmin() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.registerClearingHouse(address(50), "CH", "US");
    }

    // -----------------------------------------------------------------------
    // 3. Security Issuance
    // -----------------------------------------------------------------------
    function test_IssueSecurity() public {
        uint256 maturity = block.timestamp + 365 days;

        vm.expectEmit(true, false, true, true);
        emit GovernmentSecuritiesSettlement.SecurityIssued(
            1,
            GovernmentSecuritiesSettlement.SecurityType.TreasuryBond,
            government,
            1_000_000,
            "US0001234567"
        );

        vm.prank(government);
        uint256 secId = instance.issueSecurity(
            GovernmentSecuritiesSettlement.SecurityType.TreasuryBond,
            "US0001234567",
            "123456789",
            1000e18,        // faceValue
            500,            // couponRate (5%)
            maturity,
            1_000_000       // totalIssued
        );

        assertEq(secId, 1);
        assertEq(instance.securityCounter(), 1);
        assertEq(instance.totalSecuritiesValue(), 1_000_000 * 1000e18);

        GovernmentSecuritiesSettlement.Security memory s = instance.getSecurity(1);
        assertEq(s.securityId, 1);
        assertEq(s.issuer, government);
        assertEq(s.isin, "US0001234567");
        assertEq(s.faceValue, 1000e18);
        assertEq(s.couponRate, 500);
        assertEq(s.totalIssued, 1_000_000);
        assertEq(s.outstandingAmount, 1_000_000);
        assertTrue(s.active);

        // Issuer receives holdings
        assertEq(instance.getHoldings(government, 1), 1_000_000);
    }

    function test_IssueSecurity_MultipleTypes() public {
        uint256 maturity = block.timestamp + 365 days;
        vm.startPrank(government);
        instance.issueSecurity(
            GovernmentSecuritiesSettlement.SecurityType.TreasuryBill,
            "US0002", "CUSIP2", 100e18, 0, maturity, 500_000
        );
        instance.issueSecurity(
            GovernmentSecuritiesSettlement.SecurityType.SovereignBond,
            "OZ0001", "OZCP01", 5000e18, 700, maturity, 10_000
        );
        vm.stopPrank();

        assertEq(instance.securityCounter(), 2);
    }

    function test_IssueSecurity_Reverts_NonGovernment() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.issueSecurity(
            GovernmentSecuritiesSettlement.SecurityType.TreasuryBond,
            "US001", "CUS001", 1000e18, 500,
            block.timestamp + 365 days, 1_000_000
        );
    }

    function test_IssueSecurity_Reverts_ZeroIssuance() public {
        vm.prank(government);
        vm.expectRevert("Invalid issuance amount");
        instance.issueSecurity(
            GovernmentSecuritiesSettlement.SecurityType.TreasuryBond,
            "US001", "CUS001", 1000e18, 500,
            block.timestamp + 365 days, 0
        );
    }

    function test_IssueSecurity_Reverts_PastMaturity() public {
        vm.prank(government);
        vm.expectRevert("Invalid maturity date");
        instance.issueSecurity(
            GovernmentSecuritiesSettlement.SecurityType.TreasuryBond,
            "US001", "CUS001", 1000e18, 500,
            block.timestamp - 1, 1_000_000
        );
    }

    function test_IssueSecurity_Reverts_WhenPaused() public {
        vm.prank(admin);
        instance.pause();

        vm.prank(government);
        vm.expectRevert();
        instance.issueSecurity(
            GovernmentSecuritiesSettlement.SecurityType.TreasuryBond,
            "US001", "CUS001", 1000e18, 500,
            block.timestamp + 365 days, 1_000_000
        );
    }

    // -----------------------------------------------------------------------
    // 4. Trade Execution
    // -----------------------------------------------------------------------
    function _issueDefaultSecurity() internal returns (uint256 secId) {
        vm.prank(government);
        secId = instance.issueSecurity(
            GovernmentSecuritiesSettlement.SecurityType.TreasuryBond,
            "US0001", "CUSP001", 1000e18, 500,
            block.timestamp + 365 days, 1_000_000
        );
    }

    function test_ExecuteTrade() public {
        uint256 secId = _issueDefaultSecurity();

        vm.expectEmit(true, true, true, true);
        emit GovernmentSecuritiesSettlement.TradeExecuted(
            1,
            secId,
            buyer,
            government,
            100,
            950e18
        );

        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        assertEq(tradeId, 1);
        assertEq(instance.tradeCounter(), 1);

        GovernmentSecuritiesSettlement.Trade memory t = instance.getTrade(1);
        assertEq(t.buyer, buyer);
        assertEq(t.seller, government);
        assertEq(t.quantity, 100);
        assertEq(t.price, 950e18);
        assertEq(uint8(t.status), uint8(GovernmentSecuritiesSettlement.SettlementStatus.Pending));
        assertEq(t.settlementDate, block.timestamp + 1 days);
    }

    function test_ExecuteTrade_Reverts_InsufficientHoldings() public {
        uint256 secId = _issueDefaultSecurity();

        vm.prank(buyer);
        vm.expectRevert("Insufficient holdings");
        instance.executeTrade(secId, nobody, 100, 950e18); // nobody has no holdings
    }

    function test_ExecuteTrade_Reverts_InactiveSecuriy() public {
        vm.prank(buyer);
        vm.expectRevert("Security not active");
        instance.executeTrade(999, government, 100, 950e18); // non-existent security
    }

    // -----------------------------------------------------------------------
    // 5. Trade Clearing
    // -----------------------------------------------------------------------
    function test_ClearTrade() public {
        uint256 secId = _issueDefaultSecurity();
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        bytes32 clearingRef = keccak256("clearing-001");

        vm.expectEmit(true, false, false, true);
        emit GovernmentSecuritiesSettlement.TradeCleared(tradeId, clearingRef, clearingHouse);

        vm.prank(clearingHouse);
        instance.clearTrade(tradeId, clearingRef);

        GovernmentSecuritiesSettlement.Trade memory t = instance.getTrade(tradeId);
        assertEq(uint8(t.status), uint8(GovernmentSecuritiesSettlement.SettlementStatus.Cleared));
        assertEq(t.clearingRef, clearingRef);
        assertTrue(instance.processedClearings(clearingRef));

        (
            ,
            ,
            ,
            ,
            uint256 _totalTradesCleared,
            uint256 _totalValueCleared
        ) = instance.clearingHouses(clearingHouse);
        assertEq(_totalTradesCleared, 1);
        assertEq(_totalValueCleared, 100 * 950e18);
    }

    function test_ClearTrade_Reverts_AlreadyProcessed() public {
        uint256 secId = _issueDefaultSecurity();
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        bytes32 clearingRef = keccak256("clearing-002");

        vm.prank(clearingHouse);
        instance.clearTrade(tradeId, clearingRef);

        // Try to clear another trade with same ref
        vm.prank(buyer);
        uint256 tradeId2 = instance.executeTrade(secId, government, 50, 900e18);
        vm.prank(clearingHouse);
        vm.expectRevert("Clearing already processed");
        instance.clearTrade(tradeId2, clearingRef);
    }

    function test_ClearTrade_Reverts_NonClearingHouse() public {
        uint256 secId = _issueDefaultSecurity();
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        vm.prank(nobody);
        vm.expectRevert();
        instance.clearTrade(tradeId, keccak256("ref"));
    }

    function test_ClearTrade_Reverts_NotPendingStatus() public {
        uint256 secId = _issueDefaultSecurity();
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        bytes32 ref1 = keccak256("ref1");
        bytes32 ref2 = keccak256("ref2");

        vm.prank(clearingHouse);
        instance.clearTrade(tradeId, ref1);

        // Try to clear again (now Cleared status, not Pending)
        vm.prank(clearingHouse);
        vm.expectRevert("Invalid trade status");
        instance.clearTrade(tradeId, ref2);
    }

    // -----------------------------------------------------------------------
    // 6. Trade Settlement
    // -----------------------------------------------------------------------
    function test_SettleTrade() public {
        uint256 secId = _issueDefaultSecurity();
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        bytes32 clearingRef = keccak256("settle-ref");
        vm.prank(clearingHouse);
        instance.clearTrade(tradeId, clearingRef);

        // Advance time to settlement date (T+1)
        vm.warp(block.timestamp + 1 days + 1);

        vm.expectEmit(true, false, false, false);
        emit GovernmentSecuritiesSettlement.TradeSettled(tradeId, block.timestamp);

        vm.prank(settler);
        instance.settleTrade(tradeId);

        GovernmentSecuritiesSettlement.Trade memory t = instance.getTrade(tradeId);
        assertEq(uint8(t.status), uint8(GovernmentSecuritiesSettlement.SettlementStatus.Settled));

        // Holdings transferred
        assertEq(instance.getHoldings(buyer, secId), 100);
        assertEq(instance.getHoldings(government, secId), 1_000_000 - 100);
    }

    function test_SettleTrade_Reverts_BeforeSettlementDate() public {
        uint256 secId = _issueDefaultSecurity();
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        bytes32 clearingRef = keccak256("early-settle");
        vm.prank(clearingHouse);
        instance.clearTrade(tradeId, clearingRef);

        // Attempt to settle before T+1
        vm.prank(settler);
        vm.expectRevert("Settlement date not reached");
        instance.settleTrade(tradeId);
    }

    function test_SettleTrade_Reverts_NotCleared() public {
        uint256 secId = _issueDefaultSecurity();
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        vm.warp(block.timestamp + 2 days);

        vm.prank(settler);
        vm.expectRevert("Trade not cleared");
        instance.settleTrade(tradeId);
    }

    function test_SettleTrade_Reverts_NonSettler() public {
        uint256 secId = _issueDefaultSecurity();
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 100, 950e18);

        bytes32 clearingRef = keccak256("ref");
        vm.prank(clearingHouse);
        instance.clearTrade(tradeId, clearingRef);

        vm.warp(block.timestamp + 2 days);

        vm.prank(nobody);
        vm.expectRevert();
        instance.settleTrade(tradeId);
    }

    // -----------------------------------------------------------------------
    // 7. End-to-end: Issue → Trade → Clear → Settle
    // -----------------------------------------------------------------------
    function test_FullSettlementFlow() public {
        // Issue
        uint256 secId = _issueDefaultSecurity();
        assertEq(instance.getHoldings(government, secId), 1_000_000);

        // Execute trade
        vm.prank(buyer);
        uint256 tradeId = instance.executeTrade(secId, government, 5000, 980e18);
        assertEq(uint8(instance.getTrade(tradeId).status), uint8(GovernmentSecuritiesSettlement.SettlementStatus.Pending));

        // Clear
        vm.prank(clearingHouse);
        instance.clearTrade(tradeId, keccak256("full-flow-ref"));
        assertEq(uint8(instance.getTrade(tradeId).status), uint8(GovernmentSecuritiesSettlement.SettlementStatus.Cleared));

        // Settle (T+1)
        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(settler);
        instance.settleTrade(tradeId);
        assertEq(uint8(instance.getTrade(tradeId).status), uint8(GovernmentSecuritiesSettlement.SettlementStatus.Settled));

        // Holdings updated correctly
        assertEq(instance.getHoldings(buyer, secId), 5000);
        assertEq(instance.getHoldings(government, secId), 995_000);
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
}
