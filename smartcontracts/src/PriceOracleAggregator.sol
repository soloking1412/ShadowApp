// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function decimals() external view returns (uint8);
}

contract PriceOracleAggregator is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");

    struct PriceFeed {
        address chainlinkFeed;
        uint256 lastPrice;
        uint256 lastUpdate;
        uint256 heartbeat;
        uint8 decimals;
        bool active;
    }

    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
    }

    mapping(address => PriceFeed) public assetFeeds;
    mapping(address => address[]) public backupFeeds;
    address[] public registeredAssets;

    uint256 public constant MAX_PRICE_DEVIATION = 500;
    uint256 public constant STALENESS_THRESHOLD = 3600;

    event FeedRegistered(address indexed asset, address indexed feed, uint256 heartbeat);
    event FeedUpdated(address indexed asset, uint256 price, uint256 timestamp);
    event PriceDeviationDetected(address indexed asset, uint256 primaryPrice, uint256 backupPrice);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ORACLE_MANAGER_ROLE, admin);
    }

    function registerPriceFeed(
        address asset,
        address chainlinkFeed,
        uint256 heartbeat
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(chainlinkFeed != address(0), "Invalid feed");

        uint8 decimals = AggregatorV3Interface(chainlinkFeed).decimals();

        assetFeeds[asset] = PriceFeed({
            chainlinkFeed: chainlinkFeed,
            lastPrice: 0,
            lastUpdate: 0,
            heartbeat: heartbeat,
            decimals: decimals,
            active: true
        });

        registeredAssets.push(asset);

        emit FeedRegistered(asset, chainlinkFeed, heartbeat);
    }

    function addBackupFeed(
        address asset,
        address backupFeed
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(assetFeeds[asset].active, "Asset not registered");
        backupFeeds[asset].push(backupFeed);
    }

    function getLatestPrice(address asset)
        external
        view
        returns (uint256 price, uint256 timestamp)
    {
        PriceFeed storage feed = assetFeeds[asset];
        require(feed.active, "Feed not active");

        (
            ,
            int256 answer,
            ,
            uint256 updatedAt,

        ) = AggregatorV3Interface(feed.chainlinkFeed).latestRoundData();

        require(answer > 0, "Invalid price");
        require(block.timestamp - updatedAt <= STALENESS_THRESHOLD, "Stale price");

        price = uint256(answer) * (10 ** (18 - feed.decimals));
        timestamp = updatedAt;
    }

    function getAggregatedPrice(address asset)
        external
        view
        returns (uint256 price, uint256 confidence)
    {
        PriceFeed storage feed = assetFeeds[asset];
        require(feed.active, "Feed not active");

        (uint256 primaryPrice, uint256 timestamp) = this.getLatestPrice(asset);

        if (backupFeeds[asset].length == 0) {
            return (primaryPrice, 100);
        }

        uint256 totalPrice = primaryPrice;
        uint256 validPrices = 1;

        for (uint256 i = 0; i < backupFeeds[asset].length; i++) {
            try AggregatorV3Interface(backupFeeds[asset][i]).latestRoundData() returns (
                uint80,
                int256 answer,
                uint256,
                uint256 updatedAt,
                uint80
            ) {
                if (answer > 0 && block.timestamp - updatedAt <= STALENESS_THRESHOLD) {
                    uint8 backupDecimals = AggregatorV3Interface(backupFeeds[asset][i]).decimals();
                    uint256 backupPrice = uint256(answer) * (10 ** (18 - backupDecimals));

                    totalPrice += backupPrice;
                    validPrices++;
                }
            } catch {
                continue;
            }
        }

        price = totalPrice / validPrices;
        confidence = (validPrices * 100) / (backupFeeds[asset].length + 1);
    }

    function checkPriceDeviation(address asset, uint256 targetPrice)
        external
        view
        returns (bool withinRange, uint256 deviation)
    {
        (uint256 currentPrice, ) = this.getLatestPrice(asset);

        if (currentPrice > targetPrice) {
            deviation = ((currentPrice - targetPrice) * 10000) / targetPrice;
        } else {
            deviation = ((targetPrice - currentPrice) * 10000) / targetPrice;
        }

        withinRange = deviation <= MAX_PRICE_DEVIATION;
    }

    function isPriceStale(address asset) external view returns (bool) {
        PriceFeed storage feed = assetFeeds[asset];
        if (!feed.active) return true;

        try AggregatorV3Interface(feed.chainlinkFeed).latestRoundData() returns (
            uint80,
            int256,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            return block.timestamp - updatedAt > STALENESS_THRESHOLD;
        } catch {
            return true;
        }
    }

    function getRegisteredAssets() external view returns (address[] memory) {
        return registeredAssets;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}
}
