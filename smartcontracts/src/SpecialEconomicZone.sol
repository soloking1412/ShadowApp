// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SpecialEconomicZone
 * @notice Manage Special Economic Zones with customs, tax incentives, and trade benefits
 * @dev Covers port of entry/exit, free trade zones, industrial parks
 */
contract SpecialEconomicZone is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SEZ_AUTHORITY_ROLE = keccak256("SEZ_AUTHORITY_ROLE");
    bytes32 public constant CUSTOMS_ROLE = keccak256("CUSTOMS_ROLE");

    enum SEZType {
        FreeTrade,
        ExportProcessing,
        IndustrialPark,
        TechnologyPark,
        FinancialCenter,
        LogisticsHub,
        PortAuthority
    }

    enum IncentiveType {
        TaxHoliday,
        DutyExemption,
        SubsidizedLand,
        UtilityRebate,
        EmploymentGrant,
        RDGrant
    }

    enum ZoneStatus {
        Active,
        UnderDevelopment,
        Suspended,
        Decommissioned
    }

    struct SEZ {
        uint256 zoneId;
        SEZType zoneType;
        string name;
        string location;
        string country;
        string portCode; // Associated port/airport code
        uint256 area; // in square meters
        ZoneStatus status;
        uint256 establishedDate;
        address authority;
        string[] allowedActivities;
        uint256 totalInvestment;
        uint256 employmentCount;
        bool customsAutomated;
    }

    struct Enterprise {
        uint256 enterpriseId;
        uint256 zoneId;
        address owner;
        string companyName;
        string registrationNumber;
        string industry;
        uint256 investment;
        uint256 employees;
        uint256 registeredDate;
        uint256 licenseExpiry;
        bool active;
        IncentiveType[] incentives;
    }

    struct Customs {
        uint256 customsId;
        uint256 zoneId;
        uint256 enterpriseId;
        string declarationType; // Import/Export/Transit
        string goodsDescription;
        string hsCode;
        uint256 quantity;
        uint256 value;
        uint256 dutyRate; // Basis points
        uint256 dutyAmount;
        bool dutyExempt;
        uint256 timestamp;
        bool cleared;
        string clearanceReference;
    }

    struct TaxIncentive {
        uint256 incentiveId;
        uint256 enterpriseId;
        IncentiveType incentiveType;
        string description;
        uint256 value;
        uint256 startDate;
        uint256 endDate;
        bool active;
    }

    struct ImportExportStats {
        uint256 zoneId;
        uint256 totalImports;
        uint256 totalExports;
        uint256 totalTransit;
        uint256 dutyCollected;
        uint256 dutyExempted;
        uint256 lastUpdated;
    }

    // State variables
    mapping(uint256 => SEZ) public zones;
    mapping(uint256 => Enterprise) public enterprises;
    mapping(uint256 => Customs) public customsDeclarations;
    mapping(uint256 => TaxIncentive) public incentives;
    mapping(uint256 => ImportExportStats) public zoneStats;
    mapping(uint256 => uint256[]) public zoneEnterprises;
    mapping(address => uint256[]) public ownerEnterprises;

    uint256 public zoneCounter;
    uint256 public enterpriseCounter;
    uint256 public customsCounter;
    uint256 public incentiveCounter;

    uint256 public totalSEZInvestment;
    uint256 public totalEmployment;
    uint256 public totalTradeValue;
    uint256 public constant BASIS_POINTS = 10000;

    // Events
    event SEZEstablished(
        uint256 indexed zoneId,
        SEZType zoneType,
        string name,
        string location
    );

    event EnterpriseRegistered(
        uint256 indexed enterpriseId,
        uint256 indexed zoneId,
        address indexed owner,
        string companyName
    );

    event CustomsDeclarationFiled(
        uint256 indexed customsId,
        uint256 indexed zoneId,
        uint256 indexed enterpriseId,
        string declarationType,
        uint256 value
    );

    event CustomsCleared(
        uint256 indexed customsId,
        string clearanceReference
    );

    event IncentiveGranted(
        uint256 indexed incentiveId,
        uint256 indexed enterpriseId,
        IncentiveType incentiveType,
        uint256 value
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
        _grantRole(SEZ_AUTHORITY_ROLE, admin);
        _grantRole(CUSTOMS_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    /**
     * @notice Establish new SEZ
     */
    function establishSEZ(
        SEZType zoneType,
        string memory name,
        string memory location,
        string memory country,
        string memory portCode,
        uint256 area,
        string[] memory allowedActivities
    ) external onlyRole(SEZ_AUTHORITY_ROLE) returns (uint256) {
        require(bytes(name).length > 0, "Invalid name");
        require(area > 0, "Invalid area");

        uint256 zoneId = ++zoneCounter;

        zones[zoneId] = SEZ({
            zoneId: zoneId,
            zoneType: zoneType,
            name: name,
            location: location,
            country: country,
            portCode: portCode,
            area: area,
            status: ZoneStatus.Active,
            establishedDate: block.timestamp,
            authority: msg.sender,
            allowedActivities: allowedActivities,
            totalInvestment: 0,
            employmentCount: 0,
            customsAutomated: true
        });

        emit SEZEstablished(zoneId, zoneType, name, location);

        return zoneId;
    }

    /**
     * @notice Register enterprise in SEZ
     */
    function registerEnterprise(
        uint256 zoneId,
        string memory companyName,
        string memory registrationNumber,
        string memory industry,
        uint256 investment,
        uint256 employees,
        uint256 licenseDuration
    ) external whenNotPaused returns (uint256) {
        SEZ storage zone = zones[zoneId];
        require(zone.status == ZoneStatus.Active, "Zone not active");
        require(investment > 0, "Invalid investment");

        uint256 enterpriseId = ++enterpriseCounter;

        enterprises[enterpriseId] = Enterprise({
            enterpriseId: enterpriseId,
            zoneId: zoneId,
            owner: msg.sender,
            companyName: companyName,
            registrationNumber: registrationNumber,
            industry: industry,
            investment: investment,
            employees: employees,
            registeredDate: block.timestamp,
            licenseExpiry: block.timestamp + licenseDuration,
            active: true,
            incentives: new IncentiveType[](0)
        });

        zoneEnterprises[zoneId].push(enterpriseId);
        ownerEnterprises[msg.sender].push(enterpriseId);

        zone.totalInvestment += investment;
        zone.employmentCount += employees;
        totalSEZInvestment += investment;
        totalEmployment += employees;

        emit EnterpriseRegistered(enterpriseId, zoneId, msg.sender, companyName);

        return enterpriseId;
    }

    /**
     * @notice File customs declaration
     */
    function fileCustomsDeclaration(
        uint256 zoneId,
        uint256 enterpriseId,
        string memory declarationType,
        string memory goodsDescription,
        string memory hsCode,
        uint256 quantity,
        uint256 value,
        uint256 dutyRate,
        bool dutyExempt
    ) external whenNotPaused returns (uint256) {
        require(zones[zoneId].status == ZoneStatus.Active, "Zone not active");
        Enterprise storage enterprise = enterprises[enterpriseId];
        require(enterprise.owner == msg.sender, "Not enterprise owner");
        require(enterprise.active, "Enterprise not active");

        uint256 customsId = ++customsCounter;
        uint256 dutyAmount = dutyExempt ? 0 : (value * dutyRate) / BASIS_POINTS;

        customsDeclarations[customsId] = Customs({
            customsId: customsId,
            zoneId: zoneId,
            enterpriseId: enterpriseId,
            declarationType: declarationType,
            goodsDescription: goodsDescription,
            hsCode: hsCode,
            quantity: quantity,
            value: value,
            dutyRate: dutyRate,
            dutyAmount: dutyAmount,
            dutyExempt: dutyExempt,
            timestamp: block.timestamp,
            cleared: false,
            clearanceReference: ""
        });

        // Update stats
        ImportExportStats storage stats = zoneStats[zoneId];
        if (keccak256(bytes(declarationType)) == keccak256(bytes("Import"))) {
            stats.totalImports += value;
        } else if (keccak256(bytes(declarationType)) == keccak256(bytes("Export"))) {
            stats.totalExports += value;
        } else {
            stats.totalTransit += value;
        }

        if (dutyExempt) {
            stats.dutyExempted += dutyAmount;
        } else {
            stats.dutyCollected += dutyAmount;
        }

        stats.lastUpdated = block.timestamp;
        totalTradeValue += value;

        emit CustomsDeclarationFiled(customsId, zoneId, enterpriseId, declarationType, value);

        return customsId;
    }

    /**
     * @notice Clear customs declaration
     */
    function clearCustoms(uint256 customsId, string memory clearanceReference)
        external
        onlyRole(CUSTOMS_ROLE)
    {
        Customs storage declaration = customsDeclarations[customsId];
        require(!declaration.cleared, "Already cleared");

        declaration.cleared = true;
        declaration.clearanceReference = clearanceReference;

        emit CustomsCleared(customsId, clearanceReference);
    }

    /**
     * @notice Grant tax incentive
     */
    function grantIncentive(
        uint256 enterpriseId,
        IncentiveType incentiveType,
        string memory description,
        uint256 value,
        uint256 duration
    ) external onlyRole(SEZ_AUTHORITY_ROLE) returns (uint256) {
        Enterprise storage enterprise = enterprises[enterpriseId];
        require(enterprise.active, "Enterprise not active");

        uint256 incentiveId = ++incentiveCounter;

        incentives[incentiveId] = TaxIncentive({
            incentiveId: incentiveId,
            enterpriseId: enterpriseId,
            incentiveType: incentiveType,
            description: description,
            value: value,
            startDate: block.timestamp,
            endDate: block.timestamp + duration,
            active: true
        });

        enterprise.incentives.push(incentiveType);

        emit IncentiveGranted(incentiveId, enterpriseId, incentiveType, value);

        return incentiveId;
    }

    /**
     * @notice Get SEZ details
     */
    function getSEZ(uint256 zoneId)
        external
        view
        returns (
            SEZType zoneType,
            string memory name,
            string memory location,
            string memory country,
            uint256 area,
            ZoneStatus status,
            uint256 totalInvestment,
            uint256 employmentCount
        )
    {
        SEZ storage zone = zones[zoneId];
        return (
            zone.zoneType,
            zone.name,
            zone.location,
            zone.country,
            zone.area,
            zone.status,
            zone.totalInvestment,
            zone.employmentCount
        );
    }

    /**
     * @notice Get zone enterprises
     */
    function getZoneEnterprises(uint256 zoneId)
        external
        view
        returns (uint256[] memory)
    {
        return zoneEnterprises[zoneId];
    }

    /**
     * @notice Get owner enterprises
     */
    function getOwnerEnterprises(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerEnterprises[owner];
    }

    /**
     * @notice Get zone statistics
     */
    function getZoneStats(uint256 zoneId)
        external
        view
        returns (
            uint256 totalImports,
            uint256 totalExports,
            uint256 totalTransit,
            uint256 dutyCollected,
            uint256 dutyExempted
        )
    {
        ImportExportStats storage stats = zoneStats[zoneId];
        return (
            stats.totalImports,
            stats.totalExports,
            stats.totalTransit,
            stats.dutyCollected,
            stats.dutyExempted
        );
    }

    /**
     * @notice Update zone status
     */
    function updateZoneStatus(uint256 zoneId, ZoneStatus status)
        external
        onlyRole(SEZ_AUTHORITY_ROLE)
    {
        zones[zoneId].status = status;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
