// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/InviteManager.sol";

contract InviteManagerTest is Test {
    InviteManager instance;
    address chairman = address(1);
    address invitee1 = address(2);
    address invitee2 = address(3);
    address invitee3 = address(4);
    address unauthorized = address(5);

    bytes32 public constant CHAIRMAN_ROLE = keccak256("CHAIRMAN_ROLE");
    bytes32 public constant INVITE_ISSUER_ROLE = keccak256("INVITE_ISSUER_ROLE");

    function setUp() public {
        InviteManager impl = new InviteManager();
        bytes memory init = abi.encodeCall(InviteManager.initialize, (chairman));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = InviteManager(address(proxy));
    }

    // ── Initialization ──────────────────────────────────────────────────────

    function test_ChairmanHasRoles() public view {
        assertTrue(instance.hasRole(CHAIRMAN_ROLE, chairman));
        assertTrue(instance.hasRole(INVITE_ISSUER_ROLE, chairman));
    }

    function test_InviteDuration() public view {
        assertEq(instance.INVITE_DURATION(), 30 days);
    }

    // ── Issue Invite ────────────────────────────────────────────────────────

    function _issueInvite(address _invitee, InviteManager.AccessTier tier) internal returns (bytes32 inviteCode) {
        string[] memory contracts = new string[](2);
        contracts[0] = "OICDTreasury";
        contracts[1] = "SovereignDEX";

        vm.prank(chairman);
        inviteCode = instance.issueInvite(_invitee, tier, contracts);
    }

    function test_IssueInvite() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Institutional);

        assertNotEq(code, bytes32(0));

        (
            address invitee,
            address issuer,
            InviteManager.AccessTier tier,
            InviteManager.InviteStatus status,
            uint256 issuedAt,
            uint256 expiresAt
        ) = instance.getInviteDetails(code);

        assertEq(invitee, invitee1);
        assertEq(issuer, chairman);
        assertEq(uint8(tier), uint8(InviteManager.AccessTier.Institutional));
        assertEq(uint8(status), uint8(InviteManager.InviteStatus.Pending));
        assertGt(issuedAt, 0);
        assertEq(expiresAt, issuedAt + 30 days);
    }

    function test_IssueInviteNonChairmanReverts() public {
        string[] memory contracts = new string[](0);

        vm.prank(unauthorized);
        vm.expectRevert();
        instance.issueInvite(invitee1, InviteManager.AccessTier.Basic, contracts);
    }

    function test_IssueInviteZeroAddressReverts() public {
        string[] memory contracts = new string[](0);

        vm.prank(chairman);
        vm.expectRevert("Invalid address");
        instance.issueInvite(address(0), InviteManager.AccessTier.Basic, contracts);
    }

    function test_MultipleInvitesTracked() public {
        _issueInvite(invitee1, InviteManager.AccessTier.Basic);
        _issueInvite(invitee1, InviteManager.AccessTier.VIP);

        bytes32[] memory codes = instance.getUserInvites(invitee1);
        assertEq(codes.length, 2);
    }

    // ── Accept Invite ───────────────────────────────────────────────────────

    function test_AcceptInvite() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Institutional);

        vm.prank(invitee1);
        instance.acceptInvite(code);

        assertTrue(instance.isWhitelisted(invitee1));

        InviteManager.AccessTier tier = instance.getUserAccessTier(invitee1);
        assertEq(uint8(tier), uint8(InviteManager.AccessTier.Institutional));

        // Verify invite status updated
        (, , , InviteManager.InviteStatus status, , ) = instance.getInviteDetails(code);
        assertEq(uint8(status), uint8(InviteManager.InviteStatus.Accepted));
    }

    function test_AcceptInviteWrongAddressReverts() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Basic);

        vm.prank(invitee2); // not the invitee
        vm.expectRevert("Not your invite");
        instance.acceptInvite(code);
    }

    function test_AcceptExpiredInviteReverts() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Basic);

        // Fast-forward past expiry
        vm.warp(block.timestamp + 31 days);

        vm.prank(invitee1);
        vm.expectRevert("Invite expired");
        instance.acceptInvite(code);
    }

    function test_AcceptAlreadyAcceptedReverts() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Basic);

        vm.prank(invitee1);
        instance.acceptInvite(code);

        vm.prank(invitee1);
        vm.expectRevert("Already processed");
        instance.acceptInvite(code);
    }

    // ── Revoke Invite ───────────────────────────────────────────────────────

    function test_RevokeInvite() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Government);

        vm.prank(chairman);
        instance.revokeInvite(code);

        (
            ,
            ,
            ,
            ,
            InviteManager.InviteStatus _inviteStatus,
            ,
            ,
            ,
            bool _inviteActive
        ) = instance.invites(code);
        assertEq(uint8(_inviteStatus), uint8(InviteManager.InviteStatus.Revoked));
        assertFalse(_inviteActive);
    }

    function test_RevokeAlreadyAcceptedReverts() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Basic);
        vm.prank(invitee1);
        instance.acceptInvite(code);

        vm.prank(chairman);
        vm.expectRevert("Cannot revoke");
        instance.revokeInvite(code);
    }

    function test_AcceptRevokedInviteReverts() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Basic);

        vm.prank(chairman);
        instance.revokeInvite(code);

        vm.prank(invitee1);
        vm.expectRevert("Invalid invite");
        instance.acceptInvite(code);
    }

    // ── Whitelist Management ────────────────────────────────────────────────

    function test_RemoveFromWhitelist() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.VIP);
        vm.prank(invitee1);
        instance.acceptInvite(code);

        assertTrue(instance.isWhitelisted(invitee1));

        vm.prank(chairman);
        instance.removeFromWhitelist(invitee1);

        assertFalse(instance.isWhitelisted(invitee1));
    }

    function test_GetUserAccessTierNotWhitelistedReverts() public {
        vm.expectRevert("Not whitelisted");
        instance.getUserAccessTier(invitee1);
    }

    // ── Contract Access ─────────────────────────────────────────────────────

    function test_HasAccessToAllowedContract() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Institutional);
        vm.prank(invitee1);
        instance.acceptInvite(code);

        assertTrue(instance.hasAccessToContract(invitee1, "OICDTreasury"));
        assertTrue(instance.hasAccessToContract(invitee1, "SovereignDEX"));
    }

    function test_NoAccessToUnallowedContract() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Institutional);
        vm.prank(invitee1);
        instance.acceptInvite(code);

        assertFalse(instance.hasAccessToContract(invitee1, "DarkPool")); // not in allowed list
    }

    function test_NoAccessWhenNotWhitelisted() public view {
        assertFalse(instance.hasAccessToContract(invitee1, "OICDTreasury"));
    }

    // ── VIP Tier ────────────────────────────────────────────────────────────

    function test_VIPTierAccess() public {
        string[] memory contracts = new string[](1);
        contracts[0] = "AllContracts";

        vm.prank(chairman);
        bytes32 code = instance.issueInvite(invitee2, InviteManager.AccessTier.VIP, contracts);

        vm.prank(invitee2);
        instance.acceptInvite(code);

        assertEq(uint8(instance.getUserAccessTier(invitee2)), uint8(InviteManager.AccessTier.VIP));
    }

    // ── Pause ───────────────────────────────────────────────────────────────

    function test_PausePreventsIssuing() public {
        vm.prank(chairman);
        instance.pause();

        string[] memory contracts = new string[](0);
        vm.prank(chairman);
        vm.expectRevert();
        instance.issueInvite(invitee1, InviteManager.AccessTier.Basic, contracts);
    }

    function test_PausePreventsAccepting() public {
        bytes32 code = _issueInvite(invitee1, InviteManager.AccessTier.Basic);

        vm.prank(chairman);
        instance.pause();

        vm.prank(invitee1);
        vm.expectRevert();
        instance.acceptInvite(code);
    }

    function test_UnpauseRestoresFunctionality() public {
        vm.prank(chairman);
        instance.pause();
        vm.prank(chairman);
        instance.unpause();

        bytes32 code = _issueInvite(invitee3, InviteManager.AccessTier.Government);
        assertNotEq(code, bytes32(0));
    }

    // ── Unique Codes ────────────────────────────────────────────────────────

    function test_InviteCodesAreUnique() public {
        bytes32 code1 = _issueInvite(invitee1, InviteManager.AccessTier.Basic);
        bytes32 code2 = _issueInvite(invitee2, InviteManager.AccessTier.Basic);
        assertNotEq(code1, code2);
    }
}
