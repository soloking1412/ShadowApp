// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title SGMToken — Samuel Global Market Governance Token
/// @notice OZF ecosystem governance, investment, yield and liquidity token.
///         Total supply: 250 Billion SGM (2.5 × 10^11), 18 decimals.
///         Paired to OICD stablecoin via on-chain rate.
///         Issued by Samuel Global Market Xchange Inc. (SGMX Inc.)
contract SGMToken is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    string  public constant NAME    = "Samuel Global Market Token";
    string  public constant SYMBOL  = "SGM";
    string  public constant COMPANY = "Samuel Global Market Xchange Inc.";
    uint8   public constant DECIMALS = 18;

    // 250 billion × 10^18 decimals
    uint256 public constant TOTAL_SUPPLY = 250_000_000_000 * 10**18;

    // OICD pair rate — updated by oracle; starts at 0.001 OICD per 1 SGM
    uint256 public oicdPairRate;

    // ── Member ──────────────────────────────────────────────────────────────────

    struct Member {
        uint256 balance;
        uint256 stakedBalance;        // locked for yield
        uint256 yieldAccrued;
        uint256 investmentBalance;    // across all pools
        uint256 gScore;               // 0-100 civic score
        bool    isRegistered;
        uint256 registeredAt;
    }

    // ── Yield Pool ───────────────────────────────────────────────────────────────

    struct YieldPool {
        uint256 totalStaked;
        uint256 rewardRate;           // basis points (e.g. 250 = 2.5%)
        uint256 lastDistribution;
    }

    // ── Investment Pool ──────────────────────────────────────────────────────────

    struct InvestmentPool {
        string  name;
        uint256 totalDeposited;
        uint256 targetReturn;         // basis points
        uint256 minDeposit;
        bool    active;
    }

    // ── Governance Proposal ──────────────────────────────────────────────────────

    struct Proposal {
        uint256 id;
        string  title;
        string  description;
        string  proposalType;         // "investment" | "governance" | "yield" | "liquidity"
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endsAt;
        bool    executed;
        bool    passed;
    }

    // ── Storage ──────────────────────────────────────────────────────────────────

    uint256 public circulatingSupply;
    uint256 public proposalCounter;
    uint256 public totalMembers;
    uint256 public totalStaked;
    uint256 public poolCount;

    YieldPool public yieldPool;

    mapping(address => Member)   public members;
    mapping(address => bool)     public registered;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => InvestmentPool)           public investmentPools;
    mapping(address => mapping(uint256 => uint256)) public poolDeposits;

    // SGM/OICD liquidity reserves
    uint256 public liquidityReserveOICD;
    uint256 public liquidityReserveSGM;

    // ── Events ───────────────────────────────────────────────────────────────────

    event MemberRegistered(address indexed member);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensStaked(address indexed member, uint256 amount);
    event TokensUnstaked(address indexed member, uint256 amount);
    event YieldClaimed(address indexed member, uint256 amount);
    event InvestmentDeposited(address indexed member, uint256 poolId, uint256 amount);
    event ProposalCreated(uint256 indexed id, string title, string proposalType);
    event VoteCast(uint256 indexed id, address voter, bool support);
    event ProposalExecuted(uint256 indexed id, bool passed);
    event LiquidityAdded(uint256 sgmAmount, uint256 oicdAmount);
    event PairRateUpdated(uint256 newRate);

    // ── Initializer ──────────────────────────────────────────────────────────────

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        oicdPairRate     = 1e15;          // 0.001 OICD per SGM
        circulatingSupply = TOTAL_SUPPLY * 40 / 100;  // 40% public float

        yieldPool = YieldPool({
            totalStaked:      0,
            rewardRate:       250,          // 2.5% per period
            lastDistribution: block.timestamp
        });

        // Seed 3 investment pools
        investmentPools[1] = InvestmentPool("OZF Infrastructure Fund",  0, 800,  1000 ether, true);
        investmentPools[2] = InvestmentPool("SGM Growth Portfolio",      0, 1200,  500 ether, true);
        investmentPools[3] = InvestmentPool("OICD Liquidity Pool",       0,  400,  100 ether, true);
        poolCount = 3;
    }

    // ── Registration ─────────────────────────────────────────────────────────────

    function register() external {
        require(!registered[msg.sender], "Already registered");
        members[msg.sender] = Member({
            balance:           0,
            stakedBalance:     0,
            yieldAccrued:      0,
            investmentBalance: 0,
            gScore:            1,
            isRegistered:      true,
            registeredAt:      block.timestamp
        });
        registered[msg.sender] = true;
        totalMembers++;
        emit MemberRegistered(msg.sender);
    }

    // ── Minting ──────────────────────────────────────────────────────────────────

    function mint(address to, uint256 amount) external onlyOwner {
        require(circulatingSupply + amount <= TOTAL_SUPPLY, "Exceeds supply");
        members[to].balance += amount;
        circulatingSupply   += amount;
        emit TokensMinted(to, amount);
    }

    // ── Staking / Yield ──────────────────────────────────────────────────────────

    function stake(uint256 amount) external {
        require(registered[msg.sender],              "Not registered");
        require(members[msg.sender].balance >= amount, "Insufficient balance");
        members[msg.sender].balance      -= amount;
        members[msg.sender].stakedBalance += amount;
        yieldPool.totalStaked            += amount;
        totalStaked                      += amount;
        emit TokensStaked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(members[msg.sender].stakedBalance >= amount, "Insufficient staked");
        members[msg.sender].stakedBalance -= amount;
        members[msg.sender].balance       += amount;
        yieldPool.totalStaked             -= amount;
        totalStaked                       -= amount;
        // Yield on unstake
        uint256 yield_ = (amount * yieldPool.rewardRate) / 10000;
        members[msg.sender].yieldAccrued += yield_;
        emit TokensUnstaked(msg.sender, amount);
    }

    function claimYield() external returns (uint256 claimed) {
        claimed = members[msg.sender].yieldAccrued;
        require(claimed > 0, "No yield");
        members[msg.sender].yieldAccrued = 0;
        members[msg.sender].balance     += claimed;
        emit YieldClaimed(msg.sender, claimed);
    }

    // ── Investment Pools ─────────────────────────────────────────────────────────

    function depositToPool(uint256 poolId, uint256 amount) external {
        require(investmentPools[poolId].active,             "Pool inactive");
        require(amount >= investmentPools[poolId].minDeposit, "Below minimum");
        require(members[msg.sender].balance >= amount,      "Insufficient balance");
        members[msg.sender].balance           -= amount;
        members[msg.sender].investmentBalance += amount;
        investmentPools[poolId].totalDeposited += amount;
        poolDeposits[msg.sender][poolId]       += amount;
        emit InvestmentDeposited(msg.sender, poolId, amount);
    }

    // ── Governance (1 person = 1 vote) ────────────────────────────────────────────

    function createProposal(
        string calldata title,
        string calldata description,
        string calldata proposalType,
        uint256 durationDays
    ) external returns (uint256 id) {
        require(registered[msg.sender], "Not registered");
        id = ++proposalCounter;
        proposals[id] = Proposal({
            id:           id,
            title:        title,
            description:  description,
            proposalType: proposalType,
            votesFor:     0,
            votesAgainst: 0,
            endsAt:       block.timestamp + durationDays * 1 days,
            executed:     false,
            passed:       false
        });
        emit ProposalCreated(id, title, proposalType);
    }

    function vote(uint256 proposalId, bool support) external {
        require(registered[msg.sender],                    "Not registered");
        require(!hasVoted[proposalId][msg.sender],         "Already voted");
        require(block.timestamp < proposals[proposalId].endsAt, "Voting ended");
        hasVoted[proposalId][msg.sender] = true;
        if (support) proposals[proposalId].votesFor++;
        else         proposals[proposalId].votesAgainst++;
        if (members[msg.sender].gScore < 100) members[msg.sender].gScore++;
        emit VoteCast(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.endsAt, "Still active");
        require(!p.executed,                 "Already executed");
        p.executed = true;
        p.passed   = p.votesFor > p.votesAgainst;
        emit ProposalExecuted(proposalId, p.passed);
    }

    // ── Liquidity ────────────────────────────────────────────────────────────────

    function addLiquidity(uint256 sgmAmount, uint256 oicdAmount) external onlyOwner {
        liquidityReserveSGM  += sgmAmount;
        liquidityReserveOICD += oicdAmount;
        emit LiquidityAdded(sgmAmount, oicdAmount);
    }

    function updateOICDPairRate(uint256 newRate) external onlyOwner {
        oicdPairRate = newRate;
        emit PairRateUpdated(newRate);
    }

    // ── Views ─────────────────────────────────────────────────────────────────────

    function getMember(address m) external view returns (Member memory)   { return members[m]; }
    function getProposal(uint256 id) external view returns (Proposal memory) { return proposals[id]; }
    function getPool(uint256 id) external view returns (InvestmentPool memory) { return investmentPools[id]; }
    function totalSupply() external pure returns (uint256) { return TOTAL_SUPPLY; }

    function globalStats() external view returns (
        uint256 supply, uint256 circulating, uint256 staked,
        uint256 members_, uint256 pools, uint256 rate
    ) {
        supply      = TOTAL_SUPPLY;
        circulating = circulatingSupply;
        staked      = totalStaked;
        members_    = totalMembers;
        pools       = poolCount;
        rate        = oicdPairRate;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
