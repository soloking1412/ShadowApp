// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title DigitalTradeExchange (DTX)
 * @notice 5-center global bourse for listing and trading company shares on the OICD network.
 *         Alpha: Puerto Rico | Bravo: Colombia | Charlie: Ghana
 *         Delta: Sri Lanka   | Echo: Indonesia
 * @dev UUPS upgradeable proxy.
 */
contract DigitalTradeExchange is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // ─────────────────────────────────────────────
    //  Data Structures
    // ─────────────────────────────────────────────

    enum Center { Alpha, Bravo, Charlie, Delta, Echo }

    struct ExchangeCenter {
        string  name;
        string  location;
        string  country;
        string  region;
        bool    active;
        uint256 totalListings;
    }

    struct Company {
        string  name;
        string  ticker;         // e.g. "ACME"
        string  sector;         // e.g. "Technology", "Agriculture"
        Center  center;
        address registrant;
        uint256 sharesTotal;    // total authorized shares (token units)
        uint256 priceOICD;      // last traded price in OICD (18 decimals)
        bool    listed;
        uint256 listedAt;       // block timestamp
        uint256 marketCap;      // sharesTotal * priceOICD / 1e18
    }

    struct TradeRecord {
        uint256 companyId;
        address buyer;
        address seller;
        uint256 shares;
        uint256 priceOICD;
        uint256 timestamp;
    }

    // ─────────────────────────────────────────────
    //  State
    // ─────────────────────────────────────────────

    ExchangeCenter[5] public centers;
    Company[]         public companies;
    TradeRecord[]     public tradeHistory;

    // companyId → authorized traders (KYC cleared)
    mapping(uint256 => mapping(address => bool)) public authorizedTraders;

    // center → list of companyIds
    mapping(uint256 => uint256[]) private _centerListings;

    // ticker → companyId+1 (0 = not found)
    mapping(string => uint256) private _tickerIndex;

    uint256 public listingFeeOICD;  // fee in OICD wei to list
    uint256 public tradingFeesBps;  // basis points (e.g. 9 = 0.09%)

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────

    event CompanyListed(uint256 indexed id, string ticker, Center center, address registrant);
    event CompanyDelisted(uint256 indexed id, string ticker);
    event TradeExecuted(uint256 indexed companyId, address buyer, address seller, uint256 shares, uint256 priceOICD);
    event PriceUpdated(uint256 indexed companyId, uint256 oldPrice, uint256 newPrice);
    event CenterStatusChanged(Center center, bool active);
    event TraderAuthorized(uint256 indexed companyId, address trader);

    // ─────────────────────────────────────────────
    //  Initializer
    // ─────────────────────────────────────────────

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        // Seed the 5 exchange centers
        centers[uint256(Center.Alpha)]   = ExchangeCenter("Alpha Exchange",   "San Juan",      "Puerto Rico", "Americas",       true, 0);
        centers[uint256(Center.Bravo)]   = ExchangeCenter("Bravo Exchange",   "Bogota",        "Colombia",    "Americas",       true, 0);
        centers[uint256(Center.Charlie)] = ExchangeCenter("Charlie Exchange", "Accra",         "Ghana",       "Africa",         true, 0);
        centers[uint256(Center.Delta)]   = ExchangeCenter("Delta Exchange",   "Colombo",       "Sri Lanka",   "Asia Pacific",   true, 0);
        centers[uint256(Center.Echo)]    = ExchangeCenter("Echo Exchange",    "Jakarta",       "Indonesia",   "Asia Pacific",   true, 0);

        listingFeeOICD = 10_000 * 1e18;  // 10,000 OICD
        tradingFeesBps = 9;               // 0.09%
    }

    // ─────────────────────────────────────────────
    //  Listing
    // ─────────────────────────────────────────────

    /**
     * @notice List a company on one of the 5 DTX exchange centers.
     * @param _name         Full company name
     * @param _ticker       Unique ticker symbol (uppercase, 2-5 chars)
     * @param _sector       Industry sector
     * @param _center       Exchange center (0=Alpha .. 4=Echo)
     * @param _sharesTotal  Total authorized shares
     * @param _initialPrice Initial price per share in OICD wei
     */
    function listCompany(
        string calldata _name,
        string calldata _ticker,
        string calldata _sector,
        Center  _center,
        uint256 _sharesTotal,
        uint256 _initialPrice
    ) external returns (uint256 companyId) {
        require(_tickerIndex[_ticker] == 0, "DTX: ticker already listed");
        require(centers[uint256(_center)].active, "DTX: center inactive");
        require(_sharesTotal > 0, "DTX: zero shares");
        require(bytes(_ticker).length >= 2 && bytes(_ticker).length <= 5, "DTX: invalid ticker length");

        companyId = companies.length;
        companies.push(Company({
            name:       _name,
            ticker:     _ticker,
            sector:     _sector,
            center:     _center,
            registrant: msg.sender,
            sharesTotal: _sharesTotal,
            priceOICD:  _initialPrice,
            listed:     true,
            listedAt:   block.timestamp,
            marketCap:  (_sharesTotal * _initialPrice) / 1e18
        }));

        _tickerIndex[_ticker] = companyId + 1;
        _centerListings[uint256(_center)].push(companyId);
        centers[uint256(_center)].totalListings++;

        // Registrant is auto-authorized
        authorizedTraders[companyId][msg.sender] = true;

        emit CompanyListed(companyId, _ticker, _center, msg.sender);
    }

    /**
     * @notice Delist a company. Only registrant or owner may delist.
     */
    function delistCompany(uint256 _companyId) external {
        Company storage c = companies[_companyId];
        require(c.listed, "DTX: not listed");
        require(msg.sender == c.registrant || msg.sender == owner(), "DTX: unauthorized");
        c.listed = false;
        centers[uint256(c.center)].totalListings--;
        emit CompanyDelisted(_companyId, c.ticker);
    }

    // ─────────────────────────────────────────────
    //  Trading
    // ─────────────────────────────────────────────

    /**
     * @notice Record an OTC trade between two parties.
     *         Both buyer and seller must be authorized traders for this company.
     */
    function executeTrade(
        uint256 _companyId,
        address _seller,
        uint256 _shares,
        uint256 _priceOICD
    ) external {
        Company storage c = companies[_companyId];
        require(c.listed, "DTX: company not listed");
        require(authorizedTraders[_companyId][msg.sender], "DTX: buyer not authorized");
        require(authorizedTraders[_companyId][_seller],    "DTX: seller not authorized");
        require(_shares > 0, "DTX: zero shares");

        // Update last price & market cap
        uint256 oldPrice = c.priceOICD;
        c.priceOICD = _priceOICD;
        c.marketCap = (c.sharesTotal * _priceOICD) / 1e18;

        tradeHistory.push(TradeRecord({
            companyId:  _companyId,
            buyer:      msg.sender,
            seller:     _seller,
            shares:     _shares,
            priceOICD:  _priceOICD,
            timestamp:  block.timestamp
        }));

        emit PriceUpdated(_companyId, oldPrice, _priceOICD);
        emit TradeExecuted(_companyId, msg.sender, _seller, _shares, _priceOICD);
    }

    /**
     * @notice Update the last-trade price for a company (owner/oracle only).
     */
    function updatePrice(uint256 _companyId, uint256 _newPrice) external onlyOwner {
        Company storage c = companies[_companyId];
        require(c.listed, "DTX: company not listed");
        uint256 old = c.priceOICD;
        c.priceOICD = _newPrice;
        c.marketCap = (c.sharesTotal * _newPrice) / 1e18;
        emit PriceUpdated(_companyId, old, _newPrice);
    }

    // ─────────────────────────────────────────────
    //  Authorization
    // ─────────────────────────────────────────────

    function authorizeTrader(uint256 _companyId, address _trader) external {
        require(
            msg.sender == companies[_companyId].registrant || msg.sender == owner(),
            "DTX: unauthorized"
        );
        authorizedTraders[_companyId][_trader] = true;
        emit TraderAuthorized(_companyId, _trader);
    }

    // ─────────────────────────────────────────────
    //  Admin
    // ─────────────────────────────────────────────

    function setCenterActive(Center _center, bool _active) external onlyOwner {
        centers[uint256(_center)].active = _active;
        emit CenterStatusChanged(_center, _active);
    }

    function setListingFee(uint256 _feeOICD) external onlyOwner { listingFeeOICD = _feeOICD; }
    function setTradingFee(uint256 _bps)     external onlyOwner { tradingFeesBps = _bps; }

    // ─────────────────────────────────────────────
    //  View Helpers
    // ─────────────────────────────────────────────

    function companyCount() external view returns (uint256) { return companies.length; }
    function tradeCount()   external view returns (uint256) { return tradeHistory.length; }

    function getCenterListings(uint256 _centerId) external view returns (uint256[] memory) {
        return _centerListings[_centerId];
    }

    function getCompany(uint256 _id) external view returns (Company memory) {
        return companies[_id];
    }

    function getCompanyByTicker(string calldata _ticker) external view returns (Company memory, uint256 id) {
        uint256 idx = _tickerIndex[_ticker];
        require(idx > 0, "DTX: ticker not found");
        id = idx - 1;
        return (companies[id], id);
    }

    function getAllCenters() external view returns (ExchangeCenter[5] memory) {
        return centers;
    }

    function getRecentTrades(uint256 _count) external view returns (TradeRecord[] memory) {
        uint256 len = tradeHistory.length;
        uint256 n = _count > len ? len : _count;
        TradeRecord[] memory result = new TradeRecord[](n);
        for (uint256 i = 0; i < n; i++) {
            result[i] = tradeHistory[len - n + i];
        }
        return result;
    }

    // ─────────────────────────────────────────────
    //  UUPS
    // ─────────────────────────────────────────────

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
