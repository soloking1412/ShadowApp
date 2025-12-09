// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title OICDPriceOracle - COMPLETE PRODUCTION VERSION
 * @notice Multi-source price aggregation with staleness checks and outlier detection
 */
contract OICDPriceOracle is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    enum AssetType {
        Currency,
        Equity,
        Bond,
        Commodity,
        Crypto,
        RealEstate
    }
    
    struct PriceFeed {
        address feedAddress;
        uint256 weight;
        uint256 lastUpdate;
        bool active;
        string source;
    }
    
    struct Price {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        uint256 volume24h;
    }
    
    struct Asset {
        string symbol;
        AssetType assetType;
        uint256 decimals;
        bool active;
        uint256 stalenessThreshold;
        uint256 deviationThreshold;
    }
    
    mapping(address => Asset) public assets;
    mapping(address => PriceFeed[]) public priceFeeds;
    mapping(address => Price) public latestPrices;
    mapping(address => Price[]) public priceHistory;
    
    address[] public assetList;
    
    uint256 public defaultStalenessThreshold;
    uint256 public defaultDeviationThreshold;
    uint256 public minOracleSources;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant CONFIDENCE_DENOMINATOR = 100;
    
    event AssetRegistered(address indexed asset, string symbol, AssetType assetType);
    event PriceFeedAdded(address indexed asset, address indexed feed, uint256 weight);
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);
    event StalePrice(address indexed asset, uint256 lastUpdate);
    event PriceDeviation(address indexed asset, uint256 price, uint256 median);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address admin,
        uint256 _stalenessThreshold,
        uint256 _deviationThreshold,
        uint256 _minSources
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ORACLE_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        defaultStalenessThreshold = _stalenessThreshold;
        defaultDeviationThreshold = _deviationThreshold;
        minOracleSources = _minSources;
    }
    
    function registerAsset(
        address asset,
        string memory symbol,
        AssetType assetType,
        uint256 decimals,
        uint256 stalenessThreshold,
        uint256 deviationThreshold
    ) external onlyRole(ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(!assets[asset].active, "Already registered");
        
        assets[asset] = Asset({
            symbol: symbol,
            assetType: assetType,
            decimals: decimals,
            active: true,
            stalenessThreshold: stalenessThreshold > 0 ? stalenessThreshold : defaultStalenessThreshold,
            deviationThreshold: deviationThreshold > 0 ? deviationThreshold : defaultDeviationThreshold
        });
        
        assetList.push(asset);
        
        emit AssetRegistered(asset, symbol, assetType);
    }
    
    function addPriceFeed(
        address asset,
        address feedAddress,
        uint256 weight,
        string memory source
    ) external onlyRole(ADMIN_ROLE) {
        require(assets[asset].active, "Asset not registered");
        require(feedAddress != address(0), "Invalid feed");
        require(weight > 0 && weight <= 100, "Invalid weight");
        
        priceFeeds[asset].push(PriceFeed({
            feedAddress: feedAddress,
            weight: weight,
            lastUpdate: 0,
            active: true,
            source: source
        }));
        
        emit PriceFeedAdded(asset, feedAddress, weight);
    }
    
    function updatePrice(
        address asset,
        uint256 price,
        uint256 confidence,
        uint256 volume24h
    ) external onlyRole(ORACLE_ROLE) whenNotPaused {
        require(assets[asset].active, "Asset not registered");
        require(price > 0, "Invalid price");
        require(confidence <= CONFIDENCE_DENOMINATOR, "Invalid confidence");
        
        // Update price feed
        bool feedFound = false;
        PriceFeed[] storage feeds = priceFeeds[asset];
        
        for (uint256 i = 0; i < feeds.length; i++) {
            if (feeds[i].feedAddress == msg.sender && feeds[i].active) {
                feeds[i].lastUpdate = block.timestamp;
                feedFound = true;
                break;
            }
        }
        
        require(feedFound, "Feed not found");
        
        // Calculate aggregated price
        uint256 aggregatedPrice = _aggregatePrice(asset);
        
        // Check deviation
        if (latestPrices[asset].price > 0) {
            _checkDeviation(asset, aggregatedPrice);
        }
        
        // Update latest price
        latestPrices[asset] = Price({
            price: aggregatedPrice,
            timestamp: block.timestamp,
            confidence: confidence,
            volume24h: volume24h
        });
        
        // Store in history
        priceHistory[asset].push(latestPrices[asset]);
        
        // Keep only last 100 prices
        if (priceHistory[asset].length > 100) {
            _removeOldestPrice(asset);
        }
        
        emit PriceUpdated(asset, aggregatedPrice, block.timestamp);
    }
    
    function _aggregatePrice(address asset) internal view returns (uint256) {
        PriceFeed[] storage feeds = priceFeeds[asset];
        require(feeds.length >= minOracleSources, "Insufficient price sources");
        
        uint256[] memory prices = new uint256[](feeds.length);
        uint256[] memory weights = new uint256[](feeds.length);
        uint256 validFeeds = 0;
        uint256 totalWeight = 0;
        
        // Collect prices from active feeds
        for (uint256 i = 0; i < feeds.length; i++) {
            if (feeds[i].active && !_isStale(asset, feeds[i].lastUpdate)) {
                try IExternalOracle(feeds[i].feedAddress).getPrice(asset) returns (uint256 price) {
                    if (price > 0) {
                        prices[validFeeds] = price;
                        weights[validFeeds] = feeds[i].weight;
                        totalWeight += feeds[i].weight;
                        validFeeds++;
                    }
                } catch {
                    // Skip failed feeds
                }
            }
        }
        
        require(validFeeds >= minOracleSources, "Insufficient valid feeds");
        
        // Calculate weighted average
        uint256 weightedSum = 0;
        for (uint256 i = 0; i < validFeeds; i++) {
            weightedSum += prices[i] * weights[i];
        }
        
        return weightedSum / totalWeight;
    }
    
    function _isStale(address asset, uint256 lastUpdate) internal view returns (bool) {
        uint256 threshold = assets[asset].stalenessThreshold;
        return block.timestamp - lastUpdate > threshold;
    }
    
    function _checkDeviation(address asset, uint256 newPrice) internal {
        uint256 oldPrice = latestPrices[asset].price;
        uint256 deviation;
        
        if (newPrice > oldPrice) {
            deviation = ((newPrice - oldPrice) * BASIS_POINTS) / oldPrice;
        } else {
            deviation = ((oldPrice - newPrice) * BASIS_POINTS) / oldPrice;
        }
        
        uint256 threshold = assets[asset].deviationThreshold;
        
        if (deviation > threshold) {
            emit PriceDeviation(asset, newPrice, oldPrice);
        }
    }
    
    function _removeOldestPrice(address asset) internal {
        Price[] storage history = priceHistory[asset];
        
        // Shift all elements left
        for (uint256 i = 0; i < history.length - 1; i++) {
            history[i] = history[i + 1];
        }
        history.pop();
    }
    
    function getPrice(address asset) external view returns (uint256, uint256) {
        require(assets[asset].active, "Asset not registered");
        
        Price memory price = latestPrices[asset];
        require(price.price > 0, "Price not available");
        require(!_isStale(asset, price.timestamp), "Price is stale");
        
        return (price.price, price.timestamp);
    }
    
    function getPriceWithConfidence(address asset) 
        external 
        view 
        returns (uint256 price, uint256 timestamp, uint256 confidence) 
    {
        require(assets[asset].active, "Asset not registered");
        
        Price memory p = latestPrices[asset];
        require(p.price > 0, "Price not available");
        
        return (p.price, p.timestamp, p.confidence);
    }
    
    function getTWAP(address asset, uint256 period) 
        external 
        view 
        returns (uint256) 
    {
        require(assets[asset].active, "Asset not registered");
        
        Price[] storage history = priceHistory[asset];
        require(history.length > 0, "No price history");
        
        uint256 cutoff = block.timestamp - period;
        uint256 sum = 0;
        uint256 count = 0;
        
        // Calculate average from recent history
        for (uint256 i = history.length; i > 0; i--) {
            if (history[i - 1].timestamp < cutoff) break;
            
            sum += history[i - 1].price;
            count++;
        }
        
        require(count > 0, "Insufficient history");
        
        return sum / count;
    }
    
    function getVolatility(address asset, uint256 period) 
        external 
        view 
        returns (uint256) 
    {
        require(assets[asset].active, "Asset not registered");
        
        Price[] storage history = priceHistory[asset];
        require(history.length >= 2, "Insufficient history");
        
        uint256 cutoff = block.timestamp - period;
        
        // Calculate standard deviation
        uint256 sum = 0;
        uint256 count = 0;
        
        for (uint256 i = history.length; i > 0; i--) {
            if (history[i - 1].timestamp < cutoff) break;
            sum += history[i - 1].price;
            count++;
        }
        
        require(count >= 2, "Insufficient data points");
        
        uint256 mean = sum / count;
        uint256 variance = 0;
        
        for (uint256 i = history.length; i > 0 && count > 0; i--) {
            if (history[i - 1].timestamp < cutoff) break;
            
            uint256 price = history[i - 1].price;
            uint256 diff = price > mean ? price - mean : mean - price;
            variance += diff * diff;
        }
        
        return _sqrt(variance / count);
    }
    
    function batchGetPrices(address[] memory assetAddresses) 
        external 
        view 
        returns (uint256[] memory prices, uint256[] memory timestamps) 
    {
        prices = new uint256[](assetAddresses.length);
        timestamps = new uint256[](assetAddresses.length);
        
        for (uint256 i = 0; i < assetAddresses.length; i++) {
            Price memory price = latestPrices[assetAddresses[i]];
            prices[i] = price.price;
            timestamps[i] = price.timestamp;
        }
        
        return (prices, timestamps);
    }
    
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
    
    function deactivateFeed(address asset, address feedAddress) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        PriceFeed[] storage feeds = priceFeeds[asset];
        
        for (uint256 i = 0; i < feeds.length; i++) {
            if (feeds[i].feedAddress == feedAddress) {
                feeds[i].active = false;
                break;
            }
        }
    }
    
    function updateFeedWeight(address asset, address feedAddress, uint256 newWeight) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(newWeight > 0 && newWeight <= 100, "Invalid weight");
        
        PriceFeed[] storage feeds = priceFeeds[asset];
        
        for (uint256 i = 0; i < feeds.length; i++) {
            if (feeds[i].feedAddress == feedAddress) {
                feeds[i].weight = newWeight;
                break;
            }
        }
    }
    
    function setDefaultStalenessThreshold(uint256 threshold) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        defaultStalenessThreshold = threshold;
    }
    
    function setDefaultDeviationThreshold(uint256 threshold) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(threshold <= BASIS_POINTS, "Invalid threshold");
        defaultDeviationThreshold = threshold;
    }
    
    function setMinOracleSources(uint256 min) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(min > 0, "Invalid minimum");
        minOracleSources = min;
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getAsset(address asset) 
        external 
        view 
        returns (Asset memory) 
    {
        return assets[asset];
    }
    
    function getPriceFeeds(address asset) 
        external 
        view 
        returns (PriceFeed[] memory) 
    {
        return priceFeeds[asset];
    }
    
    function getPriceHistory(address asset) 
        external 
        view 
        returns (Price[] memory) 
    {
        return priceHistory[asset];
    }
    
    function getAllAssets() 
        external 
        view 
        returns (address[] memory) 
    {
        return assetList;
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}

interface IExternalOracle {
    function getPrice(address asset) external view returns (uint256);
}