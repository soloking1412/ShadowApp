// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract InviteManager is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant CHAIRMAN_ROLE = keccak256("CHAIRMAN_ROLE");
    bytes32 public constant INVITE_ISSUER_ROLE = keccak256("INVITE_ISSUER_ROLE");

    enum InviteStatus { Pending, Accepted, Rejected, Expired, Revoked }
    enum AccessTier { Basic, Institutional, Government, VIP }

    struct Invite {
        bytes32 inviteCode;
        address invitee;
        address issuer;
        AccessTier tier;
        InviteStatus status;
        uint256 issuedAt;
        uint256 expiresAt;
        uint256 acceptedAt;
        string[] allowedContracts;
        bool active;
    }

    mapping(bytes32 => Invite) public invites;
    mapping(address => bytes32[]) public userInvites;
    mapping(address => AccessTier) public userAccessTier;
    mapping(address => bool) public whitelisted;

    uint256 public constant INVITE_DURATION = 30 days;
    uint256 public inviteCounter;

    event InviteIssued(bytes32 indexed inviteCode, address indexed invitee, AccessTier tier);
    event InviteAccepted(bytes32 indexed inviteCode, address indexed invitee);
    event InviteRevoked(bytes32 indexed inviteCode);
    event UserWhitelisted(address indexed user, AccessTier tier);
    event UserRemovedFromWhitelist(address indexed user);

    constructor() {
        _disableInitializers();
    }

    function initialize(address chairman) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, chairman);
        _grantRole(CHAIRMAN_ROLE, chairman);
        _grantRole(INVITE_ISSUER_ROLE, chairman);
    }

    function issueInvite(
        address invitee,
        AccessTier tier,
        string[] memory allowedContracts
    ) external onlyRole(CHAIRMAN_ROLE) whenNotPaused returns (bytes32) {
        require(invitee != address(0), "Invalid address");

        bytes32 inviteCode = keccak256(abi.encodePacked(invitee, block.timestamp, inviteCounter++, msg.sender));

        invites[inviteCode] = Invite({
            inviteCode: inviteCode,
            invitee: invitee,
            issuer: msg.sender,
            tier: tier,
            status: InviteStatus.Pending,
            issuedAt: block.timestamp,
            expiresAt: block.timestamp + INVITE_DURATION,
            acceptedAt: 0,
            allowedContracts: allowedContracts,
            active: true
        });

        userInvites[invitee].push(inviteCode);

        emit InviteIssued(inviteCode, invitee, tier);
        return inviteCode;
    }

    function acceptInvite(bytes32 inviteCode) external whenNotPaused {
        Invite storage invite = invites[inviteCode];
        require(invite.active, "Invalid invite");
        require(invite.invitee == msg.sender, "Not your invite");
        require(block.timestamp <= invite.expiresAt, "Invite expired");
        require(invite.status == InviteStatus.Pending, "Already processed");

        invite.status = InviteStatus.Accepted;
        invite.acceptedAt = block.timestamp;

        if (!whitelisted[msg.sender]) {
            userAccessTier[msg.sender] = invite.tier;
            whitelisted[msg.sender] = true;
            emit UserWhitelisted(msg.sender, invite.tier);
        }

        emit InviteAccepted(inviteCode, msg.sender);
    }

    function revokeInvite(bytes32 inviteCode) external onlyRole(CHAIRMAN_ROLE) {
        Invite storage invite = invites[inviteCode];
        require(invite.active, "Invalid invite");
        require(invite.status == InviteStatus.Pending, "Cannot revoke");

        invite.status = InviteStatus.Revoked;
        invite.active = false;

        emit InviteRevoked(inviteCode);
    }

    function removeFromWhitelist(address user) external onlyRole(CHAIRMAN_ROLE) {
        whitelisted[user] = false;
        delete userAccessTier[user];

        emit UserRemovedFromWhitelist(user);
    }

    function isWhitelisted(address user) external view returns (bool) {
        return whitelisted[user];
    }

    function getUserAccessTier(address user) external view returns (AccessTier) {
        require(whitelisted[user], "Not whitelisted");
        return userAccessTier[user];
    }

    function hasAccessToContract(address user, string memory contractName)
        external
        view
        returns (bool)
    {
        if (!whitelisted[user]) return false;

        bytes32[] memory codes = userInvites[user];
        for (uint256 i = 0; i < codes.length; i++) {
            Invite storage invite = invites[codes[i]];
            if (invite.status == InviteStatus.Accepted) {
                for (uint256 j = 0; j < invite.allowedContracts.length; j++) {
                    if (keccak256(bytes(invite.allowedContracts[j])) == keccak256(bytes(contractName))) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    function getUserInvites(address user) external view returns (bytes32[] memory) {
        return userInvites[user];
    }

    function getInviteDetails(bytes32 inviteCode)
        external
        view
        returns (
            address invitee,
            address issuer,
            AccessTier tier,
            InviteStatus status,
            uint256 issuedAt,
            uint256 expiresAt
        )
    {
        Invite storage invite = invites[inviteCode];
        return (
            invite.invitee,
            invite.issuer,
            invite.tier,
            invite.status,
            invite.issuedAt,
            invite.expiresAt
        );
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
