// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title ICFLending — Independent Capital Financing Platform
/// @notice Implements Obsidian Capital's lending programs:
///         1. ICF Standard — G-score based tiered loans ($1M–$1B OICD)
///         2. First90 — Interest-free 90-day business launch loan ($5–10M OICD)
///         3. FFE — Finance Forward Education (3.5% income share agreement)
///         4. Debt Restructuring — Sovereign debt at 1.5x–2x with 2.5–10% interest
contract ICFLending is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    enum LoanType { ICF, First90, FFE, DebtRestructuring }

    enum LoanTier {
        Micro,           // $1M–$10M OICD
        Small,           // $10M–$20M
        Medium,          // $20M–$80M
        Large,           // $80M–$200M
        Institutional    // $200M–$1B OICD
    }

    enum LoanStatus { Applied, Approved, Active, Completed, Defaulted, Rejected }

    enum LoanTerm { Y5, Y10, Y15, Y20, Y30, Y100 }

    struct Loan {
        uint256 loanId;
        address borrower;
        LoanType loanType;
        LoanTier tier;
        LoanStatus status;
        uint256 principalOICD;    // 1e18 scaled
        uint256 interestRateBps;  // basis points: 250 = 2.5%, 1000 = 10%
        LoanTerm term;
        uint256 appliedAt;
        uint256 approvedAt;
        uint256 dueAt;
        uint256 repaidOICD;
        uint256 gScoreAtApplication;
        string  purpose;
        // First90 specific
        bool    revenueProven;    // for First90
        uint256 revenueProvenAt;
        // FFE specific
        string  institution;      // for FFE
        bool    employed;         // ISA trigger for FFE
        // Debt restructuring
        string  countryCode;
        uint256 fiatDebtUSD;
    }

    // Loan tier config: min/max principal OICD (1e18), min G-score
    struct TierConfig {
        uint256 minOICD;
        uint256 maxOICD;
        uint8   minGScore;
        uint256 defaultRateBps;
    }

    // -- Storage --
    uint256 public loanCounter;
    uint256 public totalLoansIssued;
    uint256 public totalPrincipalOICD;
    uint256 public totalRepaidOICD;
    uint256 public activeLoans;

    // First90 stats
    uint256 public first90Counter;
    uint256 public first90Successes;
    uint256 public first90Defaults;

    // FFE stats
    uint256 public ffeCounter;
    uint256 public ffeTotalEducationOICD;

    // Debt restructuring stats
    uint256 public debtRestructuringCounter;
    uint256 public totalSovereignDebtHandled;

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint8) public gScores;  // borrower G-score
    mapping(LoanTier => TierConfig) public tierConfigs;
    mapping(address => uint256) public activeFirst90;  // borrower => loanId

    // -- Events --
    event LoanApplied(uint256 indexed loanId, address borrower, LoanType loanType, uint256 principalOICD);
    event LoanApproved(uint256 indexed loanId, uint256 approvedAt, uint256 dueAt);
    event LoanRepayment(uint256 indexed loanId, address borrower, uint256 amount, uint256 remaining);
    event LoanCompleted(uint256 indexed loanId);
    event LoanDefaulted(uint256 indexed loanId, address borrower);
    event LoanRejected(uint256 indexed loanId, string reason);
    event RevenueProven(uint256 indexed loanId, address borrower);
    event GScoreUpdated(address indexed borrower, uint8 score);
    event EmploymentConfirmed(uint256 indexed loanId, address borrower);

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        // Configure tiers (OICD values as token units * 1e18)
        tierConfigs[LoanTier.Micro]        = TierConfig(1e24,   10e24,  10, 850);   // $1M–$10M, gScore>=10, 8.5%
        tierConfigs[LoanTier.Small]        = TierConfig(10e24,  20e24,  20, 700);   // $10M–$20M, gScore>=20, 7%
        tierConfigs[LoanTier.Medium]       = TierConfig(20e24,  80e24,  35, 550);   // $20M–$80M, gScore>=35, 5.5%
        tierConfigs[LoanTier.Large]        = TierConfig(80e24,  200e24, 50, 400);   // $80M–$200M, gScore>=50, 4%
        tierConfigs[LoanTier.Institutional]= TierConfig(200e24, 1000e24,70, 250);   // $200M–$1B, gScore>=70, 2.5%
    }

    // -- G Score --

    function setGScore(address borrower, uint8 score) external onlyOwner {
        require(score <= 100, "Max 100");
        gScores[borrower] = score;
        emit GScoreUpdated(borrower, score);
    }

    // -- ICF Standard Loan --

    function applyICFLoan(
        LoanTier tier,
        uint256 principalOICD,
        uint8 termChoice,
        string calldata purpose
    ) external nonReentrant returns (uint256 loanId) {
        TierConfig memory tc = tierConfigs[tier];
        require(principalOICD >= tc.minOICD && principalOICD <= tc.maxOICD, "Amount out of tier range");
        require(gScores[msg.sender] >= tc.minGScore, "G-score too low for this tier");

        loanId = ++loanCounter;
        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            loanType: LoanType.ICF,
            tier: tier,
            status: LoanStatus.Applied,
            principalOICD: principalOICD,
            interestRateBps: tc.defaultRateBps,
            term: LoanTerm(termChoice),
            appliedAt: block.timestamp,
            approvedAt: 0,
            dueAt: 0,
            repaidOICD: 0,
            gScoreAtApplication: gScores[msg.sender],
            purpose: purpose,
            revenueProven: false,
            revenueProvenAt: 0,
            institution: "",
            employed: false,
            countryCode: "",
            fiatDebtUSD: 0
        });

        borrowerLoans[msg.sender].push(loanId);
        emit LoanApplied(loanId, msg.sender, LoanType.ICF, principalOICD);
    }

    // -- First90 Loan (Interest-free, prove revenue in 90 days) --

    function applyFirst90(uint256 principalOICD, string calldata purpose) external nonReentrant returns (uint256 loanId) {
        require(principalOICD >= 5e24 && principalOICD <= 10e24, "First90: $5M-$10M OICD");
        require(activeFirst90[msg.sender] == 0, "Already have active First90 loan");

        loanId = ++loanCounter;
        first90Counter++;
        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            loanType: LoanType.First90,
            tier: LoanTier.Small,
            status: LoanStatus.Applied,
            principalOICD: principalOICD,
            interestRateBps: 0,  // interest-free
            term: LoanTerm.Y5,
            appliedAt: block.timestamp,
            approvedAt: 0,
            dueAt: block.timestamp + 90 days,
            repaidOICD: 0,
            gScoreAtApplication: gScores[msg.sender],
            purpose: purpose,
            revenueProven: false,
            revenueProvenAt: 0,
            institution: "",
            employed: false,
            countryCode: "",
            fiatDebtUSD: 0
        });

        activeFirst90[msg.sender] = loanId;
        borrowerLoans[msg.sender].push(loanId);
        emit LoanApplied(loanId, msg.sender, LoanType.First90, principalOICD);
    }

    function proveRevenue(uint256 loanId) external {
        Loan storage l = loans[loanId];
        require(l.borrower == msg.sender, "Not borrower");
        require(l.loanType == LoanType.First90, "Not First90 loan");
        require(!l.revenueProven, "Already proven");
        require(block.timestamp <= l.dueAt, "90 days expired");

        l.revenueProven = true;
        l.revenueProvenAt = block.timestamp;
        l.status = LoanStatus.Active;
        first90Successes++;
        // G score boost for successful business launch
        if (gScores[msg.sender] < 90) gScores[msg.sender] += 10;
        emit RevenueProven(loanId, msg.sender);
    }

    // -- Finance Forward Education (FFE) --

    function applyFFE(
        uint256 educationCostOICD,
        string calldata institution
    ) external nonReentrant returns (uint256 loanId) {
        require(educationCostOICD > 0, "Cost required");

        loanId = ++loanCounter;
        ffeCounter++;
        ffeTotalEducationOICD += educationCostOICD;

        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            loanType: LoanType.FFE,
            tier: LoanTier.Micro,
            status: LoanStatus.Applied,
            principalOICD: educationCostOICD,
            interestRateBps: 350,  // 3.5% ISA
            term: LoanTerm.Y10,    // repay on employment, max 10 years
            appliedAt: block.timestamp,
            approvedAt: 0,
            dueAt: 0,  // activates on employment
            repaidOICD: 0,
            gScoreAtApplication: gScores[msg.sender],
            purpose: "Finance Forward Education",
            revenueProven: false,
            revenueProvenAt: 0,
            institution: institution,
            employed: false,
            countryCode: "",
            fiatDebtUSD: 0
        });

        borrowerLoans[msg.sender].push(loanId);
        emit LoanApplied(loanId, msg.sender, LoanType.FFE, educationCostOICD);
    }

    function confirmEmployment(uint256 loanId) external {
        Loan storage l = loans[loanId];
        require(l.borrower == msg.sender, "Not borrower");
        require(l.loanType == LoanType.FFE, "Not FFE loan");
        l.employed = true;
        l.dueAt = block.timestamp + 10 * 365 days; // max 10 years from employment
        l.status = LoanStatus.Active;
        emit EmploymentConfirmed(loanId, msg.sender);
    }

    // -- Debt Restructuring (Sovereign) --

    function applyDebtRestructuring(
        string calldata countryCode,
        uint256 fiatDebtUSDMillions,
        uint256 principalOICD,   // 1.5x–2x of fiat debt in OICD
        uint256 interestRateBps, // 250–1000 (2.5%–10%)
        uint8 termChoice
    ) external onlyOwner returns (uint256 loanId) {
        require(interestRateBps >= 250 && interestRateBps <= 1000, "Rate 2.5%-10%");

        loanId = ++loanCounter;
        debtRestructuringCounter++;
        totalSovereignDebtHandled += fiatDebtUSDMillions;

        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            loanType: LoanType.DebtRestructuring,
            tier: LoanTier.Institutional,
            status: LoanStatus.Approved,
            principalOICD: principalOICD,
            interestRateBps: interestRateBps,
            term: LoanTerm(termChoice),
            appliedAt: block.timestamp,
            approvedAt: block.timestamp,
            dueAt: 0, // set by term
            repaidOICD: 0,
            gScoreAtApplication: 100,
            purpose: "Sovereign Debt Restructuring",
            revenueProven: false,
            revenueProvenAt: 0,
            institution: "",
            employed: false,
            countryCode: countryCode,
            fiatDebtUSD: fiatDebtUSDMillions
        });

        borrowerLoans[msg.sender].push(loanId);
        emit LoanApplied(loanId, msg.sender, LoanType.DebtRestructuring, principalOICD);
        emit LoanApproved(loanId, block.timestamp, 0);
    }

    // -- Admin: Approve / Reject / Mark Default --

    function approveLoan(uint256 loanId) external onlyOwner {
        Loan storage l = loans[loanId];
        require(l.status == LoanStatus.Applied, "Not applied");
        l.status = LoanStatus.Active;
        l.approvedAt = block.timestamp;
        totalLoansIssued++;
        totalPrincipalOICD += l.principalOICD;
        activeLoans++;
        emit LoanApproved(loanId, block.timestamp, l.dueAt);
    }

    function rejectLoan(uint256 loanId, string calldata reason) external onlyOwner {
        loans[loanId].status = LoanStatus.Rejected;
        emit LoanRejected(loanId, reason);
    }

    function markDefault(uint256 loanId) external onlyOwner {
        Loan storage l = loans[loanId];
        l.status = LoanStatus.Defaulted;
        if (l.loanType == LoanType.First90) { first90Defaults++; activeFirst90[l.borrower] = 0; }
        if (gScores[l.borrower] > 20) gScores[l.borrower] -= 20;
        if (activeLoans > 0) activeLoans--;
        emit LoanDefaulted(loanId, l.borrower);
    }

    // -- Repayment --

    function repayLoan(uint256 loanId, uint256 amountOICD) external nonReentrant {
        Loan storage l = loans[loanId];
        require(l.borrower == msg.sender, "Not borrower");
        require(l.status == LoanStatus.Active, "Loan not active");
        require(amountOICD > 0, "Zero amount");

        l.repaidOICD += amountOICD;
        totalRepaidOICD += amountOICD;

        uint256 remaining = l.principalOICD > l.repaidOICD ? l.principalOICD - l.repaidOICD : 0;
        emit LoanRepayment(loanId, msg.sender, amountOICD, remaining);

        if (l.repaidOICD >= l.principalOICD) {
            l.status = LoanStatus.Completed;
            if (activeLoans > 0) activeLoans--;
            if (l.loanType == LoanType.First90) { activeFirst90[msg.sender] = 0; }
            if (gScores[msg.sender] < 90) gScores[msg.sender] += 5;
            emit LoanCompleted(loanId);
        }
    }

    // -- Views --

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    function getBorrowerLoans(address borrower) external view returns (uint256[] memory) {
        return borrowerLoans[borrower];
    }

    function getTierConfig(LoanTier tier) external view returns (TierConfig memory) {
        return tierConfigs[tier];
    }

    function getGScore(address borrower) external view returns (uint8) {
        return gScores[borrower];
    }

    function platformStats() external view returns (
        uint256 totalLoans,
        uint256 totalPrincipal,
        uint256 totalRepaid,
        uint256 active,
        uint256 first90Count,
        uint256 first90Success,
        uint256 ffeCount,
        uint256 debtCount,
        uint256 sovereignDebt
    ) {
        totalLoans     = totalLoansIssued;
        totalPrincipal = totalPrincipalOICD;
        totalRepaid    = totalRepaidOICD;
        active         = activeLoans;
        first90Count   = first90Counter;
        first90Success = first90Successes;
        ffeCount       = ffeCounter;
        debtCount      = debtRestructuringCounter;
        sovereignDebt  = totalSovereignDebtHandled;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
