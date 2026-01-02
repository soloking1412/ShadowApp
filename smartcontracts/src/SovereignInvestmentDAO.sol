// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract SovereignInvestmentDAO is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MINISTRY_ROLE = keccak256("MINISTRY_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    enum MinistryType { Treasury, Finance, Infrastructure, Trade, Defense, Energy, Technology }
    enum ProposalCategory { Treasury, Infrastructure, Policy, Emergency, Upgrade, Parameter, Ministry }
    enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed }

    struct Ministry {
        address ministry;
        MinistryType ministryType;
        uint256 votingWeight;
        bool active;
        uint256 proposalsVoted;
    }

    struct Proposal {
        uint256 proposalId;
        ProposalCategory category;
        address proposer;
        uint256 budgetImpact;
        bytes32 documentHash;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        bool executed;
        bool canceled;
        bool requiresMinistryApproval;
        uint256 ministryApprovals;
        uint256 requiredMinistryApprovals;
        ProposalState state;
    }

    struct Vote {
        bool hasVoted;
        uint8 support;
        uint256 weight;
    }

    mapping(address => Ministry) public ministries;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public ministryVotes;
    mapping(uint256 => mapping(address => Vote)) public votes;
    address[] public ministryList;

    uint256 public proposalCounter;
    uint256 public votingPeriod;
    uint256 public executionDelay;
    uint256 public ministryQuorum;
    uint256 public emergencyQuorum;
    uint256 public quorumPercentage;
    bool public emergencyMode;

    mapping(MinistryType => uint256) public ministryWeights;

    event MinistryRegistered(address indexed ministry, MinistryType ministryType);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, ProposalCategory category);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, uint256 weight);
    event MinistryVoteCast(uint256 indexed proposalId, address indexed ministry, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, uint256 _votingPeriod, uint256 _executionDelay, uint256 _quorumPercentage) public initializer {
        __AccessControl_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(MINISTRY_ROLE, admin);
        _grantRole(PROPOSER_ROLE, admin);
        votingPeriod = _votingPeriod;
        executionDelay = _executionDelay;
        quorumPercentage = _quorumPercentage;
        ministryQuorum = 55;
        emergencyQuorum = 60;
        ministryWeights[MinistryType.Treasury] = 20;
        ministryWeights[MinistryType.Finance] = 18;
        ministryWeights[MinistryType.Infrastructure] = 15;
        ministryWeights[MinistryType.Trade] = 13;
        ministryWeights[MinistryType.Defense] = 12;
        ministryWeights[MinistryType.Energy] = 12;
        ministryWeights[MinistryType.Technology] = 10;
    }

    function registerMinistry(address ministry, MinistryType ministryType) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ministry != address(0) && !ministries[ministry].active, "Invalid ministry");
        ministries[ministry] = Ministry(ministry, ministryType, ministryWeights[ministryType], true, 0);
        ministryList.push(ministry);
        _grantRole(MINISTRY_ROLE, ministry);
        emit MinistryRegistered(ministry, ministryType);
    }

    function propose(ProposalCategory category, uint256 budgetImpact, bytes32 documentHash, string memory description)
        external onlyRole(PROPOSER_ROLE) whenNotPaused returns (uint256) {
        uint256 proposalId = proposalCounter++;
        bool requiresMinistry = category == ProposalCategory.Treasury || category == ProposalCategory.Infrastructure || category == ProposalCategory.Emergency;
        proposals[proposalId] = Proposal(proposalId, category, msg.sender, budgetImpact, documentHash, description,
            0, 0, 0, block.timestamp, block.timestamp + votingPeriod, 0, false, false, requiresMinistry, 0,
            requiresMinistry ? (category == ProposalCategory.Emergency ? emergencyQuorum : ministryQuorum) : 0, ProposalState.Active);
        emit ProposalCreated(proposalId, msg.sender, category);
        return proposalId;
    }

    function castVote(uint256 proposalId, uint8 support) external {
        require(support <= 2, "Invalid vote");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active && block.timestamp <= proposal.endTime, "Cannot vote");
        Vote storage vote = votes[proposalId][msg.sender];
        require(!vote.hasVoted, "Already voted");
        uint256 weight = 1;
        vote.hasVoted = true;
        vote.support = support;
        vote.weight = weight;
        if (support == 0) proposal.againstVotes += weight;
        else if (support == 1) proposal.forVotes += weight;
        else proposal.abstainVotes += weight;
        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    function castMinistryVote(uint256 proposalId, bool support) external onlyRole(MINISTRY_ROLE) {
        require(ministries[msg.sender].active && !ministryVotes[proposalId][msg.sender], "Cannot vote");
        Proposal storage proposal = proposals[proposalId];
        require(proposal.requiresMinistryApproval && proposal.state == ProposalState.Active, "Invalid proposal");
        if (support) proposal.ministryApprovals += ministries[msg.sender].votingWeight;
        ministryVotes[proposalId][msg.sender] = true;
        ministries[msg.sender].proposalsVoted++;
        emit MinistryVoteCast(proposalId, msg.sender, support);
    }

    function execute(uint256 proposalId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed && !proposal.canceled && block.timestamp > proposal.endTime, "Cannot execute");
        _updateProposalState(proposalId);
        require(proposal.state == ProposalState.Succeeded, "Not succeeded");
        if (proposal.requiresMinistryApproval) {
            require(proposal.ministryApprovals >= proposal.requiredMinistryApprovals, "Insufficient ministry approvals");
        }
        proposal.executed = true;
        proposal.executionTime = block.timestamp;
        proposal.state = ProposalState.Executed;
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        require(!proposal.executed && !proposal.canceled, "Cannot cancel");
        proposal.canceled = true;
        proposal.state = ProposalState.Canceled;
        emit ProposalCanceled(proposalId);
    }

    function _updateProposalState(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) proposal.state = ProposalState.Canceled;
        else if (proposal.executed) proposal.state = ProposalState.Executed;
        else if (block.timestamp <= proposal.endTime) proposal.state = ProposalState.Active;
        else {
            uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
            uint256 quorum = (totalVotes * quorumPercentage) / 100;
            proposal.state = (proposal.forVotes >= quorum && proposal.forVotes > proposal.againstVotes) ? ProposalState.Succeeded : ProposalState.Defeated;
        }
    }

    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) return ProposalState.Canceled;
        if (proposal.executed) return ProposalState.Executed;
        if (block.timestamp <= proposal.endTime) return ProposalState.Active;
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorum = (totalVotes * quorumPercentage) / 100;
        return (proposal.forVotes >= quorum && proposal.forVotes > proposal.againstVotes) ? ProposalState.Succeeded : ProposalState.Defeated;
    }

    function activateEmergencyMode() external onlyRole(DEFAULT_ADMIN_ROLE) { emergencyMode = true; _pause(); }
    function deactivateEmergencyMode() external onlyRole(DEFAULT_ADMIN_ROLE) { emergencyMode = false; _unpause(); }
    function setVotingPeriod(uint256 period) external onlyRole(DEFAULT_ADMIN_ROLE) { votingPeriod = period; }
    function setQuorumPercentage(uint256 percentage) external onlyRole(DEFAULT_ADMIN_ROLE) { require(percentage <= 100, "Invalid"); quorumPercentage = percentage; }
    function deactivateMinistry(address ministry) external onlyRole(DEFAULT_ADMIN_ROLE) { ministries[ministry].active = false; _revokeRole(MINISTRY_ROLE, ministry); }
    function getMinistry(address ministry) external view returns (Ministry memory) { return ministries[ministry]; }
    function getProposal(uint256 proposalId) external view returns (Proposal memory) { return proposals[proposalId]; }
    function getAllMinistries() external view returns (address[] memory) { return ministryList; }
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) { _pause(); }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
