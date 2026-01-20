// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ArmsTradeCompliance
 * @notice Governmental services for arms and commodities trade with full compliance
 * @dev Covers export licenses, end-user certificates, sanctions screening
 */
contract ArmsTradeCompliance is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT_ROLE");
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant CUSTOMS_ROLE = keccak256("CUSTOMS_ROLE");

    enum CommodityType {
        ConventionalArms,
        DualUse,
        StrategicMinerals,
        Energy,
        Agriculture,
        Industrial,
        Technology,
        Pharmaceutical
    }

    enum LicenseStatus {
        Pending,
        UnderReview,
        Approved,
        Rejected,
        Suspended,
        Revoked,
        Expired
    }

    enum ComplianceStatus {
        NotScreened,
        InProgress,
        Cleared,
        Flagged,
        Rejected
    }

    struct ExportLicense {
        uint256 licenseId;
        address exporter;
        address importer;
        string exporterCountry;
        string importerCountry;
        CommodityType commodityType;
        string commodityDescription;
        string hsCode; // Harmonized System Code
        uint256 quantity;
        uint256 value;
        LicenseStatus status;
        uint256 issuedDate;
        uint256 expiryDate;
        string documentHash; // IPFS hash
        bool endUserCertificateProvided;
        ComplianceStatus complianceStatus;
    }

    struct EndUserCertificate {
        uint256 certificateId;
        uint256 licenseId;
        address endUser;
        string endUserCountry;
        string intendedUse;
        string certificateHash; // IPFS hash
        bool verified;
        uint256 issuedDate;
        address verifiedBy;
    }

    struct SanctionsCheck {
        uint256 checkId;
        address entity;
        string entityName;
        string country;
        bool isSanctioned;
        string sanctionsList; // OFAC, UN, EU, etc.
        uint256 checkedDate;
        address checkedBy;
        string remarks;
    }

    struct CommodityShipment {
        uint256 shipmentId;
        uint256 licenseId;
        string originPort;
        string destinationPort;
        string carrier;
        string trackingNumber;
        uint256 departureDate;
        uint256 estimatedArrival;
        uint256 actualArrival;
        bool customsCleared;
        string customsReference;
    }

    // State variables
    mapping(uint256 => ExportLicense) public licenses;
    mapping(uint256 => EndUserCertificate) public certificates;
    mapping(uint256 => SanctionsCheck) public sanctionsChecks;
    mapping(uint256 => CommodityShipment) public shipments;
    mapping(address => uint256[]) public exporterLicenses;
    mapping(string => bool) public sanctionedCountries;
    mapping(string => bool) public sanctionedEntities;

    uint256 public licenseCounter;
    uint256 public certificateCounter;
    uint256 public sanctionsCheckCounter;
    uint256 public shipmentCounter;

    uint256 public constant LICENSE_VALIDITY_PERIOD = 365 days;
    uint256 public totalTradeValue;

    // Events
    event LicenseApplied(
        uint256 indexed licenseId,
        address indexed exporter,
        CommodityType commodityType,
        uint256 value
    );

    event LicenseApproved(
        uint256 indexed licenseId,
        uint256 expiryDate
    );

    event LicenseRejected(
        uint256 indexed licenseId,
        string reason
    );

    event EndUserCertificateIssued(
        uint256 indexed certificateId,
        uint256 indexed licenseId,
        address endUser
    );

    event SanctionsCheckCompleted(
        uint256 indexed checkId,
        address indexed entity,
        bool isSanctioned
    );

    event ShipmentTracked(
        uint256 indexed shipmentId,
        uint256 indexed licenseId,
        string originPort,
        string destinationPort
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
        _grantRole(GOVERNMENT_ROLE, admin);
        _grantRole(COMPLIANCE_OFFICER_ROLE, admin);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    /**
     * @notice Apply for export license
     */
    function applyForLicense(
        address importer,
        string memory exporterCountry,
        string memory importerCountry,
        CommodityType commodityType,
        string memory commodityDescription,
        string memory hsCode,
        uint256 quantity,
        uint256 value,
        string memory documentHash
    ) external whenNotPaused returns (uint256) {
        require(bytes(exporterCountry).length > 0, "Invalid exporter country");
        require(bytes(importerCountry).length > 0, "Invalid importer country");
        require(!sanctionedCountries[importerCountry], "Sanctioned country");
        require(value > 0, "Invalid value");

        uint256 licenseId = ++licenseCounter;

        licenses[licenseId] = ExportLicense({
            licenseId: licenseId,
            exporter: msg.sender,
            importer: importer,
            exporterCountry: exporterCountry,
            importerCountry: importerCountry,
            commodityType: commodityType,
            commodityDescription: commodityDescription,
            hsCode: hsCode,
            quantity: quantity,
            value: value,
            status: LicenseStatus.Pending,
            issuedDate: 0,
            expiryDate: 0,
            documentHash: documentHash,
            endUserCertificateProvided: false,
            complianceStatus: ComplianceStatus.NotScreened
        });

        exporterLicenses[msg.sender].push(licenseId);

        emit LicenseApplied(licenseId, msg.sender, commodityType, value);

        return licenseId;
    }

    /**
     * @notice Submit end-user certificate
     */
    function submitEndUserCertificate(
        uint256 licenseId,
        address endUser,
        string memory endUserCountry,
        string memory intendedUse,
        string memory certificateHash
    ) external returns (uint256) {
        ExportLicense storage license = licenses[licenseId];
        require(license.exporter == msg.sender, "Not license owner");
        require(license.status == LicenseStatus.Pending || license.status == LicenseStatus.UnderReview, "Invalid status");

        uint256 certificateId = ++certificateCounter;

        certificates[certificateId] = EndUserCertificate({
            certificateId: certificateId,
            licenseId: licenseId,
            endUser: endUser,
            endUserCountry: endUserCountry,
            intendedUse: intendedUse,
            certificateHash: certificateHash,
            verified: false,
            issuedDate: block.timestamp,
            verifiedBy: address(0)
        });

        license.endUserCertificateProvided = true;

        emit EndUserCertificateIssued(certificateId, licenseId, endUser);

        return certificateId;
    }

    /**
     * @notice Perform sanctions screening
     */
    function performSanctionsCheck(
        address entity,
        string memory entityName,
        string memory country
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) returns (uint256) {
        uint256 checkId = ++sanctionsCheckCounter;

        bool isSanctioned = sanctionedCountries[country] || sanctionedEntities[entityName];

        sanctionsChecks[checkId] = SanctionsCheck({
            checkId: checkId,
            entity: entity,
            entityName: entityName,
            country: country,
            isSanctioned: isSanctioned,
            sanctionsList: isSanctioned ? "OFAC/UN/EU" : "Clear",
            checkedDate: block.timestamp,
            checkedBy: msg.sender,
            remarks: isSanctioned ? "Entity flagged for sanctions" : "No sanctions found"
        });

        emit SanctionsCheckCompleted(checkId, entity, isSanctioned);

        return checkId;
    }

    /**
     * @notice Approve export license
     */
    function approveLicense(uint256 licenseId)
        external
        onlyRole(GOVERNMENT_ROLE)
    {
        ExportLicense storage license = licenses[licenseId];
        require(license.status == LicenseStatus.Pending || license.status == LicenseStatus.UnderReview, "Invalid status");
        require(license.endUserCertificateProvided, "End-user certificate required");

        license.status = LicenseStatus.Approved;
        license.issuedDate = block.timestamp;
        license.expiryDate = block.timestamp + LICENSE_VALIDITY_PERIOD;
        license.complianceStatus = ComplianceStatus.Cleared;

        totalTradeValue += license.value;

        emit LicenseApproved(licenseId, license.expiryDate);
    }

    /**
     * @notice Reject export license
     */
    function rejectLicense(uint256 licenseId, string memory reason)
        external
        onlyRole(GOVERNMENT_ROLE)
    {
        ExportLicense storage license = licenses[licenseId];
        require(license.status == LicenseStatus.Pending || license.status == LicenseStatus.UnderReview, "Invalid status");

        license.status = LicenseStatus.Rejected;
        license.complianceStatus = ComplianceStatus.Rejected;

        emit LicenseRejected(licenseId, reason);
    }

    /**
     * @notice Track commodity shipment
     */
    function trackShipment(
        uint256 licenseId,
        string memory originPort,
        string memory destinationPort,
        string memory carrier,
        string memory trackingNumber,
        uint256 departureDate,
        uint256 estimatedArrival
    ) external onlyRole(CUSTOMS_ROLE) returns (uint256) {
        ExportLicense storage license = licenses[licenseId];
        require(license.status == LicenseStatus.Approved, "License not approved");

        uint256 shipmentId = ++shipmentCounter;

        shipments[shipmentId] = CommodityShipment({
            shipmentId: shipmentId,
            licenseId: licenseId,
            originPort: originPort,
            destinationPort: destinationPort,
            carrier: carrier,
            trackingNumber: trackingNumber,
            departureDate: departureDate,
            estimatedArrival: estimatedArrival,
            actualArrival: 0,
            customsCleared: false,
            customsReference: ""
        });

        emit ShipmentTracked(shipmentId, licenseId, originPort, destinationPort);

        return shipmentId;
    }

    /**
     * @notice Clear customs for shipment
     */
    function clearCustoms(uint256 shipmentId, string memory customsReference)
        external
        onlyRole(CUSTOMS_ROLE)
    {
        CommodityShipment storage shipment = shipments[shipmentId];
        require(!shipment.customsCleared, "Already cleared");

        shipment.customsCleared = true;
        shipment.actualArrival = block.timestamp;
        shipment.customsReference = customsReference;
    }

    /**
     * @notice Add sanctioned country
     */
    function addSanctionedCountry(string memory country)
        external
        onlyRole(GOVERNMENT_ROLE)
    {
        sanctionedCountries[country] = true;
    }

    /**
     * @notice Remove sanctioned country
     */
    function removeSanctionedCountry(string memory country)
        external
        onlyRole(GOVERNMENT_ROLE)
    {
        sanctionedCountries[country] = false;
    }

    /**
     * @notice Add sanctioned entity
     */
    function addSanctionedEntity(string memory entity)
        external
        onlyRole(GOVERNMENT_ROLE)
    {
        sanctionedEntities[entity] = true;
    }

    /**
     * @notice Get license details
     */
    function getLicense(uint256 licenseId)
        external
        view
        returns (
            address exporter,
            address importer,
            CommodityType commodityType,
            uint256 value,
            LicenseStatus status,
            uint256 expiryDate,
            ComplianceStatus complianceStatus
        )
    {
        ExportLicense storage license = licenses[licenseId];
        return (
            license.exporter,
            license.importer,
            license.commodityType,
            license.value,
            license.status,
            license.expiryDate,
            license.complianceStatus
        );
    }

    /**
     * @notice Get exporter's licenses
     */
    function getExporterLicenses(address exporter)
        external
        view
        returns (uint256[] memory)
    {
        return exporterLicenses[exporter];
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
