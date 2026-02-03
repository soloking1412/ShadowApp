// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title InfrastructureAssets
 * @notice Manage ports, airports, railways, and freight corridors
 * @dev Covers import/export infrastructure, RIN integration, freight tracking
 */
contract InfrastructureAssets is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant CUSTOMS_ROLE = keccak256("CUSTOMS_ROLE");

    enum AssetType {
        Seaport,
        Airport,
        Railway,
        RoadCorridor,
        DryPort,
        LogisticsHub
    }

    enum FreightType {
        Container,
        Bulk,
        BreakBulk,
        Liquid,
        Air,
        Rail,
        Road
    }

    enum AssetStatus {
        Active,
        Maintenance,
        Inactive,
        UnderConstruction
    }

    struct InfrastructureAsset {
        uint256 assetId;
        AssetType assetType;
        string name;
        string code; // UNLOCODE for ports, IATA for airports, etc.
        string country;
        string city;
        string coordinates; // Lat,Long
        uint256 capacity; // Annual capacity
        uint256 currentUtilization;
        AssetStatus status;
        address operator;
        uint256 operationalSince;
        string[] connectedCorridors; // Market corridors
        bool sezEnabled; // Special Economic Zone
    }

    struct FreightCorridor {
        uint256 corridorId;
        string name;
        string originCode;
        string destinationCode;
        uint256[] transitAssets; // Asset IDs in the route
        FreightType[] supportedTypes;
        uint256 distance; // in km
        uint256 averageTransitTime; // in hours
        uint256 totalVolume; // Total freight volume
        bool active;
    }

    struct FreightMovement {
        uint256 movementId;
        uint256 corridorId;
        string rin; // Route Identification Number
        address shipper;
        string origin;
        string destination;
        FreightType freightType;
        uint256 volume; // in TEU or tons
        uint256 value;
        uint256 departureTime;
        uint256 estimatedArrival;
        uint256 actualArrival;
        string[] checkpoints;
        uint256 currentCheckpoint;
        bool completed;
    }

    struct PortOperations {
        uint256 assetId;
        uint256 vesselsCurrent;
        uint256 vesselsAnnual;
        uint256 containersTEU;
        uint256 bulkTonnage;
        uint256 revenue;
    }

    struct PortInvestment {
        uint256 assetId;
        address investor;
        uint256 shares;
        uint256 investedAmount;
        uint256 investmentDate;
        uint256 lastClaimDate;
        uint256 totalClaimed;
    }

    struct PortFinancials {
        uint256 totalRevenue;
        uint256 operatingCosts;
        uint256 netProfit;
        uint256 totalShares;
        uint256 pricePerShare;
        uint256 lastDividendDate;
        uint256 dividendPerShare;
    }

    struct CorridorFinancials {
        uint256 totalFreightValue;
        uint256 totalFees;
        uint256 investorPool;
    }

    // State variables
    mapping(uint256 => InfrastructureAsset) public assets;
    mapping(uint256 => FreightCorridor) public corridors;
    mapping(uint256 => FreightMovement) public movements;
    mapping(string => uint256) public codeToAssetId;
    mapping(string => uint256) public rinToMovementId;
    mapping(uint256 => PortOperations) public operations;
    mapping(uint256 => PortFinancials) public portFinancials;
    mapping(uint256 => mapping(address => PortInvestment)) public portInvestments;
    mapping(uint256 => address[]) public portInvestors;
    mapping(uint256 => CorridorFinancials) public corridorFinancials;
    mapping(uint256 => mapping(address => uint256)) public corridorInvestorShares;
    mapping(uint256 => address[]) public corridorInvestors;

    uint256 public assetCounter;
    uint256 public corridorCounter;
    uint256 public movementCounter;
    uint256 public totalFreightVolume;
    uint256 public totalFreightValue;
    uint256 public constant CORRIDOR_FEE_BASIS_POINTS = 100;

    // Events
    event AssetRegistered(
        uint256 indexed assetId,
        AssetType assetType,
        string name,
        string code
    );

    event CorridorEstablished(
        uint256 indexed corridorId,
        string name,
        string originCode,
        string destinationCode
    );

    event FreightDispatched(
        uint256 indexed movementId,
        string indexed rin,
        address indexed shipper,
        uint256 corridorId
    );

    event CheckpointReached(
        uint256 indexed movementId,
        string checkpoint,
        uint256 timestamp
    );

    event FreightCompleted(
        uint256 indexed movementId,
        uint256 actualArrival
    );

    event PortInvestmentMade(uint256 indexed assetId, address indexed investor, uint256 amount, uint256 shares);
    event PortRevenueRecorded(uint256 indexed assetId, uint256 revenue, uint256 costs);
    event DividendDistributed(uint256 indexed assetId, uint256 totalDividend);
    event DividendClaimed(uint256 indexed assetId, address indexed investor, uint256 amount);
    event CorridorInvestmentMade(uint256 indexed corridorId, address indexed investor, uint256 amount);
    event CorridorFeeCollected(uint256 indexed corridorId, uint256 fee, string rin);
    event CorridorProfitDistributed(uint256 indexed corridorId, uint256 amount);

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
        _grantRole(OPERATOR_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    /**
     * @notice Register infrastructure asset
     */
    function registerAsset(
        AssetType assetType,
        string memory name,
        string memory code,
        string memory country,
        string memory city,
        string memory coordinates,
        uint256 capacity,
        string[] memory connectedCorridors,
        bool sezEnabled
    ) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(bytes(code).length > 0, "Invalid code");
        require(codeToAssetId[code] == 0, "Code already exists");

        uint256 assetId = ++assetCounter;

        assets[assetId] = InfrastructureAsset({
            assetId: assetId,
            assetType: assetType,
            name: name,
            code: code,
            country: country,
            city: city,
            coordinates: coordinates,
            capacity: capacity,
            currentUtilization: 0,
            status: AssetStatus.Active,
            operator: msg.sender,
            operationalSince: block.timestamp,
            connectedCorridors: connectedCorridors,
            sezEnabled: sezEnabled
        });

        codeToAssetId[code] = assetId;

        emit AssetRegistered(assetId, assetType, name, code);

        return assetId;
    }

    /**
     * @notice Establish freight corridor
     */
    function establishCorridor(
        string memory name,
        string memory originCode,
        string memory destinationCode,
        uint256[] memory transitAssets,
        FreightType[] memory supportedTypes,
        uint256 distance,
        uint256 averageTransitTime
    ) external onlyRole(OPERATOR_ROLE) returns (uint256) {
        require(codeToAssetId[originCode] != 0, "Origin not found");
        require(codeToAssetId[destinationCode] != 0, "Destination not found");

        uint256 corridorId = ++corridorCounter;

        corridors[corridorId] = FreightCorridor({
            corridorId: corridorId,
            name: name,
            originCode: originCode,
            destinationCode: destinationCode,
            transitAssets: transitAssets,
            supportedTypes: supportedTypes,
            distance: distance,
            averageTransitTime: averageTransitTime,
            totalVolume: 0,
            active: true
        });

        emit CorridorEstablished(corridorId, name, originCode, destinationCode);

        return corridorId;
    }

    /**
     * @notice Dispatch freight with RIN
     */
    function dispatchFreight(
        uint256 corridorId,
        string memory rin,
        string memory origin,
        string memory destination,
        FreightType freightType,
        uint256 volume,
        uint256 value,
        uint256 estimatedArrival,
        string[] memory checkpoints
    ) external payable whenNotPaused returns (uint256) {
        require(corridors[corridorId].active, "Corridor not active");
        require(bytes(rin).length > 0, "Invalid RIN");
        require(rinToMovementId[rin] == 0, "RIN already exists");
        require(volume > 0, "Invalid volume");

        uint256 corridorFee = (value * CORRIDOR_FEE_BASIS_POINTS) / 10000;
        require(msg.value >= corridorFee, "Insufficient fee");

        uint256 movementId = ++movementCounter;

        movements[movementId] = FreightMovement({
            movementId: movementId,
            corridorId: corridorId,
            rin: rin,
            shipper: msg.sender,
            origin: origin,
            destination: destination,
            freightType: freightType,
            volume: volume,
            value: value,
            departureTime: block.timestamp,
            estimatedArrival: estimatedArrival,
            actualArrival: 0,
            checkpoints: checkpoints,
            currentCheckpoint: 0,
            completed: false
        });

        rinToMovementId[rin] = movementId;
        corridors[corridorId].totalVolume += volume;
        totalFreightVolume += volume;
        totalFreightValue += value;

        CorridorFinancials storage financials = corridorFinancials[corridorId];
        financials.totalFreightValue += value;
        financials.totalFees += corridorFee;

        emit CorridorFeeCollected(corridorId, corridorFee, rin);
        emit FreightDispatched(movementId, rin, msg.sender, corridorId);

        return movementId;
    }

    /**
     * @notice Update freight checkpoint
     */
    function updateCheckpoint(uint256 movementId, string memory checkpoint)
        external
        onlyRole(OPERATOR_ROLE)
    {
        FreightMovement storage movement = movements[movementId];
        require(!movement.completed, "Movement already completed");

        movement.currentCheckpoint++;

        emit CheckpointReached(movementId, checkpoint, block.timestamp);

        // Auto-complete if last checkpoint
        if (movement.currentCheckpoint >= movement.checkpoints.length) {
            movement.completed = true;
            movement.actualArrival = block.timestamp;
            emit FreightCompleted(movementId, block.timestamp);
        }
    }

    /**
     * @notice Update asset utilization
     */
    function updateUtilization(uint256 assetId, uint256 utilization)
        external
        onlyRole(OPERATOR_ROLE)
    {
        InfrastructureAsset storage asset = assets[assetId];
        require(utilization <= asset.capacity, "Exceeds capacity");
        asset.currentUtilization = utilization;
    }

    /**
     * @notice Update port operations
     */
    function updatePortOperations(
        uint256 assetId,
        uint256 vesselsCurrent,
        uint256 vesselsAnnual,
        uint256 containersTEU,
        uint256 bulkTonnage,
        uint256 revenue
    ) external onlyRole(OPERATOR_ROLE) {
        require(assets[assetId].assetType == AssetType.Seaport, "Not a seaport");

        operations[assetId] = PortOperations({
            assetId: assetId,
            vesselsCurrent: vesselsCurrent,
            vesselsAnnual: vesselsAnnual,
            containersTEU: containersTEU,
            bulkTonnage: bulkTonnage,
            revenue: revenue
        });
    }

    /**
     * @notice Get freight movement by RIN
     */
    function getMovementByRIN(string memory rin)
        external
        view
        returns (
            uint256 movementId,
            uint256 corridorId,
            address shipper,
            string memory origin,
            string memory destination,
            uint256 volume,
            bool completed
        )
    {
        uint256 id = rinToMovementId[rin];
        require(id != 0, "RIN not found");

        FreightMovement storage movement = movements[id];
        return (
            movement.movementId,
            movement.corridorId,
            movement.shipper,
            movement.origin,
            movement.destination,
            movement.volume,
            movement.completed
        );
    }

    /**
     * @notice Get asset by code
     */
    function getAssetByCode(string memory code)
        external
        view
        returns (
            uint256 assetId,
            AssetType assetType,
            string memory name,
            string memory country,
            uint256 capacity,
            uint256 currentUtilization,
            AssetStatus status
        )
    {
        uint256 id = codeToAssetId[code];
        require(id != 0, "Asset not found");

        InfrastructureAsset storage asset = assets[id];
        return (
            asset.assetId,
            asset.assetType,
            asset.name,
            asset.country,
            asset.capacity,
            asset.currentUtilization,
            asset.status
        );
    }

    /**
     * @notice Get corridor details
     */
    function getCorridor(uint256 corridorId)
        external
        view
        returns (
            string memory name,
            string memory originCode,
            string memory destinationCode,
            uint256 distance,
            uint256 totalVolume,
            bool active
        )
    {
        FreightCorridor storage corridor = corridors[corridorId];
        return (
            corridor.name,
            corridor.originCode,
            corridor.destinationCode,
            corridor.distance,
            corridor.totalVolume,
            corridor.active
        );
    }

    function investInPort(uint256 assetId) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Must invest");
        InfrastructureAsset storage asset = assets[assetId];
        require(asset.assetType == AssetType.Seaport, "Not a port");
        require(asset.status == AssetStatus.Active, "Port not active");

        PortFinancials storage financials = portFinancials[assetId];

        uint256 shares;
        if (financials.totalShares == 0) {
            shares = msg.value;
            financials.pricePerShare = 1 ether;
        } else {
            shares = (msg.value * 1 ether) / financials.pricePerShare;
        }

        PortInvestment storage investment = portInvestments[assetId][msg.sender];
        if (investment.investedAmount == 0) {
            portInvestors[assetId].push(msg.sender);
            investment.investor = msg.sender;
            investment.assetId = assetId;
            investment.investmentDate = block.timestamp;
        }

        investment.shares += shares;
        investment.investedAmount += msg.value;
        investment.lastClaimDate = block.timestamp;

        financials.totalShares += shares;

        emit PortInvestmentMade(assetId, msg.sender, msg.value, shares);
    }

    function recordPortRevenue(uint256 assetId, uint256 revenue, uint256 costs)
        external
        onlyRole(OPERATOR_ROLE)
    {
        PortOperations storage ops = operations[assetId];
        PortFinancials storage financials = portFinancials[assetId];

        ops.revenue += revenue;
        financials.totalRevenue += revenue;
        financials.operatingCosts += costs;
        financials.netProfit = financials.totalRevenue - financials.operatingCosts;

        emit PortRevenueRecorded(assetId, revenue, costs);
    }

    function distributePortDividends(uint256 assetId) external onlyRole(OPERATOR_ROLE) {
        PortFinancials storage financials = portFinancials[assetId];
        require(financials.totalShares > 0, "No shareholders");
        require(financials.netProfit > 0, "No profit");

        uint256 dividendPool = (financials.netProfit * 70) / 100;
        uint256 dividendPerShare = (dividendPool * 1 ether) / financials.totalShares;

        financials.dividendPerShare += dividendPerShare;
        financials.lastDividendDate = block.timestamp;

        emit DividendDistributed(assetId, dividendPool);
    }

    function claimPortDividends(uint256 assetId) external nonReentrant {
        PortInvestment storage investment = portInvestments[assetId][msg.sender];
        require(investment.shares > 0, "No investment");

        PortFinancials storage financials = portFinancials[assetId];

        uint256 totalDividends = (investment.shares * financials.dividendPerShare) / 1 ether;
        uint256 unclaimed = totalDividends - investment.totalClaimed;

        require(unclaimed > 0, "No dividends");
        require(address(this).balance >= unclaimed, "Insufficient balance");

        investment.totalClaimed += unclaimed;
        investment.lastClaimDate = block.timestamp;

        (bool success, ) = payable(msg.sender).call{value: unclaimed}("");
        require(success, "Transfer failed");

        emit DividendClaimed(assetId, msg.sender, unclaimed);
    }

    function investInCorridor(uint256 corridorId) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Must invest");
        require(corridors[corridorId].active, "Corridor not active");

        CorridorFinancials storage financials = corridorFinancials[corridorId];

        if (corridorInvestorShares[corridorId][msg.sender] == 0) {
            corridorInvestors[corridorId].push(msg.sender);
        }

        corridorInvestorShares[corridorId][msg.sender] += msg.value;
        financials.investorPool += msg.value;

        emit CorridorInvestmentMade(corridorId, msg.sender, msg.value);
    }

    function distributeCorridorProfits(uint256 corridorId) external onlyRole(OPERATOR_ROLE) nonReentrant {
        CorridorFinancials storage financials = corridorFinancials[corridorId];
        require(financials.totalFees > 0, "No fees");
        require(financials.investorPool > 0, "No investors");

        uint256 investorPayout = (financials.totalFees * 80) / 100;

        address[] memory investors = corridorInvestors[corridorId];
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 share = corridorInvestorShares[corridorId][investor];
            uint256 payout = (investorPayout * share) / financials.investorPool;

            if (payout > 0) {
                (bool success, ) = payable(investor).call{value: payout}("");
                require(success, "Transfer failed");
            }
        }

        financials.totalFees = 0;

        emit CorridorProfitDistributed(corridorId, investorPayout);
    }

    function getPortROI(uint256 assetId, address investor)
        external
        view
        returns (uint256 invested, uint256 currentValue, uint256 claimed, int256 roi)
    {
        PortInvestment storage investment = portInvestments[assetId][investor];
        PortFinancials storage financials = portFinancials[assetId];

        invested = investment.investedAmount;
        currentValue = (investment.shares * financials.pricePerShare) / 1 ether;
        claimed = investment.totalClaimed;

        uint256 totalValue = currentValue + claimed;
        roi = int256((totalValue * 100) / invested) - 100;
    }

    function getCorridorProfitability(uint256 corridorId)
        external
        view
        returns (uint256 totalFreight, uint256 totalFees, uint256 investorPool)
    {
        CorridorFinancials storage financials = corridorFinancials[corridorId];
        totalFreight = financials.totalFreightValue;
        totalFees = financials.totalFees;
        investorPool = financials.investorPool;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    receive() external payable {}
}
