// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/SovereignDEX.sol";

contract SovereignDEXTest is Test {
    SovereignDEX public dex;

    address public owner         = address(1);
    address public initiator     = address(2);
    address public counterparty  = address(3);
    address public thirdParty    = address(4);
    address public unauthorized  = address(5);

    uint256 public constant MIN_EXPIRY = 1 hours;
    uint256 public constant OFFER_AMOUNT   = 1_000 * 1e18;
    uint256 public constant REQUEST_AMOUNT = 1_200 * 1e18;

    // ─── Setup ────────────────────────────────────────────────────────────────

    function setUp() public {
        SovereignDEX impl = new SovereignDEX();
        bytes memory init = abi.encodeCall(SovereignDEX.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        dex = SovereignDEX(address(proxy));
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    function _createSwap() internal returns (uint256 swapId) {
        vm.prank(initiator);
        swapId = dex.createSwap("USD", "EUR", OFFER_AMOUNT, REQUEST_AMOUNT, MIN_EXPIRY);
    }

    // ─── Initialization ───────────────────────────────────────────────────────

    function test_Initialize_SetsOwner() public view {
        assertEq(dex.owner(), owner);
    }

    function test_Initialize_CountersAtZero() public view {
        assertEq(dex.swapCounter(), 0);
        assertEq(dex.activeSwaps(), 0);
        assertEq(dex.settledSwaps(), 0);
        assertEq(dex.totalVolumeUSD(), 0);
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        dex.initialize(owner);
    }

    // ─── Create Swap ──────────────────────────────────────────────────────────

    function test_CreateSwap_IncrementsCounter() public {
        uint256 swapId = _createSwap();
        assertEq(swapId, 1);
        assertEq(dex.swapCounter(), 1);
    }

    function test_CreateSwap_IncrementsActiveSwaps() public {
        _createSwap();
        assertEq(dex.activeSwaps(), 1);
    }

    function test_CreateSwap_StoresSwapData() public {
        uint256 swapId = _createSwap();
        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);

        assertEq(s.swapId, 1);
        assertEq(s.initiator, initiator);
        assertEq(s.counterparty, address(0));
        assertEq(s.offerAmount, OFFER_AMOUNT);
        assertEq(s.requestAmount, REQUEST_AMOUNT);
        assertEq(uint8(s.status), uint8(SovereignDEX.SwapStatus.Open));
        assertFalse(s.initiatorDeposited);
        assertFalse(s.counterpartyDeposited);
    }

    function test_CreateSwap_CalculatesExchangeRate() public {
        uint256 swapId = _createSwap();
        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);

        uint256 expectedRate = (REQUEST_AMOUNT * 1e18) / OFFER_AMOUNT;
        assertEq(s.exchangeRate, expectedRate);
    }

    function test_CreateSwap_SetsExpiryTime() public {
        uint256 before = block.timestamp;
        uint256 swapId = _createSwap();
        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);

        assertEq(s.expiryTime, before + MIN_EXPIRY);
    }

    function test_CreateSwap_AppendsToUserSwaps() public {
        _createSwap();
        uint256[] memory ids = dex.getUserSwaps(initiator);
        assertEq(ids.length, 1);
        assertEq(ids[0], 1);
    }

    function test_CreateSwap_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit SovereignDEX.SwapCreated(1, initiator, "USD", "EUR", OFFER_AMOUNT, REQUEST_AMOUNT);

        vm.prank(initiator);
        dex.createSwap("USD", "EUR", OFFER_AMOUNT, REQUEST_AMOUNT, MIN_EXPIRY);
    }

    function test_CreateSwap_RevertsZeroAmounts() public {
        vm.prank(initiator);
        vm.expectRevert("Invalid amounts");
        dex.createSwap("USD", "EUR", 0, REQUEST_AMOUNT, MIN_EXPIRY);
    }

    function test_CreateSwap_RevertsSameCurrency() public {
        vm.prank(initiator);
        vm.expectRevert("Same currency");
        dex.createSwap("USD", "USD", OFFER_AMOUNT, REQUEST_AMOUNT, MIN_EXPIRY);
    }

    function test_CreateSwap_RevertsExpiryTooShort() public {
        vm.prank(initiator);
        vm.expectRevert("Invalid expiry");
        dex.createSwap("USD", "EUR", OFFER_AMOUNT, REQUEST_AMOUNT, 30 minutes);
    }

    function test_CreateSwap_RevertsExpiryTooLong() public {
        vm.prank(initiator);
        vm.expectRevert("Invalid expiry");
        dex.createSwap("USD", "EUR", OFFER_AMOUNT, REQUEST_AMOUNT, 31 days);
    }

    // ─── Match Swap ───────────────────────────────────────────────────────────

    function test_MatchSwap_SetsCounterparty() public {
        uint256 swapId = _createSwap();

        vm.prank(counterparty);
        dex.matchSwap(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertEq(s.counterparty, counterparty);
        assertEq(uint8(s.status), uint8(SovereignDEX.SwapStatus.Matched));
    }

    function test_MatchSwap_AppendsToCounterpartyList() public {
        uint256 swapId = _createSwap();

        vm.prank(counterparty);
        dex.matchSwap(swapId);

        uint256[] memory ids = dex.getUserSwaps(counterparty);
        assertEq(ids.length, 1);
        assertEq(ids[0], swapId);
    }

    function test_MatchSwap_EmitsEvent() public {
        uint256 swapId = _createSwap();

        vm.expectEmit(true, true, false, false);
        emit SovereignDEX.SwapMatched(swapId, counterparty);

        vm.prank(counterparty);
        dex.matchSwap(swapId);
    }

    function test_MatchSwap_RevertsNotOpen() public {
        uint256 swapId = _createSwap();

        vm.prank(counterparty);
        dex.matchSwap(swapId);

        // Attempt to match again
        vm.prank(thirdParty);
        vm.expectRevert("Not open");
        dex.matchSwap(swapId);
    }

    function test_MatchSwap_RevertsSelfMatch() public {
        uint256 swapId = _createSwap();

        vm.prank(initiator);
        vm.expectRevert("Cannot self-match");
        dex.matchSwap(swapId);
    }

    function test_MatchSwap_RevertsExpired() public {
        uint256 swapId = _createSwap();

        vm.warp(block.timestamp + MIN_EXPIRY + 1);

        vm.prank(counterparty);
        vm.expectRevert("Expired");
        dex.matchSwap(swapId);
    }

    // ─── Deposit Confirmation ─────────────────────────────────────────────────

    function _matchSwap(uint256 swapId) internal {
        vm.prank(counterparty);
        dex.matchSwap(swapId);
    }

    function test_DepositConfirmation_InitiatorConfirms() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.prank(initiator);
        dex.depositConfirmation(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertTrue(s.initiatorDeposited);
    }

    function test_DepositConfirmation_CounterpartyConfirms() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.prank(counterparty);
        dex.depositConfirmation(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertTrue(s.counterpartyDeposited);
    }

    function test_DepositConfirmation_BothConfirm_Settles() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.prank(initiator);
        dex.depositConfirmation(swapId);

        vm.prank(counterparty);
        dex.depositConfirmation(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertEq(uint8(s.status), uint8(SovereignDEX.SwapStatus.Settled));
        assertGt(s.settledAt, 0);
    }

    function test_DepositConfirmation_Settlement_DecrementsActiveSwaps() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);
        assertEq(dex.activeSwaps(), 1);

        vm.prank(initiator);
        dex.depositConfirmation(swapId);
        vm.prank(counterparty);
        dex.depositConfirmation(swapId);

        assertEq(dex.activeSwaps(), 0);
        assertEq(dex.settledSwaps(), 1);
    }

    function test_DepositConfirmation_Settlement_UpdatesVolumeAndPairStats() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.prank(initiator);
        dex.depositConfirmation(swapId);
        vm.prank(counterparty);
        dex.depositConfirmation(swapId);

        assertEq(dex.totalVolumeUSD(), OFFER_AMOUNT);

        SovereignDEX.PairStats memory ps = dex.getPairStats("USD", "EUR");
        assertEq(ps.totalVolume, OFFER_AMOUNT);
        assertEq(ps.totalSwaps, 1);
        assertGt(ps.lastPrice, 0);
    }

    function test_DepositConfirmation_EmitsSwapDepositedEvent() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.expectEmit(true, true, false, true);
        emit SovereignDEX.SwapDeposited(swapId, initiator, true);

        vm.prank(initiator);
        dex.depositConfirmation(swapId);
    }

    function test_DepositConfirmation_EmitsSwapSettledEvent() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.prank(initiator);
        dex.depositConfirmation(swapId);

        vm.expectEmit(true, false, false, false);
        emit SovereignDEX.SwapSettled(swapId, block.timestamp);

        vm.prank(counterparty);
        dex.depositConfirmation(swapId);
    }

    function test_DepositConfirmation_RevertsNotMatched() public {
        uint256 swapId = _createSwap();

        vm.prank(initiator);
        vm.expectRevert("Not matched");
        dex.depositConfirmation(swapId);
    }

    function test_DepositConfirmation_RevertsNotParty() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.prank(thirdParty);
        vm.expectRevert("Not party");
        dex.depositConfirmation(swapId);
    }

    function test_DepositConfirmation_RevertsDoubleDeposit() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.startPrank(initiator);
        dex.depositConfirmation(swapId);

        vm.expectRevert("Already deposited");
        dex.depositConfirmation(swapId);
        vm.stopPrank();
    }

    function test_DepositConfirmation_RevertsExpired() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.warp(block.timestamp + MIN_EXPIRY + 1);

        vm.prank(initiator);
        vm.expectRevert("Expired");
        dex.depositConfirmation(swapId);
    }

    // ─── Cancel Swap ──────────────────────────────────────────────────────────

    function test_CancelSwap_ByInitiator() public {
        uint256 swapId = _createSwap();

        vm.prank(initiator);
        dex.cancelSwap(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertEq(uint8(s.status), uint8(SovereignDEX.SwapStatus.Cancelled));
    }

    function test_CancelSwap_ByOwner() public {
        uint256 swapId = _createSwap();

        vm.prank(owner);
        dex.cancelSwap(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertEq(uint8(s.status), uint8(SovereignDEX.SwapStatus.Cancelled));
    }

    function test_CancelSwap_CanCancelMatched() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.prank(initiator);
        dex.cancelSwap(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertEq(uint8(s.status), uint8(SovereignDEX.SwapStatus.Cancelled));
    }

    function test_CancelSwap_DecrementsActiveSwaps() public {
        _createSwap();
        assertEq(dex.activeSwaps(), 1);

        vm.prank(initiator);
        dex.cancelSwap(1);

        assertEq(dex.activeSwaps(), 0);
    }

    function test_CancelSwap_EmitsEvent() public {
        uint256 swapId = _createSwap();

        vm.expectEmit(true, true, false, false);
        emit SovereignDEX.SwapCancelled(swapId, initiator);

        vm.prank(initiator);
        dex.cancelSwap(swapId);
    }

    function test_CancelSwap_RevertsUnauthorized() public {
        uint256 swapId = _createSwap();

        vm.prank(unauthorized);
        vm.expectRevert("Not authorised");
        dex.cancelSwap(swapId);
    }

    function test_CancelSwap_RevertsWhenSettled() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);
        vm.prank(initiator);
        dex.depositConfirmation(swapId);
        vm.prank(counterparty);
        dex.depositConfirmation(swapId);

        vm.prank(initiator);
        vm.expectRevert("Cannot cancel");
        dex.cancelSwap(swapId);
    }

    // ─── Expire Swap ──────────────────────────────────────────────────────────

    function test_ExpireSwap_AfterExpiry() public {
        uint256 swapId = _createSwap();

        vm.warp(block.timestamp + MIN_EXPIRY + 1);

        dex.expireSwap(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertEq(uint8(s.status), uint8(SovereignDEX.SwapStatus.Expired));
    }

    function test_ExpireSwap_DecrementsActiveSwaps() public {
        _createSwap();
        vm.warp(block.timestamp + MIN_EXPIRY + 1);
        dex.expireSwap(1);
        assertEq(dex.activeSwaps(), 0);
    }

    function test_ExpireSwap_EmitsEvent() public {
        uint256 swapId = _createSwap();
        vm.warp(block.timestamp + MIN_EXPIRY + 1);

        vm.expectEmit(true, false, false, false);
        emit SovereignDEX.SwapExpired(swapId);

        dex.expireSwap(swapId);
    }

    function test_ExpireSwap_RevertsBeforeExpiry() public {
        uint256 swapId = _createSwap();

        vm.expectRevert("Not yet expired");
        dex.expireSwap(swapId);
    }

    function test_ExpireSwap_CanExpireMatchedSwap() public {
        uint256 swapId = _createSwap();
        _matchSwap(swapId);

        vm.warp(block.timestamp + MIN_EXPIRY + 1);
        dex.expireSwap(swapId);

        SovereignDEX.CurrencySwap memory s = dex.getSwap(swapId);
        assertEq(uint8(s.status), uint8(SovereignDEX.SwapStatus.Expired));
    }

    // ─── Multiple Swaps / Pair Stats ──────────────────────────────────────────

    function test_MultiplePairs_IndependentPairStats() public {
        // USD/EUR swap
        vm.prank(initiator);
        uint256 swap1 = dex.createSwap("USD", "EUR", 1_000 * 1e18, 1_200 * 1e18, MIN_EXPIRY);
        vm.prank(counterparty);
        dex.matchSwap(swap1);
        vm.prank(initiator);
        dex.depositConfirmation(swap1);
        vm.prank(counterparty);
        dex.depositConfirmation(swap1);

        // GBP/JPY swap
        vm.prank(initiator);
        uint256 swap2 = dex.createSwap("GBP", "JPY", 500 * 1e18, 90_000 * 1e18, MIN_EXPIRY);
        vm.prank(counterparty);
        dex.matchSwap(swap2);
        vm.prank(initiator);
        dex.depositConfirmation(swap2);
        vm.prank(counterparty);
        dex.depositConfirmation(swap2);

        SovereignDEX.PairStats memory ps1 = dex.getPairStats("USD", "EUR");
        SovereignDEX.PairStats memory ps2 = dex.getPairStats("GBP", "JPY");

        assertEq(ps1.totalSwaps, 1);
        assertEq(ps2.totalSwaps, 1);
        assertEq(ps1.totalVolume, 1_000 * 1e18);
        assertEq(ps2.totalVolume, 500 * 1e18);
    }

    function test_UserSwaps_TracksBothRoles() public {
        // initiator creates, counterparty matches
        uint256 swapId = _createSwap();
        vm.prank(counterparty);
        dex.matchSwap(swapId);

        uint256[] memory iSwaps = dex.getUserSwaps(initiator);
        uint256[] memory cSwaps = dex.getUserSwaps(counterparty);

        assertEq(iSwaps.length, 1);
        assertEq(cSwaps.length, 1);
        assertEq(iSwaps[0], swapId);
        assertEq(cSwaps[0], swapId);
    }

    // ─── Constants ────────────────────────────────────────────────────────────

    function test_Constants_FeeAndExpiry() public view {
        assertEq(dex.SWAP_FEE_BPS(), 10);
        assertEq(dex.MIN_EXPIRY(), 1 hours);
        assertEq(dex.MAX_EXPIRY(), 30 days);
    }
}
