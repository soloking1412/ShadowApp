// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/FreeTradeRegistry.sol";

contract FreeTradeRegistryTest is Test {
    FreeTradeRegistry instance;
    address admin = address(1);
    address exporter = address(2);
    address importer = address(3);
    address broker = address(4);
    address thirdParty = address(5);

    function setUp() public {
        FreeTradeRegistry impl = new FreeTradeRegistry();
        bytes memory init = abi.encodeCall(FreeTradeRegistry.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = FreeTradeRegistry(address(proxy));
    }

    // ── Broker Management ──────────────────────────────────────────────────

    function test_AuthorizeBroker() public {
        vm.prank(admin);
        instance.authorizeBroker(broker, true);
        assertTrue(instance.authorizedBrokers(broker));
    }

    function test_RevokeBroker() public {
        vm.prank(admin);
        instance.authorizeBroker(broker, true);
        vm.prank(admin);
        instance.authorizeBroker(broker, false);
        assertFalse(instance.authorizedBrokers(broker));
    }

    // ── Create Agreement ───────────────────────────────────────────────────

    function _createAgreement() internal returns (uint256 agreementId) {
        uint8[] memory comms = new uint8[](2);
        comms[0] = uint8(FreeTradeRegistry.CommodityType.Gold);
        comms[1] = uint8(FreeTradeRegistry.CommodityType.Lithium);

        vm.prank(exporter);
        agreementId = instance.createAgreement(
            importer,
            broker,
            "NG",
            "US",
            "SGM Global Brokers",
            comms,
            1_000_000 * 1e18,
            uint8(FreeTradeRegistry.Incoterms.FOB),
            uint8(FreeTradeRegistry.PaymentTerms.Net30),
            block.timestamp + 1 days,
            block.timestamp + 365 days
        );
    }

    function test_CreateAgreement() public {
        uint256 id = _createAgreement();

        assertEq(id, 1);
        assertEq(instance.agreementCounter(), 1);

        FreeTradeRegistry.TradeAgreement memory a = instance.getAgreement(1);
        assertEq(a.exporter, exporter);
        assertEq(a.importer, importer);
        assertEq(a.broker, broker);
        assertEq(a.totalValueOICD, 1_000_000 * 1e18);
        assertEq(uint8(a.status), uint8(FreeTradeRegistry.AgreementStatus.Draft));
        assertFalse(a.exporterSigned);
        assertFalse(a.importerSigned);
    }

    function test_CreateAgreementInvalidImporterReverts() public {
        uint8[] memory comms = new uint8[](1);
        comms[0] = 0;

        vm.prank(exporter);
        vm.expectRevert("Invalid importer");
        instance.createAgreement(
            address(0),
            broker,
            "NG",
            "US",
            "SGM",
            comms,
            1_000_000 * 1e18,
            0,
            0,
            block.timestamp + 1 days,
            block.timestamp + 365 days
        );
    }

    function test_CreateAgreementInvalidDatesReverts() public {
        uint8[] memory comms = new uint8[](1);
        comms[0] = 0;

        vm.prank(exporter);
        vm.expectRevert("Invalid dates");
        instance.createAgreement(
            importer,
            broker,
            "NG",
            "US",
            "SGM",
            comms,
            1_000_000 * 1e18,
            0,
            0,
            block.timestamp + 365 days,  // effective after expiry
            block.timestamp + 1 days
        );
    }

    // ── Sign Agreement ─────────────────────────────────────────────────────

    function test_ExporterSigns() public {
        uint256 id = _createAgreement();

        vm.prank(exporter);
        instance.signAgreement(id);

        FreeTradeRegistry.TradeAgreement memory a = instance.getAgreement(id);
        assertTrue(a.exporterSigned);
        assertFalse(a.importerSigned);
        assertEq(uint8(a.status), uint8(FreeTradeRegistry.AgreementStatus.PendingSignature));
    }

    function test_BothPartiesSign() public {
        uint256 id = _createAgreement();

        vm.prank(exporter);
        instance.signAgreement(id);

        vm.prank(importer);
        instance.signAgreement(id);

        FreeTradeRegistry.TradeAgreement memory a = instance.getAgreement(id);
        assertTrue(a.exporterSigned);
        assertTrue(a.importerSigned);
        assertEq(uint8(a.status), uint8(FreeTradeRegistry.AgreementStatus.Active));
        assertEq(instance.totalActiveAgreements(), 1);
        assertEq(instance.totalTradeValueOICD(), 1_000_000 * 1e18);
    }

    function test_ThirdPartySignReverts() public {
        uint256 id = _createAgreement();

        vm.prank(thirdParty);
        vm.expectRevert("Not a party");
        instance.signAgreement(id);
    }

    // ── Bill of Lading ─────────────────────────────────────────────────────

    function _activateAgreement() internal returns (uint256 id) {
        id = _createAgreement();
        vm.prank(exporter);
        instance.signAgreement(id);
        vm.prank(importer);
        instance.signAgreement(id);
    }

    function test_IssueBillOfLading() public {
        uint256 agreeId = _activateAgreement();

        vm.prank(exporter);
        uint256 bolId = instance.issueBillOfLading(
            agreeId,
            "BOL-2024-001",
            "Acme Corp",
            "Notify Party",
            "MV Obsidian",
            "Lagos Port",
            "New York Port",
            uint8(FreeTradeRegistry.CommodityType.Gold),
            "Raw Gold Ore - 5 metric tons",
            5000,
            5_000_000,
            500_000 * 1e18,
            uint8(FreeTradeRegistry.Incoterms.FOB)
        );

        assertEq(bolId, 1);
        assertEq(instance.bolCounter(), 1);

        FreeTradeRegistry.BillOfLading memory bol = instance.getBOL(bolId);
        assertEq(bol.bolNumber, "BOL-2024-001");
        assertEq(bol.exporter, exporter);
        assertEq(bol.vesselName, "MV Obsidian");
        assertTrue(bol.signed);

        // Agreement should reference the BOL
        FreeTradeRegistry.TradeAgreement memory a = instance.getAgreement(agreeId);
        assertEq(a.bolId, bolId);
    }

    function test_IssueBOLNotActiveReverts() public {
        uint256 id = _createAgreement(); // Draft only

        vm.prank(exporter);
        vm.expectRevert("Agreement not active");
        instance.issueBillOfLading(
            id, "BOL-001", "cons", "notify", "vessel", "portA", "portB",
            0, "goods", 100, 1000, 1000 * 1e18, 0
        );
    }

    function test_IssueBOLNonExporterReverts() public {
        uint256 agreeId = _activateAgreement();

        vm.prank(importer); // not the exporter
        vm.expectRevert("Only exporter");
        instance.issueBillOfLading(
            agreeId, "BOL-001", "cons", "notify", "vessel", "portA", "portB",
            0, "goods", 100, 1000, 1000 * 1e18, 0
        );
    }

    // ── WTO/OZF Registration ────────────────────────────────────────────────

    function test_RegisterWithAuthorities() public {
        uint256 agreeId = _activateAgreement();

        vm.prank(admin);
        instance.registerWithAuthorities(agreeId, true, true, "WTO-2024-REF-001");

        FreeTradeRegistry.TradeAgreement memory a = instance.getAgreement(agreeId);
        assertTrue(a.registeredWithWTO);
        assertTrue(a.registeredWithOZF);
        assertEq(a.wtoFilingRef, "WTO-2024-REF-001");
    }

    function test_RegisterNotActiveReverts() public {
        uint256 id = _createAgreement(); // Draft

        vm.prank(admin);
        vm.expectRevert("Agreement not active");
        instance.registerWithAuthorities(id, true, false, "ref");
    }

    // ── Complete & Dispute ─────────────────────────────────────────────────

    function test_CompleteAgreement() public {
        uint256 agreeId = _activateAgreement();

        vm.prank(exporter);
        instance.completeAgreement(agreeId);

        FreeTradeRegistry.TradeAgreement memory a = instance.getAgreement(agreeId);
        assertEq(uint8(a.status), uint8(FreeTradeRegistry.AgreementStatus.Completed));
        assertEq(instance.totalActiveAgreements(), 0);
    }

    function test_RaiseDispute() public {
        uint256 agreeId = _activateAgreement();

        vm.prank(importer);
        instance.raiseDispute(agreeId, "Goods not delivered");

        FreeTradeRegistry.TradeAgreement memory a = instance.getAgreement(agreeId);
        assertEq(uint8(a.status), uint8(FreeTradeRegistry.AgreementStatus.Disputed));
    }

    function test_RaiseDisputeByThirdPartyReverts() public {
        uint256 agreeId = _activateAgreement();

        vm.prank(thirdParty);
        vm.expectRevert("Not a party");
        instance.raiseDispute(agreeId, "fraud");
    }

    // ── Views ──────────────────────────────────────────────────────────────

    function test_GetExporterAgreements() public {
        _createAgreement();
        uint256[] memory ids = instance.getExporterAgreements(exporter);
        assertEq(ids.length, 1);
    }

    function test_GetImporterAgreements() public {
        _createAgreement();
        uint256[] memory ids = instance.getImporterAgreements(importer);
        assertEq(ids.length, 1);
    }

    function test_GetBrokerAgreements() public {
        _createAgreement();
        uint256[] memory ids = instance.getBrokerAgreements(broker);
        assertEq(ids.length, 1);
    }
}
