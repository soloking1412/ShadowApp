// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ReputationScoreSystem - COMPLETE PRODUCTION VERSION
 * @notice R-Score system (0-10000) for institutional participants with AI-powered scoring
 */
contract ReputationScoreSystem is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SCORER_ROLE = keccak256("SCORER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    enum ParticipantType {
        Government,
        Corporation,
        Institution,
        Individual,
        TradingEntity
    }
    
    struct ReputationScore {
        uint256 totalScore;
        uint256 paymentScore;
        uint256 complianceScore;
        uint256 volumeScore;
        uint256 longevityScore;
        uint256 disputeScore;
        uint256 lastUpdate;
        uint256 scoreHistory;
    }
    
    struct ScoringFactors {
        uint256 totalTransactions;
        uint256 successfulTransactions;
        uint256 failedTransactions;
        uint256 totalVolume;
        uint256 onTimePayments;
        uint256 latePayments;
        uint256 defaults;
        uint256 disputes;
        uint256 disputesWon;
        uint256 accountAge;
        uint256 complianceViolations;
    }
    
    struct ScoreAdjustment {
        uint256 adjustmentId;
        address participant;
        int256 adjustment;
        string reason;
        address adjuster;
        uint256 timestamp;
    }
    
    struct Tier {
        string name;
        uint256 minScore;
        uint256 maxScore;
        uint256 tradingLimit;
        uint256 feeDiscount;
        bool priorityAccess;
    }
    
    mapping(address => ReputationScore) public scores;
    mapping(address => ScoringFactors) public factors;
    mapping(address => ParticipantType) public participantTypes;
    mapping(address => ScoreAdjustment[]) public adjustmentHistory;
    mapping(uint256 => Tier) public tiers;
    
    uint256 public adjustmentCounter;
    uint256 public tierCount;
    
    uint256 public constant MAX_SCORE = 10000;
    uint256 public constant INITIAL_SCORE = 5000;
    
    // Scoring weights (basis points)
    uint256 public paymentWeight;
    uint256 public complianceWeight;
    uint256 public volumeWeight;
    uint256 public longevityWeight;
    uint256 public disputeWeight;
    
    event ScoreUpdated(address indexed participant, uint256 newScore, uint256 oldScore);
    event ScoreAdjusted(address indexed participant, int256 adjustment, string reason);
    event ParticipantRegistered(address indexed participant, ParticipantType participantType);
    event TierChanged(address indexed participant, uint256 oldTier, uint256 newTier);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(address admin) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(SCORER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        // Set default weights
        paymentWeight = 3000;      // 30%
        complianceWeight = 2500;   // 25%
        volumeWeight = 2000;       // 20%
        longevityWeight = 1500;    // 15%
        disputeWeight = 1000;      // 10%
        
        // Initialize tiers
        _initializeTiers();
    }
    
    function _initializeTiers() internal {
        tiers[0] = Tier("Bronze", 0, 3000, 100000e18, 0, false);
        tiers[1] = Tier("Silver", 3001, 5000, 500000e18, 100, false);
        tiers[2] = Tier("Gold", 5001, 7000, 2000000e18, 200, true);
        tiers[3] = Tier("Platinum", 7001, 9000, 10000000e18, 300, true);
        tiers[4] = Tier("Diamond", 9001, 10000, type(uint256).max, 500, true);
        tierCount = 5;
    }
    
    function registerParticipant(
        address participant,
        ParticipantType participantType
    ) external onlyRole(ADMIN_ROLE) {
        require(participant != address(0), "Invalid address");
        require(scores[participant].lastUpdate == 0, "Already registered");
        
        participantTypes[participant] = participantType;
        
        scores[participant] = ReputationScore({
            totalScore: INITIAL_SCORE,
            paymentScore: INITIAL_SCORE,
            complianceScore: INITIAL_SCORE,
            volumeScore: INITIAL_SCORE,
            longevityScore: INITIAL_SCORE,
            disputeScore: INITIAL_SCORE,
            lastUpdate: block.timestamp,
            scoreHistory: INITIAL_SCORE
        });
        
        factors[participant] = ScoringFactors({
            totalTransactions: 0,
            successfulTransactions: 0,
            failedTransactions: 0,
            totalVolume: 0,
            onTimePayments: 0,
            latePayments: 0,
            defaults: 0,
            disputes: 0,
            disputesWon: 0,
            accountAge: block.timestamp,
            complianceViolations: 0
        });
        
        emit ParticipantRegistered(participant, participantType);
    }
    
    function updateScore(address participant) 
        external 
        onlyRole(SCORER_ROLE) 
        whenNotPaused 
    {
        require(scores[participant].lastUpdate > 0, "Not registered");
        
        ScoringFactors storage factor = factors[participant];
        ReputationScore storage score = scores[participant];
        
        uint256 oldScore = score.totalScore;
        
        // Calculate component scores
        score.paymentScore = _calculatePaymentScore(factor);
        score.complianceScore = _calculateComplianceScore(factor);
        score.volumeScore = _calculateVolumeScore(factor);
        score.longevityScore = _calculateLongevityScore(factor);
        score.disputeScore = _calculateDisputeScore(factor);
        
        // Calculate weighted total
        uint256 newScore = (
            (score.paymentScore * paymentWeight) +
            (score.complianceScore * complianceWeight) +
            (score.volumeScore * volumeWeight) +
            (score.longevityScore * longevityWeight) +
            (score.disputeScore * disputeWeight)
        ) / 10000;
        
        // Cap at MAX_SCORE
        if (newScore > MAX_SCORE) {
            newScore = MAX_SCORE;
        }
        
        score.totalScore = newScore;
        score.lastUpdate = block.timestamp;
        
        emit ScoreUpdated(participant, newScore, oldScore);
        
        // Check tier change
        _checkTierChange(participant, oldScore, newScore);
    }
    
    function _calculatePaymentScore(ScoringFactors storage factor) 
        internal 
        view 
        returns (uint256) 
    {
        if (factor.totalTransactions == 0) return INITIAL_SCORE;
        
        uint256 successRate = (factor.successfulTransactions * 10000) / factor.totalTransactions;
        uint256 onTimeRate = factor.onTimePayments + factor.latePayments > 0 ?
            (factor.onTimePayments * 10000) / (factor.onTimePayments + factor.latePayments) : 5000;
        
        // Penalize defaults heavily
        uint256 defaultPenalty = factor.defaults * 1000;
        
        uint256 paymentScore = (successRate + onTimeRate) / 2;
        
        if (paymentScore > defaultPenalty) {
            paymentScore -= defaultPenalty;
        } else {
            paymentScore = 0;
        }
        
        return paymentScore > MAX_SCORE ? MAX_SCORE : paymentScore;
    }
    
    function _calculateComplianceScore(ScoringFactors storage factor)
        internal
        view
        returns (uint256) 
    {
        // Start at max, subtract for violations
        uint256 complianceScore = MAX_SCORE;
        uint256 penalty = factor.complianceViolations * 500; // 5% per violation
        
        if (complianceScore > penalty) {
            complianceScore -= penalty;
        } else {
            complianceScore = 0;
        }
        
        return complianceScore;
    }
    
    function _calculateVolumeScore(ScoringFactors storage factor)
        internal
        view
        returns (uint256) 
    {
        // Score based on trading volume
        uint256 volumeScore;
        
        if (factor.totalVolume >= 100000000e18) {
            volumeScore = MAX_SCORE;
        } else if (factor.totalVolume >= 10000000e18) {
            volumeScore = 9000;
        } else if (factor.totalVolume >= 1000000e18) {
            volumeScore = 7500;
        } else if (factor.totalVolume >= 100000e18) {
            volumeScore = 6000;
        } else if (factor.totalVolume >= 10000e18) {
            volumeScore = 4500;
        } else {
            volumeScore = 3000;
        }
        
        return volumeScore;
    }
    
    function _calculateLongevityScore(ScoringFactors storage factor) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 accountAge = block.timestamp - factor.accountAge;
        
        // Score improves with time
        if (accountAge >= 365 days * 3) {
            return MAX_SCORE;
        } else if (accountAge >= 365 days * 2) {
            return 8500;
        } else if (accountAge >= 365 days) {
            return 7000;
        } else if (accountAge >= 180 days) {
            return 5500;
        } else if (accountAge >= 90 days) {
            return 4000;
        } else {
            return 3000;
        }
    }
    
    function _calculateDisputeScore(ScoringFactors storage factor)
        internal
        view
        returns (uint256) 
    {
        if (factor.disputes == 0) return MAX_SCORE;
        
        uint256 winRate = (factor.disputesWon * 10000) / factor.disputes;
        
        // Penalize for having disputes, reward for winning them
        uint256 disputeScore = winRate;
        uint256 penalty = factor.disputes * 200; // 2% per dispute
        
        if (disputeScore > penalty) {
            disputeScore -= penalty;
        } else {
            disputeScore = 0;
        }
        
        return disputeScore > MAX_SCORE ? MAX_SCORE : disputeScore;
    }
    
    function recordTransaction(
        address participant,
        bool successful,
        uint256 volume
    ) external onlyRole(SCORER_ROLE) {
        ScoringFactors storage factor = factors[participant];
        
        factor.totalTransactions++;
        factor.totalVolume += volume;
        
        if (successful) {
            factor.successfulTransactions++;
        } else {
            factor.failedTransactions++;
        }
    }
    
    function recordPayment(
        address participant,
        bool onTime
    ) external onlyRole(SCORER_ROLE) {
        ScoringFactors storage factor = factors[participant];
        
        if (onTime) {
            factor.onTimePayments++;
        } else {
            factor.latePayments++;
        }
    }
    
    function recordDefault(address participant) 
        external 
        onlyRole(SCORER_ROLE) 
    {
        factors[participant].defaults++;
    }
    
    function recordDispute(
        address participant,
        bool won
    ) external onlyRole(SCORER_ROLE) {
        ScoringFactors storage factor = factors[participant];
        
        factor.disputes++;
        if (won) {
            factor.disputesWon++;
        }
    }
    
    function recordComplianceViolation(address participant) 
        external 
        onlyRole(SCORER_ROLE) 
    {
        factors[participant].complianceViolations++;
    }
    
    function adjustScore(
        address participant,
        int256 adjustment,
        string memory reason
    ) external onlyRole(ADMIN_ROLE) {
        require(scores[participant].lastUpdate > 0, "Not registered");
        
        ReputationScore storage score = scores[participant];
        uint256 oldScore = score.totalScore;
        
        if (adjustment > 0) {
            uint256 increase = uint256(adjustment);
            score.totalScore = oldScore + increase > MAX_SCORE ? MAX_SCORE : oldScore + increase;
        } else {
            uint256 decrease = uint256(-adjustment);
            score.totalScore = oldScore > decrease ? oldScore - decrease : 0;
        }
        
        // Record adjustment
        adjustmentHistory[participant].push(ScoreAdjustment({
            adjustmentId: adjustmentCounter++,
            participant: participant,
            adjustment: adjustment,
            reason: reason,
            adjuster: msg.sender,
            timestamp: block.timestamp
        }));
        
        emit ScoreAdjusted(participant, adjustment, reason);
        emit ScoreUpdated(participant, score.totalScore, oldScore);
    }
    
    function _checkTierChange(address participant, uint256 oldScore, uint256 newScore) 
        internal 
    {
        uint256 oldTier = _getTierForScore(oldScore);
        uint256 newTier = _getTierForScore(newScore);
        
        if (oldTier != newTier) {
            emit TierChanged(participant, oldTier, newTier);
        }
    }
    
    function _getTierForScore(uint256 score) internal view returns (uint256) {
        for (uint256 i = 0; i < tierCount; i++) {
            if (score >= tiers[i].minScore && score <= tiers[i].maxScore) {
                return i;
            }
        }
        return 0;
    }
    
    function getTier(address participant) external view returns (Tier memory) {
        uint256 score = scores[participant].totalScore;
        uint256 tierIndex = _getTierForScore(score);
        return tiers[tierIndex];
    }
    
    function setWeights(
        uint256 _paymentWeight,
        uint256 _complianceWeight,
        uint256 _volumeWeight,
        uint256 _longevityWeight,
        uint256 _disputeWeight
    ) external onlyRole(ADMIN_ROLE) {
        require(
            _paymentWeight + _complianceWeight + _volumeWeight + _longevityWeight + _disputeWeight == 10000,
            "Weights must sum to 10000"
        );
        
        paymentWeight = _paymentWeight;
        complianceWeight = _complianceWeight;
        volumeWeight = _volumeWeight;
        longevityWeight = _longevityWeight;
        disputeWeight = _disputeWeight;
    }
    
    function updateTier(
        uint256 tierIndex,
        string memory name,
        uint256 minScore,
        uint256 maxScore,
        uint256 tradingLimit,
        uint256 feeDiscount,
        bool priorityAccess
    ) external onlyRole(ADMIN_ROLE) {
        require(tierIndex < tierCount, "Invalid tier");
        
        tiers[tierIndex] = Tier({
            name: name,
            minScore: minScore,
            maxScore: maxScore,
            tradingLimit: tradingLimit,
            feeDiscount: feeDiscount,
            priorityAccess: priorityAccess
        });
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getScore(address participant) 
        external 
        view 
        returns (ReputationScore memory) 
    {
        return scores[participant];
    }
    
    function getFactors(address participant) 
        external 
        view 
        returns (ScoringFactors memory) 
    {
        return factors[participant];
    }
    
    function getAdjustmentHistory(address participant) 
        external 
        view 
        returns (ScoreAdjustment[] memory) 
    {
        return adjustmentHistory[participant];
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}