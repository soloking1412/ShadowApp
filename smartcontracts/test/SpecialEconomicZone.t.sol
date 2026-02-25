// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/SpecialEconomicZone.sol";

contract SpecialEconomicZoneTest is Test {
    SpecialEconomicZone instance;

    address admin     = address(1);
    address authority = address(2);
    address customs   = address(3);
    address enterprise1Owner = address(4);
    address enterprise2Owner = address(5);
    address nobody    = address(6);

    string[] emptyActivities;

    function setUp() public {
        SpecialEconomicZone impl = new SpecialEconomicZone();
        bytes memory init = abi.encodeCall(SpecialEconomicZone.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = SpecialEconomicZone(address(proxy));

        // Grant additional roles
        vm.startPrank(admin);
        instance.grantRole(instance.SEZ_AUTHORITY_ROLE(), authority);
        instance.grantRole(instance.CUSTOMS_ROLE(), customs);
        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // 1. Initialization
    // -----------------------------------------------------------------------
    function test_Initialization() public view {
        assertTrue(instance.hasRole(instance.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.SEZ_AUTHORITY_ROLE(), admin));
        assertTrue(instance.hasRole(instance.CUSTOMS_ROLE(), admin));
        assertEq(instance.zoneCounter(), 0);
        assertEq(instance.enterpriseCounter(), 0);
        assertEq(instance.customsCounter(), 0);
        assertEq(instance.incentiveCounter(), 0);
        assertEq(instance.totalSEZInvestment(), 0);
        assertEq(instance.totalEmployment(), 0);
        assertEq(instance.totalTradeValue(), 0);
    }

    // -----------------------------------------------------------------------
    // 2. SEZ Establishment
    // -----------------------------------------------------------------------
    function test_EstablishSEZ() public {
        string[] memory activities = new string[](2);
        activities[0] = "Manufacturing";
        activities[1] = "Logistics";

        vm.expectEmit(true, false, false, true);
        emit SpecialEconomicZone.SEZEstablished(
            1,
            SpecialEconomicZone.SEZType.FreeTrade,
            "OZF Free Trade Zone",
            "Abu Dhabi"
        );

        vm.prank(authority);
        uint256 zoneId = instance.establishSEZ(
            SpecialEconomicZone.SEZType.FreeTrade,
            "OZF Free Trade Zone",
            "Abu Dhabi",
            "AE",
            "AEAUH",
            50_000_000, // 50M m²
            activities
        );

        assertEq(zoneId, 1);
        assertEq(instance.zoneCounter(), 1);

        (
            SpecialEconomicZone.SEZType zoneType,
            string memory name,
            string memory location,
            string memory country,
            uint256 area,
            SpecialEconomicZone.ZoneStatus status,
            uint256 totalInvestment,
            uint256 employmentCount
        ) = instance.getSEZ(1);

        assertEq(uint8(zoneType), uint8(SpecialEconomicZone.SEZType.FreeTrade));
        assertEq(name, "OZF Free Trade Zone");
        assertEq(location, "Abu Dhabi");
        assertEq(country, "AE");
        assertEq(area, 50_000_000);
        assertEq(uint8(status), uint8(SpecialEconomicZone.ZoneStatus.Active));
        assertEq(totalInvestment, 0);
        assertEq(employmentCount, 0);
    }

    function test_EstablishSEZ_AllTypes() public {
        vm.startPrank(authority);
        instance.establishSEZ(SpecialEconomicZone.SEZType.ExportProcessing, "EPZ", "City A", "US", "PC1", 1_000, emptyActivities);
        instance.establishSEZ(SpecialEconomicZone.SEZType.IndustrialPark,   "IP",  "City B", "GB", "PC2", 2_000, emptyActivities);
        instance.establishSEZ(SpecialEconomicZone.SEZType.TechnologyPark,   "TP",  "City C", "DE", "PC3", 3_000, emptyActivities);
        instance.establishSEZ(SpecialEconomicZone.SEZType.FinancialCenter,  "FC",  "City D", "SG", "PC4", 4_000, emptyActivities);
        vm.stopPrank();
        assertEq(instance.zoneCounter(), 4);
    }

    function test_EstablishSEZ_Reverts_EmptyName() public {
        vm.prank(authority);
        vm.expectRevert("Invalid name");
        instance.establishSEZ(
            SpecialEconomicZone.SEZType.FreeTrade,
            "",
            "Location",
            "AE",
            "CODE",
            1_000,
            emptyActivities
        );
    }

    function test_EstablishSEZ_Reverts_ZeroArea() public {
        vm.prank(authority);
        vm.expectRevert("Invalid area");
        instance.establishSEZ(
            SpecialEconomicZone.SEZType.FreeTrade,
            "Name",
            "Location",
            "AE",
            "CODE",
            0,
            emptyActivities
        );
    }

    function test_EstablishSEZ_Reverts_NonAuthority() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.establishSEZ(
            SpecialEconomicZone.SEZType.FreeTrade,
            "Zone",
            "Loc",
            "AE",
            "C01",
            1_000,
            emptyActivities
        );
    }

    // -----------------------------------------------------------------------
    // 3. Enterprise Registration
    // -----------------------------------------------------------------------
    function _createZone() internal returns (uint256 zoneId) {
        vm.prank(authority);
        zoneId = instance.establishSEZ(
            SpecialEconomicZone.SEZType.IndustrialPark,
            "Test Zone",
            "Dubai",
            "AE",
            "DXBSEZ",
            10_000_000,
            emptyActivities
        );
    }

    function test_RegisterEnterprise() public {
        uint256 zoneId = _createZone();

        vm.expectEmit(true, true, true, true);
        emit SpecialEconomicZone.EnterpriseRegistered(
            1,
            zoneId,
            enterprise1Owner,
            "Acme Corp"
        );

        vm.prank(enterprise1Owner);
        uint256 enterpriseId = instance.registerEnterprise(
            zoneId,
            "Acme Corp",
            "REG-12345",
            "Electronics",
            5_000_000,  // investment
            200,        // employees
            365 days    // license duration
        );

        assertEq(enterpriseId, 1);
        assertEq(instance.enterpriseCounter(), 1);
        assertEq(instance.totalSEZInvestment(), 5_000_000);
        assertEq(instance.totalEmployment(), 200);

        (
            uint256 _entId,
            uint256 _entZoneId,
            address _entOwner,
            string memory _entCompanyName,
            string memory _entRegNumber,
            string memory _entIndustry,
            uint256 _entInvestment,
            uint256 _entEmployees,
            uint256 _entRegisteredDate,
            uint256 _entLicenseExpiry,
            bool _entActive
        ) = instance.enterprises(1);
        assertEq(_entOwner, enterprise1Owner);
        assertEq(_entCompanyName, "Acme Corp");
        assertEq(_entInvestment, 5_000_000);
        assertEq(_entEmployees, 200);
        assertTrue(_entActive);

        uint256[] memory zoneEnts = instance.getZoneEnterprises(zoneId);
        assertEq(zoneEnts.length, 1);
        assertEq(zoneEnts[0], 1);

        uint256[] memory ownerEnts = instance.getOwnerEnterprises(enterprise1Owner);
        assertEq(ownerEnts.length, 1);
        assertEq(ownerEnts[0], 1);
    }

    function test_RegisterEnterprise_UpdatesZoneStats() public {
        uint256 zoneId = _createZone();

        vm.prank(enterprise1Owner);
        instance.registerEnterprise(zoneId, "Corp A", "R001", "Pharma", 1_000_000, 50, 180 days);

        vm.prank(enterprise2Owner);
        instance.registerEnterprise(zoneId, "Corp B", "R002", "Logistics", 2_000_000, 100, 180 days);

        (, , , , , , uint256 totalInv, uint256 emp) = instance.getSEZ(zoneId);
        assertEq(totalInv, 3_000_000);
        assertEq(emp, 150);
    }

    function test_RegisterEnterprise_Reverts_ZoneNotActive() public {
        uint256 zoneId = _createZone();

        vm.prank(authority);
        instance.updateZoneStatus(zoneId, SpecialEconomicZone.ZoneStatus.Suspended);

        vm.prank(enterprise1Owner);
        vm.expectRevert("Zone not active");
        instance.registerEnterprise(zoneId, "Corp", "R001", "Tech", 500_000, 10, 180 days);
    }

    function test_RegisterEnterprise_Reverts_ZeroInvestment() public {
        uint256 zoneId = _createZone();

        vm.prank(enterprise1Owner);
        vm.expectRevert("Invalid investment");
        instance.registerEnterprise(zoneId, "Corp", "R001", "Tech", 0, 10, 180 days);
    }

    function test_RegisterEnterprise_Reverts_WhenPaused() public {
        uint256 zoneId = _createZone();

        vm.prank(admin);
        instance.pause();

        vm.prank(enterprise1Owner);
        vm.expectRevert();
        instance.registerEnterprise(zoneId, "Corp", "R001", "Tech", 100_000, 5, 90 days);
    }

    // -----------------------------------------------------------------------
    // 4. Customs Declarations
    // -----------------------------------------------------------------------
    function _createZoneAndEnterprise() internal returns (uint256 zoneId, uint256 enterpriseId) {
        zoneId = _createZone();
        vm.prank(enterprise1Owner);
        enterpriseId = instance.registerEnterprise(
            zoneId,
            "Trade Co",
            "TC-001",
            "Trade",
            1_000_000,
            25,
            365 days
        );
    }

    function test_FileCustomsDeclaration_Import() public {
        (uint256 zoneId, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.expectEmit(true, true, true, true);
        emit SpecialEconomicZone.CustomsDeclarationFiled(1, zoneId, enterpriseId, "Import", 500_000);

        vm.prank(enterprise1Owner);
        uint256 customsId = instance.fileCustomsDeclaration(
            zoneId,
            enterpriseId,
            "Import",
            "Electronics Components",
            "8542.31",
            1000,       // quantity
            500_000,    // value
            200,        // dutyRate (2%)
            false       // not duty exempt
        );

        assertEq(customsId, 1);
        assertEq(instance.customsCounter(), 1);
        assertEq(instance.totalTradeValue(), 500_000);

        (
            uint256 _cusId,
            uint256 _cusZoneId,
            uint256 _cusEnterpriseId,
            string memory _cusDeclType,
            string memory _cusGoodsDesc,
            string memory _cusHsCode,
            uint256 _cusQuantity,
            uint256 _cusValue,
            uint256 _cusDutyRate,
            uint256 _cusDutyAmount,
            bool _cusDutyExempt,
            uint256 _cusTimestamp,
            bool _cusCleared,
            string memory _cusClearanceRef
        ) = instance.customsDeclarations(1);
        assertEq(_cusValue, 500_000);
        assertEq(_cusDutyAmount, (500_000 * 200) / 10000); // 2% of 500_000 = 10_000
        assertFalse(_cusCleared);
        assertFalse(_cusDutyExempt);

        (uint256 imports, , , uint256 dutyCollected, ) = instance.getZoneStats(zoneId);
        assertEq(imports, 500_000);
        assertEq(dutyCollected, 10_000);
    }

    function test_FileCustomsDeclaration_Export() public {
        (uint256 zoneId, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.prank(enterprise1Owner);
        instance.fileCustomsDeclaration(
            zoneId,
            enterpriseId,
            "Export",
            "Finished Goods",
            "8471.30",
            500,
            300_000,
            0,
            true // duty exempt
        );

        (, uint256 exports, , , uint256 dutyExempted) = instance.getZoneStats(zoneId);
        assertEq(exports, 300_000);
        assertEq(dutyExempted, 0); // duty is 0 because rate is 0 and exempt doesn't matter
    }

    function test_FileCustomsDeclaration_Transit() public {
        (uint256 zoneId, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.prank(enterprise1Owner);
        instance.fileCustomsDeclaration(
            zoneId,
            enterpriseId,
            "Transit",
            "Transit Cargo",
            "9999.00",
            200,
            100_000,
            0,
            true
        );

        (, , uint256 transit, , ) = instance.getZoneStats(zoneId);
        assertEq(transit, 100_000);
    }

    function test_FileCustomsDeclaration_Reverts_NotOwner() public {
        (uint256 zoneId, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.prank(nobody);
        vm.expectRevert("Not enterprise owner");
        instance.fileCustomsDeclaration(
            zoneId,
            enterpriseId,
            "Import",
            "Goods",
            "1234.56",
            100,
            50_000,
            100,
            false
        );
    }

    // -----------------------------------------------------------------------
    // 5. Customs Clearance
    // -----------------------------------------------------------------------
    function test_ClearCustoms() public {
        (uint256 zoneId, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.prank(enterprise1Owner);
        uint256 customsId = instance.fileCustomsDeclaration(
            zoneId,
            enterpriseId,
            "Import",
            "Machinery",
            "8425.11",
            5,
            2_000_000,
            150,
            false
        );

        vm.expectEmit(true, false, false, true);
        emit SpecialEconomicZone.CustomsCleared(customsId, "CLEAR-2025-001");

        vm.prank(customs);
        instance.clearCustoms(customsId, "CLEAR-2025-001");

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            bool _cleared,
            string memory _clearanceRef
        ) = instance.customsDeclarations(customsId);
        assertTrue(_cleared);
        assertEq(_clearanceRef, "CLEAR-2025-001");
    }

    function test_ClearCustoms_Reverts_AlreadyCleared() public {
        (uint256 zoneId, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.prank(enterprise1Owner);
        uint256 customsId = instance.fileCustomsDeclaration(
            zoneId, enterpriseId, "Import", "Goods", "1234", 1, 10_000, 0, true
        );

        vm.startPrank(customs);
        instance.clearCustoms(customsId, "REF-001");
        vm.expectRevert("Already cleared");
        instance.clearCustoms(customsId, "REF-002");
        vm.stopPrank();
    }

    function test_ClearCustoms_Reverts_NonCustomsRole() public {
        (uint256 zoneId, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.prank(enterprise1Owner);
        uint256 customsId = instance.fileCustomsDeclaration(
            zoneId, enterpriseId, "Export", "Goods", "1234", 1, 10_000, 0, false
        );

        vm.prank(nobody);
        vm.expectRevert();
        instance.clearCustoms(customsId, "REF");
    }

    // -----------------------------------------------------------------------
    // 6. Tax Incentives
    // -----------------------------------------------------------------------
    function test_GrantIncentive() public {
        (, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.expectEmit(true, true, false, true);
        emit SpecialEconomicZone.IncentiveGranted(
            1,
            enterpriseId,
            SpecialEconomicZone.IncentiveType.TaxHoliday,
            5_000_000
        );

        vm.prank(authority);
        uint256 incentiveId = instance.grantIncentive(
            enterpriseId,
            SpecialEconomicZone.IncentiveType.TaxHoliday,
            "5-year tax holiday",
            5_000_000,
            5 * 365 days
        );

        assertEq(incentiveId, 1);
        assertEq(instance.incentiveCounter(), 1);

        (
            uint256 _incId,
            uint256 _incEnterpriseId,
            SpecialEconomicZone.IncentiveType _incType,
            string memory _incDescription,
            uint256 _incValue,
            uint256 _incStartDate,
            uint256 _incEndDate,
            bool _incActive
        ) = instance.incentives(1);
        assertEq(_incEnterpriseId, enterpriseId);
        assertEq(uint8(_incType), uint8(SpecialEconomicZone.IncentiveType.TaxHoliday));
        assertEq(_incValue, 5_000_000);
        assertTrue(_incActive);
        assertEq(_incEndDate, block.timestamp + 5 * 365 days);
    }

    function test_GrantIncentive_AllTypes() public {
        (, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.startPrank(authority);
        instance.grantIncentive(enterpriseId, SpecialEconomicZone.IncentiveType.DutyExemption,  "Duty", 100, 365 days);
        instance.grantIncentive(enterpriseId, SpecialEconomicZone.IncentiveType.SubsidizedLand, "Land", 200, 365 days);
        instance.grantIncentive(enterpriseId, SpecialEconomicZone.IncentiveType.UtilityRebate,  "Util", 300, 365 days);
        instance.grantIncentive(enterpriseId, SpecialEconomicZone.IncentiveType.EmploymentGrant,"Emp",  400, 365 days);
        instance.grantIncentive(enterpriseId, SpecialEconomicZone.IncentiveType.RDGrant,        "R&D", 500, 365 days);
        vm.stopPrank();

        assertEq(instance.incentiveCounter(), 5);
    }

    function test_GrantIncentive_Reverts_NonAuthority() public {
        (, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.prank(nobody);
        vm.expectRevert();
        instance.grantIncentive(
            enterpriseId,
            SpecialEconomicZone.IncentiveType.TaxHoliday,
            "Holiday",
            1_000,
            365 days
        );
    }

    // -----------------------------------------------------------------------
    // 7. Zone Status Updates
    // -----------------------------------------------------------------------
    function test_UpdateZoneStatus() public {
        uint256 zoneId = _createZone();

        vm.prank(authority);
        instance.updateZoneStatus(zoneId, SpecialEconomicZone.ZoneStatus.Suspended);

        (, , , , , SpecialEconomicZone.ZoneStatus status, , ) = instance.getSEZ(zoneId);
        assertEq(uint8(status), uint8(SpecialEconomicZone.ZoneStatus.Suspended));
    }

    function test_UpdateZoneStatus_Decommissioned() public {
        uint256 zoneId = _createZone();

        vm.prank(authority);
        instance.updateZoneStatus(zoneId, SpecialEconomicZone.ZoneStatus.Decommissioned);

        (, , , , , SpecialEconomicZone.ZoneStatus status, , ) = instance.getSEZ(zoneId);
        assertEq(uint8(status), uint8(SpecialEconomicZone.ZoneStatus.Decommissioned));
    }

    function test_UpdateZoneStatus_Reverts_NonAuthority() public {
        uint256 zoneId = _createZone();

        vm.prank(nobody);
        vm.expectRevert();
        instance.updateZoneStatus(zoneId, SpecialEconomicZone.ZoneStatus.Suspended);
    }

    // -----------------------------------------------------------------------
    // 8. Multiple enterprises across zones
    // -----------------------------------------------------------------------
    function test_MultipleEnterprisesMultipleZones() public {
        vm.startPrank(authority);
        uint256 zone1 = instance.establishSEZ(SpecialEconomicZone.SEZType.FreeTrade,    "Zone 1", "Dubai",  "AE", "DXB1", 1_000, emptyActivities);
        uint256 zone2 = instance.establishSEZ(SpecialEconomicZone.SEZType.TechnologyPark,"Zone 2", "Riyadh", "SA", "RYD1", 2_000, emptyActivities);
        vm.stopPrank();

        vm.prank(enterprise1Owner);
        instance.registerEnterprise(zone1, "Corp A", "CA-001", "Tech", 500_000, 50, 365 days);
        vm.prank(enterprise1Owner);
        instance.registerEnterprise(zone2, "Corp A Branch", "CA-002", "Tech", 300_000, 30, 365 days);
        vm.prank(enterprise2Owner);
        instance.registerEnterprise(zone1, "Corp B", "CB-001", "Logistics", 200_000, 20, 180 days);

        assertEq(instance.enterpriseCounter(), 3);
        assertEq(instance.getZoneEnterprises(zone1).length, 2);
        assertEq(instance.getZoneEnterprises(zone2).length, 1);
        assertEq(instance.getOwnerEnterprises(enterprise1Owner).length, 2);
        assertEq(instance.totalSEZInvestment(), 1_000_000);
        assertEq(instance.totalEmployment(), 100);
    }

    // -----------------------------------------------------------------------
    // 9. Pause / Unpause
    // -----------------------------------------------------------------------
    function test_PauseUnpause() public {
        vm.prank(admin);
        instance.pause();
        assertTrue(instance.paused());

        vm.prank(admin);
        instance.unpause();
        assertFalse(instance.paused());
    }

    function test_Pause_Reverts_NonAdmin() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.pause();
    }

    // -----------------------------------------------------------------------
    // 10. getZoneStats correctness
    // -----------------------------------------------------------------------
    function test_ZoneStats_Comprehensive() public {
        (uint256 zoneId, uint256 enterpriseId) = _createZoneAndEnterprise();

        vm.startPrank(enterprise1Owner);
        instance.fileCustomsDeclaration(zoneId, enterpriseId, "Import", "Good A", "1234", 10, 400_000, 250, false);
        instance.fileCustomsDeclaration(zoneId, enterpriseId, "Export", "Good B", "5678", 20, 600_000, 0, true);
        instance.fileCustomsDeclaration(zoneId, enterpriseId, "Transit","Good C", "9012", 5, 100_000, 100, false);
        vm.stopPrank();

        (
            uint256 imports,
            uint256 exports,
            uint256 transit,
            uint256 dutyCollected,
            uint256 dutyExempted
        ) = instance.getZoneStats(zoneId);

        assertEq(imports, 400_000);
        assertEq(exports, 600_000);
        assertEq(transit, 100_000);
        // dutyCollected = (400_000 * 250 / 10000) + (100_000 * 100 / 10000) = 10_000 + 1_000 = 11_000
        assertEq(dutyCollected, 11_000);
        assertEq(dutyExempted, 0); // exempt declaration has 0% duty rate so exempted amount = 0
        assertEq(instance.totalTradeValue(), 1_100_000);
    }
}
