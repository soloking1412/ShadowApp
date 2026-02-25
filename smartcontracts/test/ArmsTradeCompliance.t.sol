// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ArmsTradeCompliance.sol";

contract ArmsTradeComplianceTest is Test {
    ArmsTradeCompliance instance;
    address admin = address(1);
    address exporter = address(2);
    address importer = address(3);
    address endUser = address(4);
    address complianceOfficer = address(5);
    address customsOfficer = address(6);
    address govOfficer = address(7);

    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT_ROLE");
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant CUSTOMS_ROLE = keccak256("CUSTOMS_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp() public {
        ArmsTradeCompliance impl = new ArmsTradeCompliance();
        bytes memory init = abi.encodeCall(ArmsTradeCompliance.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = ArmsTradeCompliance(address(proxy));

        // Grant specialized roles
        vm.prank(admin);
        instance.grantRole(GOVERNMENT_ROLE, govOfficer);
        vm.prank(admin);
        instance.grantRole(COMPLIANCE_OFFICER_ROLE, complianceOfficer);
        vm.prank(admin);
        instance.grantRole(CUSTOMS_ROLE, customsOfficer);
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_AdminHasAllRoles() public view {
        assertTrue(instance.hasRole(ADMIN_ROLE, admin));
        assertTrue(instance.hasRole(GOVERNMENT_ROLE, admin));
        assertTrue(instance.hasRole(COMPLIANCE_OFFICER_ROLE, admin));
    }

    function test_LicenseValidityPeriod() public view {
        assertEq(instance.LICENSE_VALIDITY_PERIOD(), 365 days);
    }

    // ── Apply for License ───────────────────────────────────────────────────

    function _applyLicense() internal returns (uint256 licenseId) {
        vm.prank(exporter);
        licenseId = instance.applyForLicense(
            importer,
            "US",
            "DE",
            ArmsTradeCompliance.CommodityType.DualUse,
            "Dual-use electronic components",
            "8542.31",
            1000,
            5_000_000,
            "ipfs://docHash"
        );
    }

    function test_ApplyForLicense() public {
        uint256 licenseId = _applyLicense();

        assertEq(licenseId, 1);
        assertEq(instance.licenseCounter(), 1);

        (
            address exp,
            address imp,
            ArmsTradeCompliance.CommodityType commType,
            uint256 value,
            ArmsTradeCompliance.LicenseStatus status,
            uint256 expiryDate,
            ArmsTradeCompliance.ComplianceStatus compStatus
        ) = instance.getLicense(licenseId);

        assertEq(exp, exporter);
        assertEq(imp, importer);
        assertEq(uint8(commType), uint8(ArmsTradeCompliance.CommodityType.DualUse));
        assertEq(value, 5_000_000);
        assertEq(uint8(status), uint8(ArmsTradeCompliance.LicenseStatus.Pending));
        assertEq(expiryDate, 0); // not approved yet
        assertEq(uint8(compStatus), uint8(ArmsTradeCompliance.ComplianceStatus.NotScreened));
    }

    function test_ApplyForSanctionedCountryReverts() public {
        vm.prank(govOfficer);
        instance.addSanctionedCountry("IR"); // Iran

        vm.prank(exporter);
        vm.expectRevert("Sanctioned country");
        instance.applyForLicense(
            importer,
            "US",
            "IR", // sanctioned
            ArmsTradeCompliance.CommodityType.ConventionalArms,
            "weapons",
            "93.01",
            100,
            1_000_000,
            ""
        );
    }

    function test_ApplyForLicenseZeroValueReverts() public {
        vm.prank(exporter);
        vm.expectRevert("Invalid value");
        instance.applyForLicense(
            importer,
            "US",
            "DE",
            ArmsTradeCompliance.CommodityType.Industrial,
            "machines",
            "84.29",
            10,
            0, // zero value
            ""
        );
    }

    // ── End User Certificate ────────────────────────────────────────────────

    function test_SubmitEndUserCertificate() public {
        uint256 licenseId = _applyLicense();

        vm.prank(exporter);
        uint256 certId = instance.submitEndUserCertificate(
            licenseId,
            endUser,
            "DE",
            "Civilian research use only",
            "ipfs://certHash"
        );

        assertEq(certId, 1);

        // EndUserCertificate: certificateId, licenseId, endUser, endUserCountry, intendedUse, certificateHash, verified, issuedDate, verifiedBy
        (
            ,
            uint256 cert_licenseId,
            address cert_endUser,
            string memory cert_endUserCountry,
            ,
            ,
            bool cert_verified,
            ,
        ) = instance.certificates(certId);
        assertEq(cert_licenseId, licenseId);
        assertEq(cert_endUser, endUser);
        assertEq(cert_endUserCountry, "DE");
        assertFalse(cert_verified);

        // ExportLicense: licenseId, exporter, importer, exporterCountry, importerCountry, commodityType, commodityDescription, hsCode, quantity, value, status, issuedDate, expiryDate, documentHash, endUserCertificateProvided, complianceStatus
        (, , , , , , , , , , , , , , bool lic_endUserCertProvided, ) = instance.licenses(licenseId);
        assertTrue(lic_endUserCertProvided);
    }

    function test_SubmitCertNonLicenseOwnerReverts() public {
        uint256 licenseId = _applyLicense();

        vm.prank(importer); // not the exporter
        vm.expectRevert("Not license owner");
        instance.submitEndUserCertificate(licenseId, endUser, "DE", "research", "ipfs://hash");
    }

    // ── Sanctions Screening ─────────────────────────────────────────────────

    function test_PerformSanctionsCheckClear() public {
        vm.prank(complianceOfficer);
        uint256 checkId = instance.performSanctionsCheck(importer, "Acme Corp", "DE");

        assertEq(checkId, 1);

        // SanctionsCheck: checkId, entity, entityName, country, isSanctioned, sanctionsList, checkedDate, checkedBy, remarks
        (
            ,
            address check_entity,
            ,
            ,
            bool check_isSanctioned,
            string memory check_sanctionsList,
            ,
            ,
        ) = instance.sanctionsChecks(checkId);
        assertEq(check_entity, importer);
        assertFalse(check_isSanctioned);
        assertEq(check_sanctionsList, "Clear");
    }

    function test_PerformSanctionsCheckFlagged() public {
        vm.prank(govOfficer);
        instance.addSanctionedEntity("Rogue Corp");

        vm.prank(complianceOfficer);
        uint256 checkId = instance.performSanctionsCheck(importer, "Rogue Corp", "DE");

        // SanctionsCheck: checkId, entity, entityName, country, isSanctioned, sanctionsList, checkedDate, checkedBy, remarks
        (
            ,
            ,
            ,
            ,
            bool check2_isSanctioned,
            string memory check2_sanctionsList,
            ,
            ,
        ) = instance.sanctionsChecks(checkId);
        assertTrue(check2_isSanctioned);
        assertEq(check2_sanctionsList, "OFAC/UN/EU");
    }

    function test_SanctionsCheckNonComplianceOfficerReverts() public {
        vm.prank(exporter);
        vm.expectRevert();
        instance.performSanctionsCheck(importer, "Corp", "US");
    }

    // ── Approve / Reject License ────────────────────────────────────────────

    function test_ApproveLicense() public {
        uint256 licenseId = _applyLicense();

        // Must provide end-user certificate first
        vm.prank(exporter);
        instance.submitEndUserCertificate(licenseId, endUser, "DE", "research", "ipfs://c");

        vm.prank(govOfficer);
        instance.approveLicense(licenseId);

        (
            ,
            ,
            ,
            uint256 value,
            ArmsTradeCompliance.LicenseStatus status,
            uint256 expiryDate,
            ArmsTradeCompliance.ComplianceStatus compStatus
        ) = instance.getLicense(licenseId);

        assertEq(uint8(status), uint8(ArmsTradeCompliance.LicenseStatus.Approved));
        assertEq(uint8(compStatus), uint8(ArmsTradeCompliance.ComplianceStatus.Cleared));
        assertGt(expiryDate, block.timestamp);
        assertEq(instance.totalTradeValue(), value);
    }

    function test_ApproveLicenseWithoutCertReverts() public {
        uint256 licenseId = _applyLicense();

        vm.prank(govOfficer);
        vm.expectRevert("End-user certificate required");
        instance.approveLicense(licenseId);
    }

    function test_RejectLicense() public {
        uint256 licenseId = _applyLicense();

        vm.prank(govOfficer);
        instance.rejectLicense(licenseId, "Dual-use technology risk");

        (
            ,
            ,
            ,
            ,
            ArmsTradeCompliance.LicenseStatus status,
            ,
            ArmsTradeCompliance.ComplianceStatus compStatus
        ) = instance.getLicense(licenseId);

        assertEq(uint8(status), uint8(ArmsTradeCompliance.LicenseStatus.Rejected));
        assertEq(uint8(compStatus), uint8(ArmsTradeCompliance.ComplianceStatus.Rejected));
    }

    // ── Shipment Tracking ───────────────────────────────────────────────────

    function _getApprovedLicense() internal returns (uint256 licenseId) {
        licenseId = _applyLicense();
        vm.prank(exporter);
        instance.submitEndUserCertificate(licenseId, endUser, "DE", "use", "ipfs://cert");
        vm.prank(govOfficer);
        instance.approveLicense(licenseId);
    }

    function test_TrackShipment() public {
        uint256 licenseId = _getApprovedLicense();

        vm.prank(customsOfficer);
        uint256 shipmentId = instance.trackShipment(
            licenseId,
            "New York",
            "Hamburg",
            "Maersk",
            "MAEU-123456",
            block.timestamp,
            block.timestamp + 14 days
        );

        assertEq(shipmentId, 1);
        assertEq(instance.shipmentCounter(), 1);

        // CommodityShipment: shipmentId, licenseId, originPort, destinationPort, carrier, trackingNumber, departureDate, estimatedArrival, actualArrival, customsCleared, customsReference
        (
            ,
            uint256 ship_licenseId,
            string memory ship_originPort,
            string memory ship_destinationPort,
            ,
            ,
            ,
            ,
            ,
            bool ship_customsCleared,
        ) = instance.shipments(shipmentId);
        assertEq(ship_licenseId, licenseId);
        assertEq(ship_originPort, "New York");
        assertEq(ship_destinationPort, "Hamburg");
        assertFalse(ship_customsCleared);
    }

    function test_TrackShipmentUnapprovedReverts() public {
        uint256 licenseId = _applyLicense();

        vm.prank(customsOfficer);
        vm.expectRevert("License not approved");
        instance.trackShipment(licenseId, "NY", "HH", "Carrier", "TRK-001", block.timestamp, block.timestamp + 7 days);
    }

    function test_ClearCustoms() public {
        uint256 licenseId = _getApprovedLicense();

        vm.prank(customsOfficer);
        uint256 shipmentId = instance.trackShipment(
            licenseId, "NY", "HH", "Maersk", "TRK-001",
            block.timestamp, block.timestamp + 14 days
        );

        vm.prank(customsOfficer);
        instance.clearCustoms(shipmentId, "HH-CUSTOMS-2024-001");

        // CommodityShipment: shipmentId, licenseId, originPort, destinationPort, carrier, trackingNumber, departureDate, estimatedArrival, actualArrival, customsCleared, customsReference
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 ship2_actualArrival,
            bool ship2_customsCleared,
            string memory ship2_customsReference
        ) = instance.shipments(shipmentId);
        assertTrue(ship2_customsCleared);
        assertEq(ship2_customsReference, "HH-CUSTOMS-2024-001");
        assertGt(ship2_actualArrival, 0);
    }

    function test_ClearCustomsTwiceReverts() public {
        uint256 licenseId = _getApprovedLicense();
        vm.prank(customsOfficer);
        uint256 shipmentId = instance.trackShipment(
            licenseId, "NY", "HH", "Maersk", "TRK-002",
            block.timestamp, block.timestamp + 14 days
        );
        vm.prank(customsOfficer);
        instance.clearCustoms(shipmentId, "REF-001");

        vm.prank(customsOfficer);
        vm.expectRevert("Already cleared");
        instance.clearCustoms(shipmentId, "REF-002");
    }

    // ── Sanctions Management ────────────────────────────────────────────────

    function test_AddAndRemoveSanctionedCountry() public {
        vm.prank(govOfficer);
        instance.addSanctionedCountry("KP"); // North Korea
        assertTrue(instance.sanctionedCountries("KP"));

        vm.prank(govOfficer);
        instance.removeSanctionedCountry("KP");
        assertFalse(instance.sanctionedCountries("KP"));
    }

    function test_AddSanctionedEntity() public {
        vm.prank(govOfficer);
        instance.addSanctionedEntity("Arms Dealer Inc");
        assertTrue(instance.sanctionedEntities("Arms Dealer Inc"));
    }

    // ── Exporter License Views ──────────────────────────────────────────────

    function test_GetExporterLicenses() public {
        _applyLicense();
        _applyLicense();

        uint256[] memory ids = instance.getExporterLicenses(exporter);
        assertEq(ids.length, 2);
    }

    // ── Pause ───────────────────────────────────────────────────────────────

    function test_PausePreventsLicenseApplication() public {
        vm.prank(admin);
        instance.pause();

        vm.prank(exporter);
        vm.expectRevert();
        instance.applyForLicense(
            importer, "US", "DE",
            ArmsTradeCompliance.CommodityType.Agriculture,
            "grain", "10.01", 1000, 500_000, ""
        );
    }
}
