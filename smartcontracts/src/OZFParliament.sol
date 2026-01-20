// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OZFParliament
 * @notice OZHUMANILL ZAYED FEDERATION - Main Government Contract
 * @dev 216 seats + Prime Minister | Chairman controls all | 5-year terms | 55% election threshold
 */
contract OZFParliament is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant CHAIRMAN_ROLE = keccak256("CHAIRMAN_ROLE");
    bytes32 public constant PRIME_MINISTER_ROLE = keccak256("PRIME_MINISTER_ROLE");
    bytes32 public constant SEAT_HOLDER_ROLE = keccak256("SEAT_HOLDER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    enum ProposalType {
        Trade,
        Commerce,
        Business,
        Investment,
        Negotiation,
        Legislative,
        Constitutional
    }

    enum ProposalStatus {
        Pending,
        Active,
        Passed,
        Rejected,
        Executed
    }

    struct Seat {
        uint256 seatNumber; // 1-216
        address holder;
        string delegationName;
        string tradeBlockName;
        string jurisdiction;
        uint256 termStart;
        uint256 termEnd; // 5 years
        bool active;
        uint256 votingPower; // 1 vote per seat
        uint256 proposalsCreated;
        uint256 votescast;
    }

    struct Election {
        uint256 electionId;
        uint256 seatNumber;
        address[] candidates;
        mapping(address => uint256) votes;
        mapping(address => bool) hasVoted;
        uint256 totalVotes;
        uint256 startDate;
        uint256 endDate;
        bool concluded;
        address winner;
        uint256 requiredThreshold; // 55% = 5500 basis points
    }

    struct Proposal {
        uint256 proposalId;
        ProposalType proposalType;
        address proposer;
        string title;
        string description;
        string tradeBlockInvolved;
        uint256 fundingAmount;
        uint256 createdAt;
        uint256 votingDeadline;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
        ProposalStatus status;
        bytes executionData;
    }

    // State variables
    mapping(uint256 => Seat) public seats; // seatNumber => Seat
    mapping(address => uint256) public seatHolderToNumber;
    mapping(uint256 => Election) public elections;
    mapping(uint256 => Proposal) public proposals;

    address public chairman; // Controls everything
    address public primeMinister; // Government leader
    address public treasuryGovernor; // Treasury control

    uint256 public constant TOTAL_SEATS = 216;
    uint256 public constant TERM_DURATION = 5 * 365 days;
    uint256 public constant ELECTION_THRESHOLD = 5500; // 55%
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant VOTING_PERIOD = 7 days;

    uint256 public electionCounter;
    uint256 public proposalCounter;
    uint256 public activeSeats;

    // Events
    event SeatAssigned(
        uint256 indexed seatNumber,
        address indexed holder,
        string delegationName,
        uint256 termEnd
    );

    event ElectionStarted(
        uint256 indexed electionId,
        uint256 indexed seatNumber,
        uint256 endDate
    );

    event VoteCast(
        uint256 indexed electionId,
        address indexed voter,
        address indexed candidate
    );

    event ElectionConcluded(
        uint256 indexed electionId,
        uint256 indexed seatNumber,
        address winner,
        uint256 votePercentage
    );

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string title
    );

    event ProposalVoted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        ProposalStatus status
    );

    event ChairmanUpdated(address indexed oldChairman, address indexed newChairman);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _chairman,
        address _primeMinister,
        address _treasuryGovernor
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        chairman = _chairman;
        primeMinister = _primeMinister;
        treasuryGovernor = _treasuryGovernor;

        _grantRole(DEFAULT_ADMIN_ROLE, _chairman);
        _grantRole(CHAIRMAN_ROLE, _chairman);
        _grantRole(PRIME_MINISTER_ROLE, _primeMinister);
        _grantRole(ADMIN_ROLE, _chairman);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(CHAIRMAN_ROLE)
    {}

    /**
     * @notice Assign a seat to a delegation (only Chairman)
     */
    function assignSeat(
        uint256 seatNumber,
        address holder,
        string memory delegationName,
        string memory tradeBlockName,
        string memory jurisdiction
    ) external onlyRole(CHAIRMAN_ROLE) {
        require(seatNumber > 0 && seatNumber <= TOTAL_SEATS, "Invalid seat number");
        require(holder != address(0), "Invalid holder");
        require(!seats[seatNumber].active, "Seat already occupied");

        seats[seatNumber] = Seat({
            seatNumber: seatNumber,
            holder: holder,
            delegationName: delegationName,
            tradeBlockName: tradeBlockName,
            jurisdiction: jurisdiction,
            termStart: block.timestamp,
            termEnd: block.timestamp + TERM_DURATION,
            active: true,
            votingPower: 1,
            proposalsCreated: 0,
            votescast: 0
        });

        seatHolderToNumber[holder] = seatNumber;
        _grantRole(SEAT_HOLDER_ROLE, holder);
        activeSeats++;

        emit SeatAssigned(seatNumber, holder, delegationName, block.timestamp + TERM_DURATION);
    }

    /**
     * @notice Start an election for a seat
     */
    function startElection(uint256 seatNumber, address[] memory candidates)
        external
        onlyRole(CHAIRMAN_ROLE)
    {
        require(seatNumber > 0 && seatNumber <= TOTAL_SEATS, "Invalid seat number");
        require(candidates.length > 0, "No candidates");

        uint256 electionId = ++electionCounter;

        Election storage election = elections[electionId];
        election.electionId = electionId;
        election.seatNumber = seatNumber;
        election.candidates = candidates;
        election.startDate = block.timestamp;
        election.endDate = block.timestamp + 30 days; // 30 day election period
        election.concluded = false;
        election.requiredThreshold = ELECTION_THRESHOLD;

        emit ElectionStarted(electionId, seatNumber, election.endDate);
    }

    /**
     * @notice Vote in an election (1 vote per seat holder)
     */
    function voteInElection(uint256 electionId, address candidate)
        external
        onlyRole(SEAT_HOLDER_ROLE)
    {
        Election storage election = elections[electionId];
        require(!election.concluded, "Election concluded");
        require(block.timestamp <= election.endDate, "Election ended");
        require(!election.hasVoted[msg.sender], "Already voted");

        bool validCandidate = false;
        for (uint256 i = 0; i < election.candidates.length; i++) {
            if (election.candidates[i] == candidate) {
                validCandidate = true;
                break;
            }
        }
        require(validCandidate, "Invalid candidate");

        election.votes[candidate]++;
        election.hasVoted[msg.sender] = true;
        election.totalVotes++;

        emit VoteCast(electionId, msg.sender, candidate);
    }

    /**
     * @notice Conclude an election and determine winner
     */
    function concludeElection(uint256 electionId)
        external
        onlyRole(CHAIRMAN_ROLE)
    {
        Election storage election = elections[electionId];
        require(!election.concluded, "Already concluded");
        require(block.timestamp > election.endDate, "Election still active");

        address winner;
        uint256 maxVotes = 0;

        for (uint256 i = 0; i < election.candidates.length; i++) {
            address candidate = election.candidates[i];
            if (election.votes[candidate] > maxVotes) {
                maxVotes = election.votes[candidate];
                winner = candidate;
            }
        }

        uint256 votePercentage = (maxVotes * BASIS_POINTS) / activeSeats;
        require(votePercentage >= election.requiredThreshold, "Threshold not met");

        election.concluded = true;
        election.winner = winner;

        // Assign seat to winner
        uint256 seatNumber = election.seatNumber;
        if (seats[seatNumber].active) {
            address oldHolder = seats[seatNumber].holder;
            _revokeRole(SEAT_HOLDER_ROLE, oldHolder);
            delete seatHolderToNumber[oldHolder];
        }

        seats[seatNumber].holder = winner;
        seats[seatNumber].termStart = block.timestamp;
        seats[seatNumber].termEnd = block.timestamp + TERM_DURATION;
        seats[seatNumber].active = true;

        seatHolderToNumber[winner] = seatNumber;
        _grantRole(SEAT_HOLDER_ROLE, winner);

        emit ElectionConcluded(electionId, seatNumber, winner, votePercentage);
    }

    /**
     * @notice Create a proposal (only seat holders)
     */
    function createProposal(
        ProposalType proposalType,
        string memory title,
        string memory description,
        string memory tradeBlockInvolved,
        uint256 fundingAmount,
        bytes memory executionData
    ) external onlyRole(SEAT_HOLDER_ROLE) whenNotPaused returns (uint256) {
        uint256 proposalId = ++proposalCounter;

        Proposal storage proposal = proposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.proposalType = proposalType;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.tradeBlockInvolved = tradeBlockInvolved;
        proposal.fundingAmount = fundingAmount;
        proposal.createdAt = block.timestamp;
        proposal.votingDeadline = block.timestamp + VOTING_PERIOD;
        proposal.status = ProposalStatus.Active;
        proposal.executionData = executionData;

        uint256 seatNumber = seatHolderToNumber[msg.sender];
        seats[seatNumber].proposalsCreated++;

        emit ProposalCreated(proposalId, msg.sender, proposalType, title);

        return proposalId;
    }

    /**
     * @notice Vote on a proposal (1 vote per seat)
     */
    function voteOnProposal(uint256 proposalId, bool support)
        external
        onlyRole(SEAT_HOLDER_ROLE)
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal not active");
        require(block.timestamp <= proposal.votingDeadline, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }

        uint256 seatNumber = seatHolderToNumber[msg.sender];
        seats[seatNumber].votescast++;

        emit ProposalVoted(proposalId, msg.sender, support);
    }

    /**
     * @notice Execute a passed proposal (Chairman or Prime Minister)
     */
    function executeProposal(uint256 proposalId)
        external
        nonReentrant
    {
        require(
            hasRole(CHAIRMAN_ROLE, msg.sender) || hasRole(PRIME_MINISTER_ROLE, msg.sender),
            "Not authorized"
        );

        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal not active");
        require(block.timestamp > proposal.votingDeadline, "Voting still active");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 approvalPercentage = (proposal.votesFor * BASIS_POINTS) / totalVotes;

        if (approvalPercentage >= ELECTION_THRESHOLD) {
            proposal.status = ProposalStatus.Passed;
            // Execute proposal logic here
            proposal.status = ProposalStatus.Executed;
        } else {
            proposal.status = ProposalStatus.Rejected;
        }

        emit ProposalExecuted(proposalId, proposal.status);
    }

    /**
     * @notice Get seat details
     */
    function getSeat(uint256 seatNumber)
        external
        view
        returns (
            address holder,
            string memory delegationName,
            string memory tradeBlockName,
            uint256 termEnd,
            bool active
        )
    {
        Seat storage seat = seats[seatNumber];
        return (
            seat.holder,
            seat.delegationName,
            seat.tradeBlockName,
            seat.termEnd,
            seat.active
        );
    }

    /**
     * @notice Update Chairman (only current Chairman)
     */
    function updateChairman(address newChairman)
        external
        onlyRole(CHAIRMAN_ROLE)
    {
        require(newChairman != address(0), "Invalid address");

        address oldChairman = chairman;
        _revokeRole(CHAIRMAN_ROLE, oldChairman);
        _grantRole(CHAIRMAN_ROLE, newChairman);

        chairman = newChairman;

        emit ChairmanUpdated(oldChairman, newChairman);
    }

    function pause() external onlyRole(CHAIRMAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(CHAIRMAN_ROLE) {
        _unpause();
    }
}
