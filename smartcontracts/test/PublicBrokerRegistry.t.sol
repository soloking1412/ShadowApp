// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/PublicBrokerRegistry.sol";

contract PublicBrokerRegistryTest is Test {
    PublicBrokerRegistry instance;
    address admin = address(1);
    address broker1 = address(2);
    address broker2 = address(3);
    address client1 = address(4);
    address client2 = address(5);

    function setUp() public {
        PublicBrokerRegistry impl = new PublicBrokerRegistry();
        bytes memory init = abi.encodeCall(PublicBrokerRegistry.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = PublicBrokerRegistry(address(proxy));
    }

    // ── Register Broker ─────────────────────────────────────────────────────

    function _registerBroker1() internal returns (uint256 brokerId) {
        vm.prank(broker1);
        brokerId = instance.registerBroker(
            "Global Capital Partners",
            "REG-2024-001",
            "US",
            "LIC-US-001",
            PublicBrokerRegistry.LicenseTier.Institutional,
            "https://gcp.com",
            "info@gcp.com"
        );
    }

    function test_RegisterBroker() public {
        uint256 brokerId = _registerBroker1();

        assertEq(brokerId, 1);
        assertEq(instance.brokerCounter(), 1);

        PublicBrokerRegistry.Broker memory b = instance.getBroker(1);
        assertEq(b.wallet, broker1);
        assertEq(b.companyName, "Global Capital Partners");
        assertEq(b.registrationNumber, "REG-2024-001");
        assertEq(b.jurisdiction, "US");
        assertEq(uint8(b.tier), uint8(PublicBrokerRegistry.LicenseTier.Institutional));
        assertEq(uint8(b.status), uint8(PublicBrokerRegistry.BrokerStatus.Pending));
        assertEq(b.complianceScore, 50); // default
        assertFalse(b.kycVerified);
        assertFalse(b.amlVerified);
    }

    function test_RegisterBrokerTwiceReverts() public {
        _registerBroker1();

        vm.prank(broker1);
        vm.expectRevert("Already registered");
        instance.registerBroker(
            "Second Firm", "REG-002", "UK", "LIC-002",
            PublicBrokerRegistry.LicenseTier.Prime,
            "https://sf.com", "sf@sf.com"
        );
    }

    function test_RegisterBrokerNoNameReverts() public {
        vm.prank(broker2);
        vm.expectRevert("Name required");
        instance.registerBroker(
            "", "REG-003", "UK", "LIC-003",
            PublicBrokerRegistry.LicenseTier.Retail,
            "https://test.com", "test@test.com"
        );
    }

    function test_RegisterBrokerNoRegNumberReverts() public {
        vm.prank(broker2);
        vm.expectRevert("Reg number required");
        instance.registerBroker(
            "Valid Name", "", "UK", "LIC-003",
            PublicBrokerRegistry.LicenseTier.Retail,
            "https://test.com", "test@test.com"
        );
    }

    function test_WalletToBrokerIdMapped() public {
        _registerBroker1();
        assertEq(instance.walletToBrokerId(broker1), 1);
    }

    // ── Approve / Suspend / Revoke Broker ──────────────────────────────────

    function test_ApproveBroker() public {
        _registerBroker1();

        vm.prank(admin);
        instance.approveBroker(1);

        PublicBrokerRegistry.Broker memory b = instance.getBroker(1);
        assertEq(uint8(b.status), uint8(PublicBrokerRegistry.BrokerStatus.Active));
        assertGt(b.approvedAt, 0);
        assertEq(instance.activeBrokers(), 1);
    }

    function test_ApproveNonPendingReverts() public {
        _registerBroker1();
        vm.prank(admin);
        instance.approveBroker(1);

        vm.prank(admin);
        vm.expectRevert("Not pending");
        instance.approveBroker(1); // already active
    }

    function test_SuspendBroker() public {
        _registerBroker1();
        vm.prank(admin);
        instance.approveBroker(1);

        vm.prank(admin);
        instance.suspendBroker(1, "Compliance review");

        PublicBrokerRegistry.Broker memory b = instance.getBroker(1);
        assertEq(uint8(b.status), uint8(PublicBrokerRegistry.BrokerStatus.Suspended));
        assertEq(instance.activeBrokers(), 0);
    }

    function test_SuspendNonActiveReverts() public {
        _registerBroker1(); // pending

        vm.prank(admin);
        vm.expectRevert("Not active");
        instance.suspendBroker(1, "reason");
    }

    function test_RevokeBroker() public {
        _registerBroker1();
        vm.prank(admin);
        instance.approveBroker(1);

        vm.prank(admin);
        instance.revokeBroker(1, "License violation");

        PublicBrokerRegistry.Broker memory b = instance.getBroker(1);
        assertEq(uint8(b.status), uint8(PublicBrokerRegistry.BrokerStatus.Revoked));
        assertEq(instance.activeBrokers(), 0);
    }

    function test_RevokeAlreadyRevokedReverts() public {
        _registerBroker1();
        vm.prank(admin);
        instance.approveBroker(1);
        vm.prank(admin);
        instance.revokeBroker(1, "reason");

        vm.prank(admin);
        vm.expectRevert("Already revoked");
        instance.revokeBroker(1, "reason2");
    }

    // ── Compliance Update ───────────────────────────────────────────────────

    function test_UpdateCompliance() public {
        _registerBroker1();

        vm.prank(admin);
        instance.updateCompliance(1, true, true, 95);

        PublicBrokerRegistry.Broker memory b = instance.getBroker(1);
        assertTrue(b.kycVerified);
        assertTrue(b.amlVerified);
        assertEq(b.complianceScore, 95);
    }

    function test_UpdateComplianceScoreAbove100Reverts() public {
        _registerBroker1();

        vm.prank(admin);
        vm.expectRevert("Score > 100");
        instance.updateCompliance(1, true, true, 101);
    }

    function test_UpdateComplianceNonOwnerReverts() public {
        _registerBroker1();

        vm.prank(broker1);
        vm.expectRevert();
        instance.updateCompliance(1, true, true, 80);
    }

    // ── Client Onboarding ───────────────────────────────────────────────────

    function test_OnboardClient() public {
        _registerBroker1();
        vm.prank(admin);
        instance.approveBroker(1);

        vm.prank(broker1);
        instance.onboardClient(client1);

        assertEq(instance.clientToBrokerId(client1), 1);

        address[] memory clients = instance.getBrokerClients(1);
        assertEq(clients.length, 1);
        assertEq(clients[0], client1);

        PublicBrokerRegistry.Broker memory b = instance.getBroker(1);
        assertEq(b.totalClientsOnboarded, 1);
    }

    function test_OnboardClientNonBrokerReverts() public {
        vm.prank(client1);
        vm.expectRevert("Not a broker");
        instance.onboardClient(client2);
    }

    function test_OnboardClientInactiveBrokerReverts() public {
        _registerBroker1(); // pending, not approved

        vm.prank(broker1);
        vm.expectRevert("Broker not active");
        instance.onboardClient(client1);
    }

    function test_OnboardClientAlreadyAssignedReverts() public {
        _registerBroker1();
        vm.prank(admin);
        instance.approveBroker(1);

        vm.prank(broker1);
        instance.onboardClient(client1);

        vm.prank(broker1);
        vm.expectRevert("Client already assigned");
        instance.onboardClient(client1); // same client
    }

    // ── Volume Recording ────────────────────────────────────────────────────

    function test_RecordVolume() public {
        _registerBroker1();

        vm.prank(admin);
        instance.recordVolume(1, 1_000_000 * 1e18);

        PublicBrokerRegistry.Broker memory b = instance.getBroker(1);
        assertEq(b.totalVolumeHandled, 1_000_000 * 1e18);
        assertEq(instance.totalVolumeProcessed(), 1_000_000 * 1e18);
    }

    function test_RecordVolumeNonOwnerReverts() public {
        _registerBroker1();

        vm.prank(broker1);
        vm.expectRevert();
        instance.recordVolume(1, 100 * 1e18);
    }

    // ── Views ──────────────────────────────────────────────────────────────

    function test_GetBrokerByWallet() public {
        _registerBroker1();

        PublicBrokerRegistry.Broker memory b = instance.getBrokerByWallet(broker1);
        assertEq(b.brokerId, 1);
        assertEq(b.companyName, "Global Capital Partners");
    }

    function test_GetClientBroker() public {
        _registerBroker1();
        vm.prank(admin);
        instance.approveBroker(1);
        vm.prank(broker1);
        instance.onboardClient(client1);

        PublicBrokerRegistry.Broker memory b = instance.getClientBroker(client1);
        assertEq(b.brokerId, 1);
    }

    function test_SovereignTierRegistration() public {
        vm.prank(broker2);
        uint256 brokerId = instance.registerBroker(
            "Sovereign Capital Fund",
            "REG-SVRN-001",
            "AE",
            "LIC-SVRN-001",
            PublicBrokerRegistry.LicenseTier.Sovereign,
            "https://scf.ae",
            "contact@scf.ae"
        );

        PublicBrokerRegistry.Broker memory b = instance.getBroker(brokerId);
        assertEq(uint8(b.tier), uint8(PublicBrokerRegistry.LicenseTier.Sovereign));
    }
}
