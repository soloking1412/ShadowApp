// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title BondAuctionHouse — Dutch and sealed-bid auctions for 2DI bonds
/// @notice Supports two auction types:
///         - Dutch: price starts high and decrements until a buyer accepts
///         - Sealed: participants submit blind bids, winner pays clearing price
contract BondAuctionHouse is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    enum AuctionType   { Dutch, SealedBid }
    enum AuctionStatus { Active, Settled, Cancelled }

    struct Auction {
        uint256 auctionId;
        AuctionType auctionType;
        AuctionStatus status;
        address issuer;
        string  bondName;
        string  bondISIN;
        uint256 faceValue;          // in wei
        uint256 totalSupply;        // units available
        uint256 startPrice;         // Dutch: start; Sealed: reserve
        uint256 currentPrice;       // Dutch: current decrement price
        uint256 priceDecrement;     // Dutch: decrement per interval
        uint256 decrementInterval;  // Dutch: seconds between price drops
        uint256 lastDecrementAt;
        uint256 minPrice;           // Dutch: floor price
        uint256 startTime;
        uint256 endTime;
        uint256 totalRaised;
        uint256 unitsSold;
        address winner;             // SealedBid: winning bidder
        uint256 winningBid;
    }

    struct Bid {
        address bidder;
        uint256 amount;      // price per unit
        uint256 quantity;
        uint256 timestamp;
        bool    revealed;    // SealedBid only
    }

    uint256 public auctionCounter;
    uint256 public totalCapitalRaised;

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(address => uint256[]) public issuerAuctions;
    mapping(address => uint256[]) public bidderAuctions;

    event AuctionCreated(uint256 indexed auctionId, AuctionType auctionType, address indexed issuer, string bondName, uint256 faceValue, uint256 totalSupply);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint256 quantity);
    event DutchPriceDecremented(uint256 indexed auctionId, uint256 newPrice);
    event AuctionSettled(uint256 indexed auctionId, address winner, uint256 clearingPrice, uint256 totalRaised);
    event AuctionCancelled(uint256 indexed auctionId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    // ─── CREATE AUCTION ───────────────────────────────────────────────────────

    function createDutchAuction(
        string calldata bondName,
        string calldata bondISIN,
        uint256 faceValue,
        uint256 totalSupply,
        uint256 startPrice,
        uint256 minPrice,
        uint256 priceDecrement,
        uint256 decrementInterval,
        uint256 durationSeconds
    ) external returns (uint256 auctionId) {
        require(startPrice > minPrice, "Start must exceed min");
        require(faceValue > 0 && totalSupply > 0, "Invalid bond params");
        require(durationSeconds >= 1 hours, "Duration too short");

        auctionId = ++auctionCounter;
        auctions[auctionId] = Auction({
            auctionId: auctionId,
            auctionType: AuctionType.Dutch,
            status: AuctionStatus.Active,
            issuer: msg.sender,
            bondName: bondName,
            bondISIN: bondISIN,
            faceValue: faceValue,
            totalSupply: totalSupply,
            startPrice: startPrice,
            currentPrice: startPrice,
            priceDecrement: priceDecrement,
            decrementInterval: decrementInterval,
            lastDecrementAt: block.timestamp,
            minPrice: minPrice,
            startTime: block.timestamp,
            endTime: block.timestamp + durationSeconds,
            totalRaised: 0,
            unitsSold: 0,
            winner: address(0),
            winningBid: 0
        });

        issuerAuctions[msg.sender].push(auctionId);
        emit AuctionCreated(auctionId, AuctionType.Dutch, msg.sender, bondName, faceValue, totalSupply);
    }

    function createSealedBidAuction(
        string calldata bondName,
        string calldata bondISIN,
        uint256 faceValue,
        uint256 totalSupply,
        uint256 reservePrice,
        uint256 durationSeconds
    ) external returns (uint256 auctionId) {
        require(faceValue > 0 && totalSupply > 0, "Invalid bond params");
        require(durationSeconds >= 1 hours, "Duration too short");

        auctionId = ++auctionCounter;
        auctions[auctionId] = Auction({
            auctionId: auctionId,
            auctionType: AuctionType.SealedBid,
            status: AuctionStatus.Active,
            issuer: msg.sender,
            bondName: bondName,
            bondISIN: bondISIN,
            faceValue: faceValue,
            totalSupply: totalSupply,
            startPrice: reservePrice,
            currentPrice: reservePrice,
            priceDecrement: 0,
            decrementInterval: 0,
            lastDecrementAt: 0,
            minPrice: reservePrice,
            startTime: block.timestamp,
            endTime: block.timestamp + durationSeconds,
            totalRaised: 0,
            unitsSold: 0,
            winner: address(0),
            winningBid: 0
        });

        issuerAuctions[msg.sender].push(auctionId);
        emit AuctionCreated(auctionId, AuctionType.SealedBid, msg.sender, bondName, faceValue, totalSupply);
    }

    // ─── DUTCH AUCTION BID ────────────────────────────────────────────────────

    function dutchBid(uint256 auctionId, uint256 quantity) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.Active, "Not active");
        require(a.auctionType == AuctionType.Dutch, "Not Dutch");
        require(block.timestamp <= a.endTime, "Expired");
        require(quantity > 0 && quantity <= a.totalSupply - a.unitsSold, "Invalid quantity");

        // Decrement price if interval has passed
        _decrementDutchPrice(a);

        uint256 totalCost = a.currentPrice * quantity;
        a.unitsSold += quantity;
        a.totalRaised += totalCost;
        a.winner = msg.sender;
        a.winningBid = a.currentPrice;
        totalCapitalRaised += totalCost;

        auctionBids[auctionId].push(Bid({
            bidder: msg.sender,
            amount: a.currentPrice,
            quantity: quantity,
            timestamp: block.timestamp,
            revealed: true
        }));
        bidderAuctions[msg.sender].push(auctionId);

        // Auto-settle when all units sold
        if (a.unitsSold >= a.totalSupply) {
            a.status = AuctionStatus.Settled;
            emit AuctionSettled(auctionId, msg.sender, a.currentPrice, a.totalRaised);
        } else {
            emit BidPlaced(auctionId, msg.sender, a.currentPrice, quantity);
        }
    }

    function _decrementDutchPrice(Auction storage a) internal {
        if (a.decrementInterval == 0) return;
        uint256 intervals = (block.timestamp - a.lastDecrementAt) / a.decrementInterval;
        if (intervals == 0) return;

        uint256 newPrice = a.currentPrice;
        for (uint256 i = 0; i < intervals; i++) {
            if (newPrice <= a.priceDecrement + a.minPrice) { newPrice = a.minPrice; break; }
            newPrice -= a.priceDecrement;
        }
        if (newPrice != a.currentPrice) {
            a.currentPrice = newPrice;
            a.lastDecrementAt = block.timestamp;
            emit DutchPriceDecremented(a.auctionId, newPrice);
        }
    }

    // ─── SEALED BID ───────────────────────────────────────────────────────────

    function sealedBid(uint256 auctionId, uint256 bidPrice, uint256 quantity) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.Active, "Not active");
        require(a.auctionType == AuctionType.SealedBid, "Not sealed bid");
        require(block.timestamp <= a.endTime, "Expired");
        require(bidPrice >= a.minPrice, "Below reserve");
        require(quantity > 0, "Invalid quantity");

        auctionBids[auctionId].push(Bid({
            bidder: msg.sender,
            amount: bidPrice,
            quantity: quantity,
            timestamp: block.timestamp,
            revealed: false
        }));
        bidderAuctions[msg.sender].push(auctionId);

        emit BidPlaced(auctionId, msg.sender, bidPrice, quantity);
    }

    // ─── SETTLE SEALED BID ────────────────────────────────────────────────────

    function settleSealedAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.Active, "Not active");
        require(a.auctionType == AuctionType.SealedBid, "Not sealed bid");
        require(block.timestamp > a.endTime || msg.sender == a.issuer, "Not ended");

        // Find highest bid
        Bid[] storage bids = auctionBids[auctionId];
        uint256 highestBid = 0;
        address winner = address(0);

        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].amount > highestBid) {
                highestBid = bids[i].amount;
                winner = bids[i].bidder;
            }
        }

        a.status = AuctionStatus.Settled;
        a.winner = winner;
        a.winningBid = highestBid;
        a.totalRaised = highestBid * a.totalSupply;
        a.unitsSold = a.totalSupply;
        totalCapitalRaised += a.totalRaised;

        emit AuctionSettled(auctionId, winner, highestBid, a.totalRaised);
    }

    // ─── CANCEL ───────────────────────────────────────────────────────────────

    function cancelAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.Active, "Not active");
        require(msg.sender == a.issuer || msg.sender == owner(), "Not authorised");

        a.status = AuctionStatus.Cancelled;
        emit AuctionCancelled(auctionId);
    }

    // ─── VIEWS ────────────────────────────────────────────────────────────────

    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    function getAuctionBids(uint256 auctionId) external view returns (Bid[] memory) {
        return auctionBids[auctionId];
    }

    function getIssuerAuctions(address issuer) external view returns (uint256[] memory) {
        return issuerAuctions[issuer];
    }

    function getBidderAuctions(address bidder) external view returns (uint256[] memory) {
        return bidderAuctions[bidder];
    }

    function getCurrentDutchPrice(uint256 auctionId) external view returns (uint256) {
        Auction storage a = auctions[auctionId];
        if (a.auctionType != AuctionType.Dutch || a.decrementInterval == 0) return a.currentPrice;

        uint256 intervals = (block.timestamp - a.lastDecrementAt) / a.decrementInterval;
        uint256 price = a.currentPrice;
        for (uint256 i = 0; i < intervals; i++) {
            if (price <= a.priceDecrement + a.minPrice) { price = a.minPrice; break; }
            price -= a.priceDecrement;
        }
        return price;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
