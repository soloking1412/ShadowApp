// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title PublicBrokerRegistry — On-chain broker onboarding and licensing
/// @notice Registers financial brokers, tracks their compliance status,
///         licensing tier, performance metrics, and client relationships.
contract PublicBrokerRegistry is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    enum BrokerStatus { Pending, Active, Suspended, Revoked }
    enum LicenseTier  { Retail, Institutional, Prime, Sovereign }

    struct Broker {
        uint256 brokerId;
        address wallet;
        string  companyName;
        string  registrationNumber;
        string  jurisdiction;
        string  licenseNumber;
        LicenseTier tier;
        BrokerStatus status;
        uint256 registeredAt;
        uint256 approvedAt;
        uint256 totalClientsOnboarded;
        uint256 totalVolumeHandled;   // in wei
        uint256 complianceScore;      // 0-100
        bool    kycVerified;
        bool    amlVerified;
        string  websiteUrl;
        string  contactEmail;
    }

    struct ClientRelationship {
        address client;
        uint256 brokerId;
        uint256 startDate;
        bool    active;
    }

    uint256 public brokerCounter;
    uint256 public activeBrokers;
    uint256 public totalVolumeProcessed;

    mapping(uint256 => Broker) public brokers;
    mapping(address => uint256) public walletToBrokerId;   // wallet → brokerId
    mapping(address => uint256) public clientToBrokerId;   // client → assigned broker
    mapping(uint256 => address[]) public brokerClients;
    mapping(address => ClientRelationship) public clientRelationships;

    event BrokerRegistered(uint256 indexed brokerId, address indexed wallet, string companyName, LicenseTier tier);
    event BrokerApproved(uint256 indexed brokerId, uint256 approvedAt);
    event BrokerSuspended(uint256 indexed brokerId, string reason);
    event BrokerRevoked(uint256 indexed brokerId, string reason);
    event ClientOnboarded(uint256 indexed brokerId, address indexed client);
    event ComplianceUpdated(uint256 indexed brokerId, bool kycVerified, bool amlVerified, uint256 score);
    event VolumeRecorded(uint256 indexed brokerId, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    // ─── REGISTER ─────────────────────────────────────────────────────────────

    function registerBroker(
        string calldata companyName,
        string calldata registrationNumber,
        string calldata jurisdiction,
        string calldata licenseNumber,
        LicenseTier tier,
        string calldata websiteUrl,
        string calldata contactEmail
    ) external returns (uint256 brokerId) {
        require(walletToBrokerId[msg.sender] == 0, "Already registered");
        require(bytes(companyName).length > 0, "Name required");
        require(bytes(registrationNumber).length > 0, "Reg number required");

        brokerId = ++brokerCounter;
        brokers[brokerId] = Broker({
            brokerId: brokerId,
            wallet: msg.sender,
            companyName: companyName,
            registrationNumber: registrationNumber,
            jurisdiction: jurisdiction,
            licenseNumber: licenseNumber,
            tier: tier,
            status: BrokerStatus.Pending,
            registeredAt: block.timestamp,
            approvedAt: 0,
            totalClientsOnboarded: 0,
            totalVolumeHandled: 0,
            complianceScore: 50,
            kycVerified: false,
            amlVerified: false,
            websiteUrl: websiteUrl,
            contactEmail: contactEmail
        });

        walletToBrokerId[msg.sender] = brokerId;
        emit BrokerRegistered(brokerId, msg.sender, companyName, tier);
    }

    // ─── ADMIN CONTROLS ───────────────────────────────────────────────────────

    function approveBroker(uint256 brokerId) external onlyOwner {
        Broker storage b = brokers[brokerId];
        require(b.status == BrokerStatus.Pending, "Not pending");

        b.status = BrokerStatus.Active;
        b.approvedAt = block.timestamp;
        activeBrokers++;

        emit BrokerApproved(brokerId, block.timestamp);
    }

    function suspendBroker(uint256 brokerId, string calldata reason) external onlyOwner {
        Broker storage b = brokers[brokerId];
        require(b.status == BrokerStatus.Active, "Not active");

        b.status = BrokerStatus.Suspended;
        activeBrokers--;

        emit BrokerSuspended(brokerId, reason);
    }

    function revokeBroker(uint256 brokerId, string calldata reason) external onlyOwner {
        Broker storage b = brokers[brokerId];
        require(b.status != BrokerStatus.Revoked, "Already revoked");
        if (b.status == BrokerStatus.Active) activeBrokers--;

        b.status = BrokerStatus.Revoked;
        emit BrokerRevoked(brokerId, reason);
    }

    function updateCompliance(
        uint256 brokerId,
        bool kycVerified,
        bool amlVerified,
        uint256 complianceScore
    ) external onlyOwner {
        require(complianceScore <= 100, "Score > 100");
        Broker storage b = brokers[brokerId];
        b.kycVerified = kycVerified;
        b.amlVerified = amlVerified;
        b.complianceScore = complianceScore;

        emit ComplianceUpdated(brokerId, kycVerified, amlVerified, complianceScore);
    }

    // ─── CLIENT OPERATIONS ────────────────────────────────────────────────────

    function onboardClient(address client) external {
        uint256 brokerId = walletToBrokerId[msg.sender];
        require(brokerId != 0, "Not a broker");
        require(brokers[brokerId].status == BrokerStatus.Active, "Broker not active");
        require(clientToBrokerId[client] == 0, "Client already assigned");

        clientToBrokerId[client] = brokerId;
        brokerClients[brokerId].push(client);
        brokers[brokerId].totalClientsOnboarded++;

        clientRelationships[client] = ClientRelationship({
            client: client,
            brokerId: brokerId,
            startDate: block.timestamp,
            active: true
        });

        emit ClientOnboarded(brokerId, client);
    }

    function recordVolume(uint256 brokerId, uint256 amount) external onlyOwner {
        brokers[brokerId].totalVolumeHandled += amount;
        totalVolumeProcessed += amount;
        emit VolumeRecorded(brokerId, amount);
    }

    // ─── VIEWS ────────────────────────────────────────────────────────────────

    function getBroker(uint256 brokerId) external view returns (Broker memory) {
        return brokers[brokerId];
    }

    function getBrokerByWallet(address wallet) external view returns (Broker memory) {
        uint256 id = walletToBrokerId[wallet];
        return brokers[id];
    }

    function getBrokerClients(uint256 brokerId) external view returns (address[] memory) {
        return brokerClients[brokerId];
    }

    function getClientBroker(address client) external view returns (Broker memory) {
        uint256 id = clientToBrokerId[client];
        return brokers[id];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
