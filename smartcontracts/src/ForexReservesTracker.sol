// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ForexReservesTracker is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct CurrencyReserve {
        string currencyCode;
        uint256 totalReserves;
        uint256 tradingVolume24h;
        uint256 lastPrice;
        uint256 priceChange24h;
        uint256 marketCap;
        uint256 lastUpdate;
    }

    struct MarketCorridor {
        string fromCurrency;
        string toCurrency;
        uint256 buyVolume;
        uint256 sellVolume;
        uint256 spread;
        uint256 liquidity;
        bool active;
        uint256 lastUpdate;
    }

    struct InvestmentOpportunity {
        uint256 opportunityId;
        string targetCurrency;
        string sourceCurrency;
        uint256 projectedReturn;
        uint256 risk;
        uint256 timeframe;
        string strategy;
        uint256 minInvestment;
        uint256 maxInvestment;
        bool active;
        uint256 createdAt;
    }

    struct Trade {
        uint256 tradeId;
        string fromCurrency;
        string toCurrency;
        uint256 amount;
        uint256 executionPrice;
        uint256 timestamp;
        address executor;
        string corridor;
    }

    struct GlobalReserveSnapshot {
        uint256 snapshotId;
        uint256 totalReservesUSD;
        uint256 timestamp;
        mapping(string => uint256) currencyReserves;
    }

    mapping(string => CurrencyReserve) public reserves;
    mapping(bytes32 => MarketCorridor) public corridors;
    mapping(uint256 => InvestmentOpportunity) public opportunities;
    mapping(uint256 => Trade) public trades;
    mapping(uint256 => GlobalReserveSnapshot) internal snapshots;

    string[] public currencies;
    bytes32[] public activeCorriors;
    uint256 public opportunityCounter;
    uint256 public tradeCounter;
    uint256 public snapshotCounter;

    uint256 public totalGlobalReservesUSD;

    event ReserveUpdated(string indexed currency, uint256 totalReserves, uint256 lastPrice);
    event CorridorUpdated(string fromCurrency, string toCurrency, uint256 buyVolume, uint256 sellVolume);
    event OpportunityCreated(uint256 indexed opportunityId, string targetCurrency, uint256 projectedReturn);
    event TradeExecuted(uint256 indexed tradeId, string fromCurrency, string toCurrency, uint256 amount);
    event SnapshotTaken(uint256 indexed snapshotId, uint256 totalReservesUSD);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ORACLE_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        _initializeCurrencies();
    }

    function _initializeCurrencies() internal {
        string[46] memory currencyList = [
            "USD", "EUR", "GBP", "JPY", "CHF", "CNY", "AUD", "CAD", "OTD",
            "RUB", "IDR", "MMK", "THB", "SGD", "EGP", "LYD", "LBP", "ILS",
            "JOD", "BAM", "SYP", "ALL", "BRL", "GEL", "DZD", "MAD", "KRW",
            "AMD", "NGN", "INR", "CLP", "ARS", "ZAR", "TND", "COP", "VES",
            "BOB", "MXN", "SAR", "QAR", "KWD", "OMR", "YER", "IQD", "IRR", "AED"
        ];

        for (uint256 i = 0; i < currencyList.length; i++) {
            string memory currency = currencyList[i];
            currencies.push(currency);

            reserves[currency] = CurrencyReserve({
                currencyCode: currency,
                totalReserves: 0,
                tradingVolume24h: 0,
                lastPrice: 1e18,
                priceChange24h: 0,
                marketCap: 0,
                lastUpdate: block.timestamp
            });
        }
    }

    function updateReserve(
        string memory currencyCode,
        uint256 totalReserves,
        uint256 tradingVolume,
        uint256 lastPrice,
        int256 priceChange,
        uint256 marketCap
    ) external onlyRole(ORACLE_ROLE) {
        CurrencyReserve storage reserve = reserves[currencyCode];

        reserve.totalReserves = totalReserves;
        reserve.tradingVolume24h = tradingVolume;
        reserve.lastPrice = lastPrice;
        reserve.priceChange24h = uint256(priceChange);
        reserve.marketCap = marketCap;
        reserve.lastUpdate = block.timestamp;

        emit ReserveUpdated(currencyCode, totalReserves, lastPrice);
    }

    function updateCorridor(
        string memory fromCurrency,
        string memory toCurrency,
        uint256 buyVolume,
        uint256 sellVolume,
        uint256 spread,
        uint256 liquidity
    ) external onlyRole(ORACLE_ROLE) {
        bytes32 corridorId = keccak256(abi.encodePacked(fromCurrency, toCurrency));

        if (!corridors[corridorId].active) {
            activeCorriors.push(corridorId);
        }

        corridors[corridorId] = MarketCorridor({
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            buyVolume: buyVolume,
            sellVolume: sellVolume,
            spread: spread,
            liquidity: liquidity,
            active: true,
            lastUpdate: block.timestamp
        });

        emit CorridorUpdated(fromCurrency, toCurrency, buyVolume, sellVolume);
    }

    function createOpportunity(
        string memory targetCurrency,
        string memory sourceCurrency,
        uint256 projectedReturn,
        uint256 risk,
        uint256 timeframe,
        string memory strategy,
        uint256 minInvestment,
        uint256 maxInvestment
    ) external onlyRole(ORACLE_ROLE) returns (uint256) {
        uint256 opportunityId = opportunityCounter++;

        opportunities[opportunityId] = InvestmentOpportunity({
            opportunityId: opportunityId,
            targetCurrency: targetCurrency,
            sourceCurrency: sourceCurrency,
            projectedReturn: projectedReturn,
            risk: risk,
            timeframe: timeframe,
            strategy: strategy,
            minInvestment: minInvestment,
            maxInvestment: maxInvestment,
            active: true,
            createdAt: block.timestamp
        });

        emit OpportunityCreated(opportunityId, targetCurrency, projectedReturn);

        return opportunityId;
    }

    function recordTrade(
        string memory fromCurrency,
        string memory toCurrency,
        uint256 amount,
        uint256 executionPrice
    ) external onlyRole(ORACLE_ROLE) returns (uint256) {
        uint256 tradeId = tradeCounter++;

        trades[tradeId] = Trade({
            tradeId: tradeId,
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            amount: amount,
            executionPrice: executionPrice,
            timestamp: block.timestamp,
            executor: msg.sender,
            corridor: string(abi.encodePacked(fromCurrency, "/", toCurrency))
        });

        emit TradeExecuted(tradeId, fromCurrency, toCurrency, amount);

        return tradeId;
    }

    function takeGlobalSnapshot() external onlyRole(ORACLE_ROLE) returns (uint256) {
        uint256 snapshotId = snapshotCounter++;

        GlobalReserveSnapshot storage snapshot = snapshots[snapshotId];
        snapshot.snapshotId = snapshotId;
        snapshot.timestamp = block.timestamp;

        uint256 totalUSD = 0;

        for (uint256 i = 0; i < currencies.length; i++) {
            string memory currency = currencies[i];
            CurrencyReserve storage reserve = reserves[currency];

            uint256 reserveValueUSD = (reserve.totalReserves * reserve.lastPrice) / 1e18;
            totalUSD += reserveValueUSD;

            snapshot.currencyReserves[currency] = reserve.totalReserves;
        }

        snapshot.totalReservesUSD = totalUSD;
        totalGlobalReservesUSD = totalUSD;

        emit SnapshotTaken(snapshotId, totalUSD);

        return snapshotId;
    }

    function getReserve(string memory currencyCode) external view returns (CurrencyReserve memory) {
        return reserves[currencyCode];
    }

    function getCorridor(string memory fromCurrency, string memory toCurrency)
        external
        view
        returns (MarketCorridor memory)
    {
        bytes32 corridorId = keccak256(abi.encodePacked(fromCurrency, toCurrency));
        return corridors[corridorId];
    }

    function getOpportunity(uint256 opportunityId)
        external
        view
        returns (InvestmentOpportunity memory)
    {
        return opportunities[opportunityId];
    }

    function getAllCurrencies() external view returns (string[] memory) {
        return currencies;
    }

    function getActiveOpportunities() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < opportunityCounter; i++) {
            if (opportunities[i].active) {
                count++;
            }
        }

        uint256[] memory activeIds = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < opportunityCounter; i++) {
            if (opportunities[i].active) {
                activeIds[index] = i;
                index++;
            }
        }

        return activeIds;
    }

    function getSnapshotCurrencyReserve(uint256 snapshotId, string memory currency)
        external
        view
        returns (uint256)
    {
        return snapshots[snapshotId].currencyReserves[currency];
    }

    function deactivateOpportunity(uint256 opportunityId) external onlyRole(ORACLE_ROLE) {
        opportunities[opportunityId].active = false;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
