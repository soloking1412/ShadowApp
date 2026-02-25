// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/BondAuctionHouse.sol";

contract BondAuctionHouseTest is Test {
    BondAuctionHouse public auctionHouse;

    address public owner   = address(1);
    address public issuer  = address(2);
    address public bidder1 = address(3);
    address public bidder2 = address(4);
    address public bidder3 = address(5);
    address public unauthorized = address(6);

    // Common bond parameters
    string  public constant BOND_NAME  = "SovereignBond2030";
    string  public constant BOND_ISIN  = "XS0000000001";
    uint256 public constant FACE_VALUE = 1_000 * 1e18;    // $1,000 face value
    uint256 public constant SUPPLY     = 100;              // 100 units
    uint256 public constant ONE_HOUR   = 3600;

    // Dutch auction parameters
    uint256 public constant START_PRICE   = 1_100 * 1e18;
    uint256 public constant MIN_PRICE     = 900 * 1e18;
    uint256 public constant DECREMENT     = 10 * 1e18;
    uint256 public constant DEC_INTERVAL  = 600;           // 10 minutes

    // Sealed bid parameters
    uint256 public constant RESERVE_PRICE = 950 * 1e18;

    // ─── Setup ────────────────────────────────────────────────────────────────

    function setUp() public {
        BondAuctionHouse impl = new BondAuctionHouse();
        bytes memory init = abi.encodeCall(BondAuctionHouse.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        auctionHouse = BondAuctionHouse(address(proxy));
    }

    // ─── Initialization ───────────────────────────────────────────────────────

    function test_Initialize_SetsOwner() public view {
        assertEq(auctionHouse.owner(), owner);
    }

    function test_Initialize_CountersAtZero() public view {
        assertEq(auctionHouse.auctionCounter(), 0);
        assertEq(auctionHouse.totalCapitalRaised(), 0);
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        auctionHouse.initialize(owner);
    }

    // ─── Create Dutch Auction ─────────────────────────────────────────────────

    function _createDutchAuction() internal returns (uint256 auctionId) {
        vm.prank(issuer);
        auctionId = auctionHouse.createDutchAuction(
            BOND_NAME,
            BOND_ISIN,
            FACE_VALUE,
            SUPPLY,
            START_PRICE,
            MIN_PRICE,
            DECREMENT,
            DEC_INTERVAL,
            ONE_HOUR
        );
    }

    function test_CreateDutchAuction_IncrementsCounter() public {
        uint256 id = _createDutchAuction();
        assertEq(id, 1);
        assertEq(auctionHouse.auctionCounter(), 1);
    }

    function test_CreateDutchAuction_StoresAuctionData() public {
        uint256 id = _createDutchAuction();
        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);

        assertEq(a.auctionId, 1);
        assertEq(uint8(a.auctionType), uint8(BondAuctionHouse.AuctionType.Dutch));
        assertEq(uint8(a.status), uint8(BondAuctionHouse.AuctionStatus.Active));
        assertEq(a.issuer, issuer);
        assertEq(a.bondName, BOND_NAME);
        assertEq(a.bondISIN, BOND_ISIN);
        assertEq(a.faceValue, FACE_VALUE);
        assertEq(a.totalSupply, SUPPLY);
        assertEq(a.startPrice, START_PRICE);
        assertEq(a.currentPrice, START_PRICE);
        assertEq(a.minPrice, MIN_PRICE);
        assertEq(a.priceDecrement, DECREMENT);
        assertEq(a.decrementInterval, DEC_INTERVAL);
        assertEq(a.unitsSold, 0);
        assertEq(a.totalRaised, 0);
    }

    function test_CreateDutchAuction_SetsEndTime() public {
        uint256 before = block.timestamp;
        uint256 id = _createDutchAuction();
        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(a.endTime, before + ONE_HOUR);
    }

    function test_CreateDutchAuction_EmitsEvent() public {
        vm.expectEmit(true, false, true, true);
        emit BondAuctionHouse.AuctionCreated(
            1,
            BondAuctionHouse.AuctionType.Dutch,
            issuer,
            BOND_NAME,
            FACE_VALUE,
            SUPPLY
        );

        _createDutchAuction();
    }

    function test_CreateDutchAuction_RegistersIssuerAuctions() public {
        uint256 id = _createDutchAuction();
        uint256[] memory issuerList = auctionHouse.getIssuerAuctions(issuer);
        assertEq(issuerList.length, 1);
        assertEq(issuerList[0], id);
    }

    function test_CreateDutchAuction_RevertsStartNotExceedMin() public {
        vm.prank(issuer);
        vm.expectRevert("Start must exceed min");
        auctionHouse.createDutchAuction(
            BOND_NAME, BOND_ISIN, FACE_VALUE, SUPPLY,
            MIN_PRICE,   // startPrice == minPrice
            MIN_PRICE,
            DECREMENT, DEC_INTERVAL, ONE_HOUR
        );
    }

    function test_CreateDutchAuction_RevertsZeroFaceValue() public {
        vm.prank(issuer);
        vm.expectRevert("Invalid bond params");
        auctionHouse.createDutchAuction(
            BOND_NAME, BOND_ISIN,
            0,         // zero face value
            SUPPLY,
            START_PRICE, MIN_PRICE, DECREMENT, DEC_INTERVAL, ONE_HOUR
        );
    }

    function test_CreateDutchAuction_RevertsDurationTooShort() public {
        vm.prank(issuer);
        vm.expectRevert("Duration too short");
        auctionHouse.createDutchAuction(
            BOND_NAME, BOND_ISIN, FACE_VALUE, SUPPLY,
            START_PRICE, MIN_PRICE, DECREMENT, DEC_INTERVAL,
            30 minutes   // below 1 hour minimum
        );
    }

    // ─── Create Sealed Bid Auction ────────────────────────────────────────────

    function _createSealedAuction() internal returns (uint256 auctionId) {
        vm.prank(issuer);
        auctionId = auctionHouse.createSealedBidAuction(
            BOND_NAME,
            BOND_ISIN,
            FACE_VALUE,
            SUPPLY,
            RESERVE_PRICE,
            ONE_HOUR
        );
    }

    function test_CreateSealedAuction_IncrementsCounter() public {
        uint256 id = _createSealedAuction();
        assertEq(id, 1);
    }

    function test_CreateSealedAuction_SetsCorrectType() public {
        uint256 id = _createSealedAuction();
        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(uint8(a.auctionType), uint8(BondAuctionHouse.AuctionType.SealedBid));
    }

    function test_CreateSealedAuction_SetsReserveAsMinPrice() public {
        uint256 id = _createSealedAuction();
        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(a.minPrice, RESERVE_PRICE);
        assertEq(a.startPrice, RESERVE_PRICE);
        assertEq(a.currentPrice, RESERVE_PRICE);
        assertEq(a.priceDecrement, 0);
    }

    function test_CreateSealedAuction_EmitsEvent() public {
        vm.expectEmit(true, false, true, false);
        emit BondAuctionHouse.AuctionCreated(1, BondAuctionHouse.AuctionType.SealedBid, issuer, BOND_NAME, FACE_VALUE, SUPPLY);

        _createSealedAuction();
    }

    function test_CreateSealedAuction_RevertsDurationTooShort() public {
        vm.prank(issuer);
        vm.expectRevert("Duration too short");
        auctionHouse.createSealedBidAuction(
            BOND_NAME, BOND_ISIN, FACE_VALUE, SUPPLY, RESERVE_PRICE,
            30 minutes
        );
    }

    // ─── Dutch Bid ────────────────────────────────────────────────────────────

    function test_DutchBid_RegistersBid() public {
        uint256 id = _createDutchAuction();

        vm.prank(bidder1);
        auctionHouse.dutchBid(id, 10);

        BondAuctionHouse.Bid[] memory bids = auctionHouse.getAuctionBids(id);
        assertEq(bids.length, 1);
        assertEq(bids[0].bidder, bidder1);
        assertEq(bids[0].quantity, 10);
        assertEq(bids[0].amount, START_PRICE);
        assertTrue(bids[0].revealed);
    }

    function test_DutchBid_UpdatesAuctionTotals() public {
        uint256 id = _createDutchAuction();

        vm.prank(bidder1);
        auctionHouse.dutchBid(id, 10);

        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(a.unitsSold, 10);
        assertEq(a.totalRaised, START_PRICE * 10);
        assertEq(a.winner, bidder1);
    }

    function test_DutchBid_UpdatesGlobalCapital() public {
        uint256 id = _createDutchAuction();

        vm.prank(bidder1);
        auctionHouse.dutchBid(id, 5);

        assertEq(auctionHouse.totalCapitalRaised(), START_PRICE * 5);
    }

    function test_DutchBid_AutoSettlesWhenFullySold() public {
        uint256 id = _createDutchAuction();

        // Buy all 100 units
        vm.prank(bidder1);
        auctionHouse.dutchBid(id, SUPPLY);

        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(uint8(a.status), uint8(BondAuctionHouse.AuctionStatus.Settled));
    }

    function test_DutchBid_AutoSettles_EmitsAuctionSettledEvent() public {
        uint256 id = _createDutchAuction();

        vm.expectEmit(true, false, false, false);
        emit BondAuctionHouse.AuctionSettled(id, bidder1, START_PRICE, START_PRICE * SUPPLY);

        vm.prank(bidder1);
        auctionHouse.dutchBid(id, SUPPLY);
    }

    function test_DutchBid_PartialBid_EmitsBidPlacedEvent() public {
        uint256 id = _createDutchAuction();

        vm.expectEmit(true, true, false, true);
        emit BondAuctionHouse.BidPlaced(id, bidder1, START_PRICE, 10);

        vm.prank(bidder1);
        auctionHouse.dutchBid(id, 10);
    }

    function test_DutchBid_RegistersBidderAuctions() public {
        uint256 id = _createDutchAuction();

        vm.prank(bidder1);
        auctionHouse.dutchBid(id, 5);

        uint256[] memory bidderList = auctionHouse.getBidderAuctions(bidder1);
        assertEq(bidderList.length, 1);
        assertEq(bidderList[0], id);
    }

    function test_DutchBid_RevertsNotActive() public {
        uint256 id = _createDutchAuction();

        // Cancel the auction first
        vm.prank(issuer);
        auctionHouse.cancelAuction(id);

        vm.prank(bidder1);
        vm.expectRevert("Not active");
        auctionHouse.dutchBid(id, 5);
    }

    function test_DutchBid_RevertsExpired() public {
        uint256 id = _createDutchAuction();

        vm.warp(block.timestamp + ONE_HOUR + 1);

        vm.prank(bidder1);
        vm.expectRevert("Expired");
        auctionHouse.dutchBid(id, 5);
    }

    function test_DutchBid_RevertsNotDutchType() public {
        uint256 id = _createSealedAuction();

        vm.prank(bidder1);
        vm.expectRevert("Not Dutch");
        auctionHouse.dutchBid(id, 5);
    }

    function test_DutchBid_RevertsExcessiveQuantity() public {
        uint256 id = _createDutchAuction();

        vm.prank(bidder1);
        vm.expectRevert("Invalid quantity");
        auctionHouse.dutchBid(id, SUPPLY + 1);
    }

    // ─── Dutch Price Decrement ─────────────────────────────────────────────────

    function test_DutchBid_PriceDecrementsAfterInterval() public {
        uint256 id = _createDutchAuction();

        // Advance time by one decrement interval
        vm.warp(block.timestamp + DEC_INTERVAL + 1);

        uint256 expectedPrice = auctionHouse.getCurrentDutchPrice(id);
        assertEq(expectedPrice, START_PRICE - DECREMENT);
    }

    function test_DutchBid_PriceFloor() public {
        uint256 id = _createDutchAuction();

        // Advance far into the future — price should floor at minPrice
        vm.warp(block.timestamp + ONE_HOUR - 1);

        uint256 price = auctionHouse.getCurrentDutchPrice(id);
        assertGe(price, MIN_PRICE, "Price should not go below minimum");
    }

    function test_DutchBid_EmitsPriceDecrementedEvent() public {
        uint256 id = _createDutchAuction();

        vm.warp(block.timestamp + DEC_INTERVAL + 1);

        vm.expectEmit(true, false, false, false);
        emit BondAuctionHouse.DutchPriceDecremented(id, START_PRICE - DECREMENT);

        vm.prank(bidder1);
        auctionHouse.dutchBid(id, 1);
    }

    // ─── Sealed Bid ───────────────────────────────────────────────────────────

    function test_SealedBid_RecordsBid() public {
        uint256 id = _createSealedAuction();

        vm.prank(bidder1);
        auctionHouse.sealedBid(id, RESERVE_PRICE + 50 * 1e18, 20);

        BondAuctionHouse.Bid[] memory bids = auctionHouse.getAuctionBids(id);
        assertEq(bids.length, 1);
        assertEq(bids[0].bidder, bidder1);
        assertEq(bids[0].amount, RESERVE_PRICE + 50 * 1e18);
        assertEq(bids[0].quantity, 20);
        assertFalse(bids[0].revealed);  // sealed bids start unrevealed
    }

    function test_SealedBid_MultipleBidders() public {
        uint256 id = _createSealedAuction();

        vm.prank(bidder1);
        auctionHouse.sealedBid(id, RESERVE_PRICE + 10 * 1e18, 10);
        vm.prank(bidder2);
        auctionHouse.sealedBid(id, RESERVE_PRICE + 50 * 1e18, 20);
        vm.prank(bidder3);
        auctionHouse.sealedBid(id, RESERVE_PRICE + 30 * 1e18, 15);

        BondAuctionHouse.Bid[] memory bids = auctionHouse.getAuctionBids(id);
        assertEq(bids.length, 3);
    }

    function test_SealedBid_EmitsBidPlacedEvent() public {
        uint256 id = _createSealedAuction();
        uint256 bidPrice = RESERVE_PRICE + 20 * 1e18;

        vm.expectEmit(true, true, false, true);
        emit BondAuctionHouse.BidPlaced(id, bidder1, bidPrice, 10);

        vm.prank(bidder1);
        auctionHouse.sealedBid(id, bidPrice, 10);
    }

    function test_SealedBid_RegistersBidderAuctions() public {
        uint256 id = _createSealedAuction();

        vm.prank(bidder1);
        auctionHouse.sealedBid(id, RESERVE_PRICE, 5);

        uint256[] memory list = auctionHouse.getBidderAuctions(bidder1);
        assertEq(list.length, 1);
        assertEq(list[0], id);
    }

    function test_SealedBid_RevertsBelowReserve() public {
        uint256 id = _createSealedAuction();

        vm.prank(bidder1);
        vm.expectRevert("Below reserve");
        auctionHouse.sealedBid(id, RESERVE_PRICE - 1, 5);
    }

    function test_SealedBid_RevertsExpired() public {
        uint256 id = _createSealedAuction();

        vm.warp(block.timestamp + ONE_HOUR + 1);

        vm.prank(bidder1);
        vm.expectRevert("Expired");
        auctionHouse.sealedBid(id, RESERVE_PRICE, 5);
    }

    function test_SealedBid_RevertsNotSealedType() public {
        uint256 id = _createDutchAuction();

        vm.prank(bidder1);
        vm.expectRevert("Not sealed bid");
        auctionHouse.sealedBid(id, START_PRICE, 5);
    }

    // ─── Settle Sealed Auction ────────────────────────────────────────────────

    function test_SettleSealedAuction_ByIssuerBeforeEnd() public {
        uint256 id = _createSealedAuction();

        vm.prank(bidder1);
        auctionHouse.sealedBid(id, RESERVE_PRICE + 100 * 1e18, 10);
        vm.prank(bidder2);
        auctionHouse.sealedBid(id, RESERVE_PRICE + 200 * 1e18, 20);

        // Issuer can settle before end time
        vm.prank(issuer);
        auctionHouse.settleSealedAuction(id);

        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(uint8(a.status), uint8(BondAuctionHouse.AuctionStatus.Settled));
        assertEq(a.winner, bidder2);
        assertEq(a.winningBid, RESERVE_PRICE + 200 * 1e18);
    }

    function test_SettleSealedAuction_AnyoneAfterEnd() public {
        uint256 id = _createSealedAuction();

        vm.prank(bidder1);
        auctionHouse.sealedBid(id, RESERVE_PRICE + 50 * 1e18, 5);

        vm.warp(block.timestamp + ONE_HOUR + 1);

        // Non-issuer can settle after expiry
        vm.prank(bidder2);
        auctionHouse.settleSealedAuction(id);

        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(uint8(a.status), uint8(BondAuctionHouse.AuctionStatus.Settled));
    }

    function test_SettleSealedAuction_EmitsSettledEvent() public {
        uint256 id = _createSealedAuction();
        uint256 bidPrice = RESERVE_PRICE + 100 * 1e18;

        vm.prank(bidder1);
        auctionHouse.sealedBid(id, bidPrice, 10);

        vm.expectEmit(true, false, false, false);
        emit BondAuctionHouse.AuctionSettled(id, bidder1, bidPrice, bidPrice * SUPPLY);

        vm.prank(issuer);
        auctionHouse.settleSealedAuction(id);
    }

    function test_SettleSealedAuction_NoBids_WinnerIsZeroAddress() public {
        uint256 id = _createSealedAuction();

        vm.prank(issuer);
        auctionHouse.settleSealedAuction(id);

        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(a.winner, address(0));
        assertEq(a.winningBid, 0);
    }

    function test_SettleSealedAuction_UpdatesGlobalCapital() public {
        uint256 id = _createSealedAuction();
        uint256 bidPrice = RESERVE_PRICE + 100 * 1e18;

        vm.prank(bidder1);
        auctionHouse.sealedBid(id, bidPrice, 10);

        vm.prank(issuer);
        auctionHouse.settleSealedAuction(id);

        assertEq(auctionHouse.totalCapitalRaised(), bidPrice * SUPPLY);
    }

    function test_SettleSealedAuction_RevertsNotActive() public {
        uint256 id = _createSealedAuction();
        vm.prank(issuer);
        auctionHouse.cancelAuction(id);

        vm.expectRevert("Not active");
        auctionHouse.settleSealedAuction(id);
    }

    function test_SettleSealedAuction_RevertsNotEnded_ByNonIssuer() public {
        uint256 id = _createSealedAuction();

        // Non-issuer cannot settle before end
        vm.prank(bidder1);
        vm.expectRevert("Not ended");
        auctionHouse.settleSealedAuction(id);
    }

    // ─── Cancel Auction ───────────────────────────────────────────────────────

    function test_CancelAuction_ByIssuer() public {
        uint256 id = _createDutchAuction();

        vm.prank(issuer);
        auctionHouse.cancelAuction(id);

        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(uint8(a.status), uint8(BondAuctionHouse.AuctionStatus.Cancelled));
    }

    function test_CancelAuction_ByOwner() public {
        uint256 id = _createDutchAuction();

        vm.prank(owner);
        auctionHouse.cancelAuction(id);

        BondAuctionHouse.Auction memory a = auctionHouse.getAuction(id);
        assertEq(uint8(a.status), uint8(BondAuctionHouse.AuctionStatus.Cancelled));
    }

    function test_CancelAuction_EmitsEvent() public {
        uint256 id = _createDutchAuction();

        vm.expectEmit(true, false, false, false);
        emit BondAuctionHouse.AuctionCancelled(id);

        vm.prank(issuer);
        auctionHouse.cancelAuction(id);
    }

    function test_CancelAuction_RevertsUnauthorized() public {
        uint256 id = _createDutchAuction();

        vm.prank(unauthorized);
        vm.expectRevert("Not authorised");
        auctionHouse.cancelAuction(id);
    }

    function test_CancelAuction_RevertsAlreadyCancelled() public {
        uint256 id = _createDutchAuction();

        vm.prank(issuer);
        auctionHouse.cancelAuction(id);

        vm.prank(issuer);
        vm.expectRevert("Not active");
        auctionHouse.cancelAuction(id);
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    function test_GetCurrentDutchPrice_NoDecrementIntervalReturnsCurrentPrice() public {
        // Create an auction with no decrement interval
        vm.prank(issuer);
        uint256 id = auctionHouse.createDutchAuction(
            BOND_NAME, BOND_ISIN, FACE_VALUE, SUPPLY,
            START_PRICE, MIN_PRICE,
            DECREMENT,
            0,         // zero interval = no auto-decrement
            ONE_HOUR
        );

        assertEq(auctionHouse.getCurrentDutchPrice(id), START_PRICE);
    }

    function test_MultipleIssuers_IndependentAuctions() public {
        vm.prank(issuer);
        uint256 id1 = auctionHouse.createDutchAuction(
            BOND_NAME, BOND_ISIN, FACE_VALUE, SUPPLY,
            START_PRICE, MIN_PRICE, DECREMENT, DEC_INTERVAL, ONE_HOUR
        );

        vm.prank(unauthorized);  // second issuer
        uint256 id2 = auctionHouse.createSealedBidAuction(
            "OtherBond", "XS9999", FACE_VALUE, 50,
            RESERVE_PRICE, ONE_HOUR
        );

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(auctionHouse.getIssuerAuctions(issuer).length, 1);
        assertEq(auctionHouse.getIssuerAuctions(unauthorized).length, 1);
    }
}
