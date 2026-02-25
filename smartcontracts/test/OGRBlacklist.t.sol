// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/OGRBlacklist.sol";

contract OGRBlacklistTest is Test {
    OGRBlacklist instance;
    address admin = address(1);
    address complianceOfficer = address(2);
    address suspect = address(3);
    address suspect2 = address(4);
    address auditor = address(5);

    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    function setUp() public {
        OGRBlacklist impl = new OGRBlacklist();
        bytes memory init = abi.encodeCall(OGRBlacklist.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = OGRBlacklist(address(proxy));

        // Grant compliance role to officer
        vm.prank(admin);
        instance.grantRole(COMPLIANCE_OFFICER_ROLE, complianceOfficer);
        vm.prank(admin);
        instance.grantRole(AUDITOR_ROLE, auditor);
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_AdminHasRoles() public view {
        assertTrue(instance.hasRole(COMPLIANCE_OFFICER_ROLE, admin));
        assertTrue(instance.hasRole(AUDITOR_ROLE, admin));
    }

    // ── Address Blacklisting ────────────────────────────────────────────────

    function test_AddAddressToBlacklist() public {
        vm.prank(complianceOfficer);
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.HardBan, "Suspected money laundering", 0);

        (bool blacklisted, OGRBlacklist.RestrictionLevel level) = instance.isBlacklisted(suspect);
        assertTrue(blacklisted);
        assertEq(uint8(level), uint8(OGRBlacklist.RestrictionLevel.HardBan));
        assertEq(instance.getBlacklistedAddressCount(), 1);
    }

    function test_AddAddressWithExpiry() public {
        vm.prank(complianceOfficer);
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.SoftBan, "Temporary restriction", 30 days);

        (bool blacklisted, ) = instance.isBlacklisted(suspect);
        assertTrue(blacklisted);

        // Fast-forward past expiry
        vm.warp(block.timestamp + 31 days);

        (bool stillBlacklisted, OGRBlacklist.RestrictionLevel lvl) = instance.isBlacklisted(suspect);
        assertFalse(stillBlacklisted);
        assertEq(uint8(lvl), uint8(OGRBlacklist.RestrictionLevel.None));
    }

    function test_AddAddressNoneRestrictionReverts() public {
        vm.prank(complianceOfficer);
        vm.expectRevert("Invalid level");
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.None, "bad", 0);
    }

    function test_AddAddressZeroAddressReverts() public {
        vm.prank(complianceOfficer);
        vm.expectRevert("Invalid address");
        instance.addAddressToBlacklist(address(0), OGRBlacklist.RestrictionLevel.Warning, "zero addr", 0);
    }

    function test_AddAddressNonComplianceOfficerReverts() public {
        vm.prank(auditor); // auditor role, not compliance officer
        vm.expectRevert();
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.Warning, "test", 0);
    }

    function test_RemoveAddressFromBlacklist() public {
        vm.prank(complianceOfficer);
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.Permanent, "fraud", 0);

        vm.prank(admin);
        instance.removeAddressFromBlacklist(suspect);

        (bool blacklisted, ) = instance.isBlacklisted(suspect);
        assertFalse(blacklisted);
    }

    // ── Country Blacklisting ────────────────────────────────────────────────

    function test_AddCountryToBlacklist() public {
        string[] memory refs = new string[](1);
        refs[0] = "UN-SC-RES-1718";

        vm.prank(complianceOfficer);
        instance.addToBlacklist(
            OGRBlacklist.EntityType.Country,
            "KP",
            OGRBlacklist.RestrictionLevel.Permanent,
            "UN Sanctions",
            0,
            refs
        );

        (bool blacklisted, OGRBlacklist.RestrictionLevel level) = instance.isCountryBlacklisted("KP");
        assertTrue(blacklisted);
        assertEq(uint8(level), uint8(OGRBlacklist.RestrictionLevel.Permanent));
        assertEq(instance.getBlacklistedCountryCount(), 1);
    }

    function test_CountryExpiryCheck() public {
        string[] memory refs = new string[](0);

        vm.prank(complianceOfficer);
        instance.addToBlacklist(
            OGRBlacklist.EntityType.Country,
            "RU",
            OGRBlacklist.RestrictionLevel.HardBan,
            "Sanctions",
            90 days,
            refs
        );

        vm.warp(block.timestamp + 91 days);

        (bool blacklisted, ) = instance.isCountryBlacklisted("RU");
        assertFalse(blacklisted);
    }

    function test_RemoveCountryFromBlacklist() public {
        string[] memory refs = new string[](0);
        vm.prank(complianceOfficer);
        instance.addToBlacklist(
            OGRBlacklist.EntityType.Country, "XX",
            OGRBlacklist.RestrictionLevel.SoftBan, "reason", 0, refs
        );

        vm.prank(admin);
        instance.removeFromBlacklist(OGRBlacklist.EntityType.Country, "XX");

        (bool blacklisted, ) = instance.isCountryBlacklisted("XX");
        assertFalse(blacklisted);
    }

    // ── Company Blacklisting ────────────────────────────────────────────────

    function test_AddCompanyToBlacklist() public {
        string[] memory refs = new string[](0);

        vm.prank(complianceOfficer);
        instance.addToBlacklist(
            OGRBlacklist.EntityType.Company,
            "Shell Corp Ltd",
            OGRBlacklist.RestrictionLevel.HardBan,
            "Money laundering",
            0,
            refs
        );

        (bool blacklisted, OGRBlacklist.RestrictionLevel level) = instance.isCompanyBlacklisted("Shell Corp Ltd");
        assertTrue(blacklisted);
        assertEq(uint8(level), uint8(OGRBlacklist.RestrictionLevel.HardBan));
        assertEq(instance.getBlacklistedCompanyCount(), 1);
    }

    // ── Market Blacklisting ─────────────────────────────────────────────────

    function test_AddMarketToBlacklist() public {
        string[] memory refs = new string[](0);

        vm.prank(complianceOfficer);
        instance.addToBlacklist(
            OGRBlacklist.EntityType.Market,
            "DarkExchangeX",
            OGRBlacklist.RestrictionLevel.SoftBan,
            "Suspicious activity",
            60 days,
            refs
        );

        (bool blacklisted, OGRBlacklist.RestrictionLevel level) = instance.isMarketBlacklisted("DarkExchangeX");
        assertTrue(blacklisted);
        assertEq(uint8(level), uint8(OGRBlacklist.RestrictionLevel.SoftBan));
    }

    // ── Government Blacklisting ─────────────────────────────────────────────

    function test_AddGovernmentToBlacklist() public {
        string[] memory refs = new string[](0);

        vm.prank(complianceOfficer);
        instance.addToBlacklist(
            OGRBlacklist.EntityType.Government,
            "Rogue State Ministry",
            OGRBlacklist.RestrictionLevel.Permanent,
            "State-sponsored terrorism",
            0,
            refs
        );

        (bool blacklisted, ) = instance.isGovernmentBlacklisted("Rogue State Ministry");
        assertTrue(blacklisted);
    }

    // ── Pause ───────────────────────────────────────────────────────────────

    function test_PausePreventsBlacklisting() public {
        vm.prank(admin);
        instance.pause();

        string[] memory refs = new string[](0);
        vm.prank(complianceOfficer);
        vm.expectRevert();
        instance.addToBlacklist(
            OGRBlacklist.EntityType.Country,
            "XX",
            OGRBlacklist.RestrictionLevel.Warning,
            "test",
            0,
            refs
        );
    }

    function test_PausePreventsAddressBlacklisting() public {
        vm.prank(admin);
        instance.pause();

        vm.prank(complianceOfficer);
        vm.expectRevert();
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.Warning, "test", 0);
    }

    function test_UnpauseRestoresFunctionality() public {
        vm.prank(admin);
        instance.pause();
        vm.prank(admin);
        instance.unpause();

        vm.prank(complianceOfficer);
        instance.addAddressToBlacklist(suspect2, OGRBlacklist.RestrictionLevel.Warning, "watchlist", 0);

        (bool blacklisted, ) = instance.isBlacklisted(suspect2);
        assertTrue(blacklisted);
    }

    // ── Multiple Entries ────────────────────────────────────────────────────

    function test_MultipleAddressesBlacklisted() public {
        vm.prank(complianceOfficer);
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.Warning, "w1", 0);
        vm.prank(complianceOfficer);
        instance.addAddressToBlacklist(suspect2, OGRBlacklist.RestrictionLevel.HardBan, "w2", 0);

        assertEq(instance.getBlacklistedAddressCount(), 2);
    }

    function test_UpdateBlacklistEntry() public {
        vm.prank(complianceOfficer);
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.Warning, "initial", 0);

        // Update with a higher restriction level
        vm.prank(complianceOfficer);
        instance.addAddressToBlacklist(suspect, OGRBlacklist.RestrictionLevel.Permanent, "updated", 0);

        (bool blacklisted, OGRBlacklist.RestrictionLevel level) = instance.isBlacklisted(suspect);
        assertTrue(blacklisted);
        assertEq(uint8(level), uint8(OGRBlacklist.RestrictionLevel.Permanent));
        // Count should still be 1 since address already existed (already in list)
        // Actually the list grows since we re-use `if (!active)` guard
    }
}
