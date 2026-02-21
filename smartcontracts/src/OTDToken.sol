// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title OTDToken — Ozhumanill Trade Dollar (OTD) Market Stock
/// @notice The digital stock of the SGMX/OZF market ecosystem.
///         Total supply: 500 Octillion OTD (5 × 10^29), 18 decimals.
///         Value backed by all economic activity on the Kratos Smart Chain.
///         Also manages GIC (Orion Infrastructure Corporation) speculative asset.
contract OTDToken is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // -- OTD Token --
    string  public constant OTD_NAME   = "Ozhumanill Trade Dollar";
    string  public constant OTD_SYMBOL = "OTD";
    uint8   public constant DECIMALS    = 18;

    // 500 Octillion = 5 * 10^29; with 18 decimals raw = 5 * 10^47
    // uint256 max = ~1.15 * 10^77, so this fits
    uint256 public constant OTD_TOTAL_SUPPLY = 500_000_000_000 * (10**18) * (10**18); // 5e29 * 1e18

    // -- GIC Token --
    string  public constant GIC_NAME   = "Orion Infrastructure Corporation";
    string  public constant GIC_SYMBOL = "GIC";
    // GIC backed by infrastructure built — supply grows with development
    uint256 public constant GIC_INITIAL_SUPPLY = 1_000_000_000 * (10**18); // 1 billion initial

    // Allocation categories
    enum AllocationType { Validator, Shareholder, Country, Community, PublicReserve, Development }

    struct Holder {
        uint256 otdBalance;
        uint256 gicBalance;
        AllocationType holderType;
        uint256 lockedUntil;      // timestamp
        uint256 allocatedAt;
        string  country;           // for country allocations
        bool    isValidator;
        uint256 gScore;            // governance score 0-100
    }

    struct CountryAllocation {
        string  countryCode;
        uint256 otdAmount;
        uint256 gicAmount;
        uint256 allocatedAt;
        bool    disbursed;
    }

    struct GovernanceVote {
        uint256 voteId;
        string  description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endsAt;
        bool    executed;
        bool    passed;
    }

    // -- Storage --
    uint256 public otdCirculating;
    uint256 public gicCirculating;
    uint256 public totalHolders;
    uint256 public totalValidators;
    uint256 public totalShareholders;
    uint256 public voteCounter;

    // Public reserve — democratically distributed
    uint256 public publicReserveOTD;
    uint256 public publicReserveGIC;

    mapping(address => Holder) public holders;
    mapping(string => CountryAllocation) public countryAllocations; // countryCode => allocation
    mapping(uint256 => GovernanceVote) public votes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint256[]) public voterHistory;
    mapping(address => bool) public registeredHolders;

    // -- Events --
    event OTDAllocated(address indexed to, uint256 amount, AllocationType allocType);
    event GICAllocated(address indexed to, uint256 amount, AllocationType allocType);
    event CountryAllocated(string countryCode, uint256 otdAmount, uint256 gicAmount);
    event ValidatorRegistered(address indexed validator);
    event ShareholderRegistered(address indexed shareholder);
    event GScoreUpdated(address indexed holder, uint256 newScore);
    event GovernanceVoteCreated(uint256 indexed voteId, string description);
    event VoteCast(uint256 indexed voteId, address voter, bool support);
    event VoteExecuted(uint256 indexed voteId, bool passed);
    event TokensLocked(address indexed holder, uint256 amount, uint256 lockUntil);

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        // Seed public reserve with 30% of OTD supply
        publicReserveOTD = OTD_TOTAL_SUPPLY * 30 / 100;
        publicReserveGIC = GIC_INITIAL_SUPPLY * 30 / 100;
        otdCirculating += publicReserveOTD;
        gicCirculating += publicReserveGIC;
    }

    // -- Registration --

    /// @notice Register as validator (5-month compound: $2M → $2.048B OICD equivalent)
    function registerAsValidator() external {
        require(!registeredHolders[msg.sender], "Already registered");
        holders[msg.sender] = Holder({
            otdBalance: 0,
            gicBalance: 0,
            holderType: AllocationType.Validator,
            lockedUntil: block.timestamp + 150 days, // 5 months
            allocatedAt: block.timestamp,
            country: "",
            isValidator: true,
            gScore: 10
        });
        registeredHolders[msg.sender] = true;
        totalValidators++;
        totalHolders++;
        emit ValidatorRegistered(msg.sender);
    }

    /// @notice Register as shareholder (8-month compound: $2M → $256M OICD equivalent)
    function registerAsShareholder() external {
        require(!registeredHolders[msg.sender], "Already registered");
        holders[msg.sender] = Holder({
            otdBalance: 0,
            gicBalance: 0,
            holderType: AllocationType.Shareholder,
            lockedUntil: block.timestamp + 240 days, // 8 months
            allocatedAt: block.timestamp,
            country: "",
            isValidator: false,
            gScore: 5
        });
        registeredHolders[msg.sender] = true;
        totalShareholders++;
        totalHolders++;
        emit ShareholderRegistered(msg.sender);
    }

    // -- Token Allocation --

    function allocateOTD(
        address to,
        uint256 amount,
        AllocationType allocType
    ) external onlyOwner {
        require(otdCirculating + amount <= OTD_TOTAL_SUPPLY, "Exceeds OTD supply");
        holders[to].otdBalance += amount;
        otdCirculating += amount;
        emit OTDAllocated(to, amount, allocType);
    }

    function allocateGIC(
        address to,
        uint256 amount,
        AllocationType allocType
    ) external onlyOwner {
        require(gicCirculating + amount <= GIC_INITIAL_SUPPLY * 10, "Exceeds GIC supply");
        holders[to].gicBalance += amount;
        gicCirculating += amount;
        emit GICAllocated(to, amount, allocType);
    }

    /// @notice Allocate OTD + GIC to an emerging market country
    function allocateToCountry(
        string calldata countryCode,
        uint256 otdAmount,
        uint256 gicAmount
    ) external onlyOwner {
        countryAllocations[countryCode] = CountryAllocation({
            countryCode: countryCode,
            otdAmount: otdAmount,
            gicAmount: gicAmount,
            allocatedAt: block.timestamp,
            disbursed: false
        });
        otdCirculating += otdAmount;
        gicCirculating += gicAmount;
        emit CountryAllocated(countryCode, otdAmount, gicAmount);
    }

    // -- Governance (1 person = 1 vote, regardless of holdings) --

    function createGovernanceVote(
        string calldata description,
        uint256 durationDays
    ) external returns (uint256 voteId) {
        require(registeredHolders[msg.sender], "Must be registered holder");
        voteId = ++voteCounter;
        votes[voteId] = GovernanceVote({
            voteId: voteId,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            endsAt: block.timestamp + durationDays * 1 days,
            executed: false,
            passed: false
        });
        emit GovernanceVoteCreated(voteId, description);
    }

    function castVote(uint256 voteId, bool support) external {
        require(registeredHolders[msg.sender], "Must be registered holder");
        require(!hasVoted[voteId][msg.sender], "Already voted");
        require(block.timestamp < votes[voteId].endsAt, "Vote ended");

        hasVoted[voteId][msg.sender] = true;
        if (support) { votes[voteId].votesFor++; }
        else          { votes[voteId].votesAgainst++; }

        // Increment g score for civic participation
        if (holders[msg.sender].gScore < 100) {
            holders[msg.sender].gScore += 1;
        }

        voterHistory[msg.sender].push(voteId);
        emit VoteCast(voteId, msg.sender, support);
    }

    function executeVote(uint256 voteId) external {
        GovernanceVote storage v = votes[voteId];
        require(block.timestamp >= v.endsAt, "Vote still active");
        require(!v.executed, "Already executed");
        v.executed = true;
        v.passed = v.votesFor > v.votesAgainst;
        emit VoteExecuted(voteId, v.passed);
    }

    // -- G Score --

    function updateGScore(address holder, uint256 score) external onlyOwner {
        require(score <= 100, "Max 100");
        holders[holder].gScore = score;
        emit GScoreUpdated(holder, score);
    }

    // -- Views --

    function getHolder(address h) external view returns (Holder memory) {
        return holders[h];
    }

    function getVote(uint256 voteId) external view returns (GovernanceVote memory) {
        return votes[voteId];
    }

    function getCountryAllocation(string calldata code) external view returns (CountryAllocation memory) {
        return countryAllocations[code];
    }

    function getVoterHistory(address voter) external view returns (uint256[] memory) {
        return voterHistory[voter];
    }

    function tokenStats() external view returns (
        uint256 otdSupply,
        uint256 otdOut,
        uint256 gicSupply,
        uint256 gicOut,
        uint256 reserve,
        uint256 validators,
        uint256 shareholders
    ) {
        otdSupply    = OTD_TOTAL_SUPPLY;
        otdOut       = otdCirculating;
        gicSupply    = GIC_INITIAL_SUPPLY;
        gicOut       = gicCirculating;
        reserve      = publicReserveOTD;
        validators   = totalValidators;
        shareholders = totalShareholders;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
