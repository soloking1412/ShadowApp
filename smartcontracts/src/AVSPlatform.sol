// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title AVSPlatform — Asset Value Securitization Platform
/// @notice Digitalizes and securitizes real-world assets from emerging markets.
///         Assets are priced in OICD and sold to international buyers.
///         60/40 revenue split: 60% to host country, 40% to Obsidian/SGM.
contract AVSPlatform is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    enum AssetType {
        NaturalResource,  // 0 oil, gas, timber
        Energy,           // 1 renewable farms, pipelines, grids
        Metal,            // 2 gold, copper, iron
        Mineral,          // 3 diamonds, bauxite, manganese
        Agribusiness,     // 4 grains, livestock
        Commodity,        // 5 generic commodity
        Transport,        // 6 logistics, shipping assets
        RealEstate,       // 7 commercial real estate, REITs
        Patent,           // 8 IP, trade secrets
        Technology        // 9 AI, quantum, blockchain, green tech
    }

    enum AssetStatus { Listed, Active, Paused, Sold, Delisted }

    enum InstrumentType { Spot, Futures, Derivatives, Options, Bond, REIT, DigitalStock }

    struct Asset {
        uint256 assetId;
        string  country;
        string  countryCode;   // ISO-2
        AssetType assetType;
        InstrumentType instrument;
        string  name;
        string  description;
        uint256 totalValueOICD;    // 1e18 scaled
        uint256 availableSupply;   // units
        uint256 pricePerUnit;      // OICD per unit, 1e18
        uint256 countryDebtOICD;   // sovereign debt backed against
        uint256 multiplier;        // 1e2 scaled: 150 = 1.5x, 450 = 4.5x
        address listedBy;
        uint256 listedAt;
        AssetStatus status;
        uint256 unitsSold;
        uint256 revenueOICD;
    }

    struct Purchase {
        uint256 purchaseId;
        uint256 assetId;
        address buyer;
        uint256 units;
        uint256 priceOICD;
        uint256 timestamp;
        bool settled;
    }

    struct CountryProfile {
        string  name;
        string  code;
        uint256 totalDebtUSD;      // in USD millions
        uint256 allocationOICD;    // total OICD allocated
        uint256 revenueShare;      // 60 = 60%
        bool    active;
        uint256 assetCount;
        uint256 totalValueSecuritized;
    }

    // -- Storage --
    uint256 public assetCounter;
    uint256 public purchaseCounter;
    uint256 public totalAssetsListed;
    uint256 public totalValueSecuritized;
    uint256 public totalRevenue;

    // Revenue split: Obsidian takes 40%, country gets 60%
    uint256 public constant OBSIDIAN_SHARE = 40;
    uint256 public constant COUNTRY_SHARE  = 60;

    mapping(uint256 => Asset) public assets;
    mapping(uint256 => Purchase) public purchases;
    mapping(string => CountryProfile) public countries;    // countryCode => profile
    mapping(address => uint256[]) public buyerPurchases;
    mapping(address => bool) public authorizedListers;
    mapping(string => uint256[]) public assetsByCountry;  // countryCode => assetIds
    mapping(AssetType => uint256[]) public assetsByType;

    // High-inflation emerging market targets (from Obsidian Capital doc)
    string[] public targetMarkets;

    // -- Events --
    event AssetListed(uint256 indexed assetId, string countryCode, AssetType assetType, uint256 valueOICD);
    event AssetPurchased(uint256 indexed purchaseId, uint256 indexed assetId, address buyer, uint256 units);
    event CountryRegistered(string countryCode, string name, uint256 debtUSD);
    event AllocationIssued(string countryCode, uint256 amountOICD, uint256 multiplier);
    event AssetStatusUpdated(uint256 indexed assetId, AssetStatus status);
    event ListerAuthorized(address lister, bool status);

    modifier onlyLister() {
        require(authorizedListers[msg.sender] || msg.sender == owner(), "Not authorized lister");
        _;
    }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        // Seed high-inflation emerging market targets from Obsidian Capital doc
        targetMarkets.push("LK"); // Sri Lanka 6.25%
        targetMarkets.push("PS"); // Palestine
        targetMarkets.push("VE"); // Venezuela 1,575%
        targetMarkets.push("SD"); // Sudan 366%
        targetMarkets.push("ZW"); // Zimbabwe 54.59%
        targetMarkets.push("AR"); // Argentina 52.1%
        targetMarkets.push("IR"); // Iran 39.2%
        targetMarkets.push("ET"); // Ethiopia 34.2%
        targetMarkets.push("AO"); // Angola 26.57%
        targetMarkets.push("YE"); // Yemen 30.61%
        targetMarkets.push("LY"); // Libya 21.1%
        targetMarkets.push("TR"); // Turkey 19.9%
        targetMarkets.push("NG"); // Nigeria 15.99%
        targetMarkets.push("GH"); // Ghana
        targetMarkets.push("BR"); // Brazil 10.7%
    }

    // -- Country Management --

    function registerCountry(
        string calldata code,
        string calldata name,
        uint256 totalDebtUSDMillions
    ) external onlyOwner {
        require(bytes(code).length == 2, "Use ISO-2 code");
        countries[code] = CountryProfile({
            name: name,
            code: code,
            totalDebtUSD: totalDebtUSDMillions,
            allocationOICD: 0,
            revenueShare: COUNTRY_SHARE,
            active: true,
            assetCount: 0,
            totalValueSecuritized: 0
        });
        emit CountryRegistered(code, name, totalDebtUSDMillions);
    }

    /// @notice Issue OICD allocation to country at 1.5x-4.5x multiplier on sovereign debt
    function issueAllocation(
        string calldata countryCode,
        uint256 multiplierBps // 150 = 1.5x, 450 = 4.5x
    ) external onlyOwner {
        require(multiplierBps >= 150 && multiplierBps <= 450, "Multiplier 1.5x-4.5x");
        CountryProfile storage c = countries[countryCode];
        require(c.active, "Country not registered");
        uint256 allocation = (c.totalDebtUSD * multiplierBps * 1e18) / 100;
        c.allocationOICD += allocation;
        emit AllocationIssued(countryCode, allocation, multiplierBps);
    }

    // -- Asset Management --

    function authorizeLister(address lister, bool status) external onlyOwner {
        authorizedListers[lister] = status;
        emit ListerAuthorized(lister, status);
    }

    function listAsset(
        string calldata countryCode,
        AssetType assetType,
        InstrumentType instrument,
        string calldata name,
        string calldata description,
        uint256 totalValueOICD,
        uint256 supply,
        uint256 pricePerUnit,
        uint256 countryDebtOICD,
        uint256 multiplierBps
    ) external onlyLister returns (uint256 assetId) {
        require(totalValueOICD > 0 && supply > 0 && pricePerUnit > 0, "Invalid params");

        assetId = ++assetCounter;
        assets[assetId] = Asset({
            assetId: assetId,
            country: countries[countryCode].name,
            countryCode: countryCode,
            assetType: assetType,
            instrument: instrument,
            name: name,
            description: description,
            totalValueOICD: totalValueOICD,
            availableSupply: supply,
            pricePerUnit: pricePerUnit,
            countryDebtOICD: countryDebtOICD,
            multiplier: multiplierBps,
            listedBy: msg.sender,
            listedAt: block.timestamp,
            status: AssetStatus.Active,
            unitsSold: 0,
            revenueOICD: 0
        });

        assetsByCountry[countryCode].push(assetId);
        assetsByType[assetType].push(assetId);
        totalAssetsListed++;
        totalValueSecuritized += totalValueOICD;

        CountryProfile storage c = countries[countryCode];
        c.assetCount++;
        c.totalValueSecuritized += totalValueOICD;

        emit AssetListed(assetId, countryCode, assetType, totalValueOICD);
    }

    function purchaseAsset(uint256 assetId, uint256 units) external nonReentrant returns (uint256 purchaseId) {
        Asset storage a = assets[assetId];
        require(a.status == AssetStatus.Active, "Asset not active");
        require(units > 0 && units <= a.availableSupply, "Invalid units");

        uint256 cost = units * a.pricePerUnit;
        purchaseId = ++purchaseCounter;

        purchases[purchaseId] = Purchase({
            purchaseId: purchaseId,
            assetId: assetId,
            buyer: msg.sender,
            units: units,
            priceOICD: cost,
            timestamp: block.timestamp,
            settled: true
        });

        a.availableSupply -= units;
        a.unitsSold += units;
        a.revenueOICD += cost;
        totalRevenue += cost;

        if (a.availableSupply == 0) {
            a.status = AssetStatus.Sold;
        }

        buyerPurchases[msg.sender].push(purchaseId);
        emit AssetPurchased(purchaseId, assetId, msg.sender, units);
    }

    function updateAssetStatus(uint256 assetId, AssetStatus status) external onlyOwner {
        assets[assetId].status = status;
        emit AssetStatusUpdated(assetId, status);
    }

    function updateAssetPrice(uint256 assetId, uint256 newPricePerUnit) external onlyOwner {
        require(newPricePerUnit > 0, "Invalid price");
        assets[assetId].pricePerUnit = newPricePerUnit;
    }

    // -- Views --

    function getAsset(uint256 assetId) external view returns (Asset memory) {
        return assets[assetId];
    }

    function getAssetsByCountry(string calldata countryCode) external view returns (uint256[] memory) {
        return assetsByCountry[countryCode];
    }

    function getAssetsByType(AssetType assetType) external view returns (uint256[] memory) {
        return assetsByType[assetType];
    }

    function getPurchase(uint256 purchaseId) external view returns (Purchase memory) {
        return purchases[purchaseId];
    }

    function getBuyerPurchases(address buyer) external view returns (uint256[] memory) {
        return buyerPurchases[buyer];
    }

    function getCountryProfile(string calldata code) external view returns (CountryProfile memory) {
        return countries[code];
    }

    function getTargetMarkets() external view returns (string[] memory) {
        return targetMarkets;
    }

    function getCountryRevenueSplit(string calldata code) external view
        returns (uint256 countryShare, uint256 obsidianShare)
    {
        CountryProfile memory c = countries[code];
        countryShare  = (c.totalValueSecuritized * COUNTRY_SHARE) / 100;
        obsidianShare = (c.totalValueSecuritized * OBSIDIAN_SHARE) / 100;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
