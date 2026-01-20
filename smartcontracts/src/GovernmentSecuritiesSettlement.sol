// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title GovernmentSecuritiesSettlement
 * @notice T+1 Settlement and Clearing for Government Securities
 * @dev Enables governments to use OZF services for securities settlement
 */
contract GovernmentSecuritiesSettlement is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SETTLER_ROLE = keccak256("SETTLER_ROLE");
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT_ROLE");
    bytes32 public constant CLEARING_HOUSE_ROLE = keccak256("CLEARING_HOUSE_ROLE");

    enum SecurityType {
        TreasuryBond,
        TreasuryBill,
        TreasuryNote,
        MunicipalBond,
        AgencyBond,
        SovereignBond,
        InfrastructureBond
    }

    enum SettlementStatus {
        Pending,
        Cleared,
        Settled,
        Failed,
        Cancelled
    }

    struct Security {
        uint256 securityId;
        SecurityType securityType;
        address issuer;
        string isin; // International Securities Identification Number
        string cusip; // Committee on Uniform Securities Identification Procedures
        uint256 faceValue;
        uint256 couponRate;
        uint256 maturityDate;
        uint256 issuanceDate;
        uint256 totalIssued;
        uint256 outstandingAmount;
        bool active;
    }

    struct Trade {
        uint256 tradeId;
        uint256 securityId;
        address buyer;
        address seller;
        uint256 quantity;
        uint256 price;
        uint256 tradeDate;
        uint256 settlementDate; // T+1
        SettlementStatus status;
        bytes32 clearingRef;
    }

    struct ClearingHouse {
        address clearingHouseAddress;
        string name;
        string jurisdiction;
        bool active;
        uint256 totalTradesCleared;
        uint256 totalValueCleared;
    }

    // State variables
    mapping(uint256 => Security) public securities;
    mapping(uint256 => Trade) public trades;
    mapping(address => ClearingHouse) public clearingHouses;
    mapping(address => mapping(uint256 => uint256)) public holdings; // user => securityId => amount
    mapping(bytes32 => bool) public processedClearings;

    uint256 public securityCounter;
    uint256 public tradeCounter;
    uint256 public constant SETTLEMENT_PERIOD = 1 days; // T+1
    uint256 public totalSecuritiesValue;

    // Events
    event SecurityIssued(
        uint256 indexed securityId,
        SecurityType securityType,
        address indexed issuer,
        uint256 totalIssued,
        string isin
    );

    event TradeExecuted(
        uint256 indexed tradeId,
        uint256 indexed securityId,
        address indexed buyer,
        address seller,
        uint256 quantity,
        uint256 price
    );

    event TradeCleared(
        uint256 indexed tradeId,
        bytes32 clearingRef,
        address clearingHouse
    );

    event TradeSettled(
        uint256 indexed tradeId,
        uint256 settlementDate
    );

    event ClearingHouseRegistered(
        address indexed clearingHouse,
        string name,
        string jurisdiction
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(SETTLER_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    /**
     * @notice Issue a new government security
     */
    function issueSecurity(
        SecurityType securityType,
        string memory isin,
        string memory cusip,
        uint256 faceValue,
        uint256 couponRate,
        uint256 maturityDate,
        uint256 totalIssued
    ) external onlyRole(GOVERNMENT_ROLE) whenNotPaused returns (uint256) {
        require(totalIssued > 0, "Invalid issuance amount");
        require(maturityDate > block.timestamp, "Invalid maturity date");

        uint256 securityId = ++securityCounter;

        securities[securityId] = Security({
            securityId: securityId,
            securityType: securityType,
            issuer: msg.sender,
            isin: isin,
            cusip: cusip,
            faceValue: faceValue,
            couponRate: couponRate,
            maturityDate: maturityDate,
            issuanceDate: block.timestamp,
            totalIssued: totalIssued,
            outstandingAmount: totalIssued,
            active: true
        });

        holdings[msg.sender][securityId] = totalIssued;
        totalSecuritiesValue += (totalIssued * faceValue);

        emit SecurityIssued(securityId, securityType, msg.sender, totalIssued, isin);

        return securityId;
    }

    /**
     * @notice Execute a trade (T+1 settlement)
     */
    function executeTrade(
        uint256 securityId,
        address seller,
        uint256 quantity,
        uint256 price
    ) external whenNotPaused nonReentrant returns (uint256) {
        Security storage security = securities[securityId];
        require(security.active, "Security not active");
        require(holdings[seller][securityId] >= quantity, "Insufficient holdings");

        uint256 tradeId = ++tradeCounter;
        uint256 settlementDate = block.timestamp + SETTLEMENT_PERIOD;

        trades[tradeId] = Trade({
            tradeId: tradeId,
            securityId: securityId,
            buyer: msg.sender,
            seller: seller,
            quantity: quantity,
            price: price,
            tradeDate: block.timestamp,
            settlementDate: settlementDate,
            status: SettlementStatus.Pending,
            clearingRef: bytes32(0)
        });

        emit TradeExecuted(tradeId, securityId, msg.sender, seller, quantity, price);

        return tradeId;
    }

    /**
     * @notice Clear a trade through clearing house
     */
    function clearTrade(
        uint256 tradeId,
        bytes32 clearingRef
    ) external onlyRole(CLEARING_HOUSE_ROLE) whenNotPaused {
        Trade storage trade = trades[tradeId];
        require(trade.status == SettlementStatus.Pending, "Invalid trade status");
        require(!processedClearings[clearingRef], "Clearing already processed");

        trade.status = SettlementStatus.Cleared;
        trade.clearingRef = clearingRef;
        processedClearings[clearingRef] = true;

        ClearingHouse storage ch = clearingHouses[msg.sender];
        ch.totalTradesCleared++;
        ch.totalValueCleared += (trade.quantity * trade.price);

        emit TradeCleared(tradeId, clearingRef, msg.sender);
    }

    /**
     * @notice Settle a cleared trade (T+1)
     */
    function settleTrade(uint256 tradeId)
        external
        onlyRole(SETTLER_ROLE)
        whenNotPaused
        nonReentrant
    {
        Trade storage trade = trades[tradeId];
        require(trade.status == SettlementStatus.Cleared, "Trade not cleared");
        require(block.timestamp >= trade.settlementDate, "Settlement date not reached");

        // Transfer securities from seller to buyer
        holdings[trade.seller][trade.securityId] -= trade.quantity;
        holdings[trade.buyer][trade.securityId] += trade.quantity;

        trade.status = SettlementStatus.Settled;

        emit TradeSettled(tradeId, block.timestamp);
    }

    /**
     * @notice Register a clearing house
     */
    function registerClearingHouse(
        address clearingHouse,
        string memory name,
        string memory jurisdiction
    ) external onlyRole(ADMIN_ROLE) {
        require(clearingHouse != address(0), "Invalid address");

        clearingHouses[clearingHouse] = ClearingHouse({
            clearingHouseAddress: clearingHouse,
            name: name,
            jurisdiction: jurisdiction,
            active: true,
            totalTradesCleared: 0,
            totalValueCleared: 0
        });

        _grantRole(CLEARING_HOUSE_ROLE, clearingHouse);

        emit ClearingHouseRegistered(clearingHouse, name, jurisdiction);
    }

    /**
     * @notice Get security holdings for an address
     */
    function getHoldings(address holder, uint256 securityId)
        external
        view
        returns (uint256)
    {
        return holdings[holder][securityId];
    }

    /**
     * @notice Get trade details
     */
    function getTrade(uint256 tradeId)
        external
        view
        returns (Trade memory)
    {
        return trades[tradeId];
    }

    /**
     * @notice Get security details
     */
    function getSecurity(uint256 securityId)
        external
        view
        returns (Security memory)
    {
        return securities[securityId];
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
