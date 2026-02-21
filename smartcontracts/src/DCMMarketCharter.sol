// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title DCMMarketCharter
 * @notice 4-Pillar Market Health Charter for the SGM Decentralized Capital Markets (DCM) platform.
 *
 *  Pillar 1 — Public Market Health       (score 0–100, 4 metrics)
 *  Pillar 2 — Global Market Health        (score 0–100, 4 metrics)
 *  Pillar 3 — Corporate Financial Health  (score 0–100, 4 metrics)
 *  Pillar 4 — Public Financial Health     (score 0–100, 4 metrics)
 *
 *  Total composite: 0–400 (400 = perfect health)
 *
 *  Subscription tiers: $3/month (retail) | $8/month (institutional)
 *  Revenue model: 0.09% transaction fee (9 bps) + CFI equity 15%
 *
 * @dev UUPS upgradeable proxy.
 */
contract DCMMarketCharter is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // ─────────────────────────────────────────────
    //  Constants
    // ─────────────────────────────────────────────

    uint8 public constant PILLARS   = 4;
    uint8 public constant METRICS   = 4;   // per pillar
    uint16 public constant MAX_SCORE = 400; // 4 pillars × 100

    // ─────────────────────────────────────────────
    //  Data Structures
    // ─────────────────────────────────────────────

    struct Metric {
        string  name;
        uint8   score;        // 0–100
        string  description;
        uint256 updatedAt;
    }

    struct Pillar {
        string   name;
        Metric[4] metrics;
        uint8    pillarScore; // average of 4 metric scores (0–100)
        uint256  updatedAt;
    }

    struct HealthReport {
        uint16  totalScore;   // 0–400
        uint8   pillar1;
        uint8   pillar2;
        uint8   pillar3;
        uint8   pillar4;
        uint256 reportedAt;
        address reportedBy;
    }

    struct Subscriber {
        bool    active;
        uint8   tier;         // 1 = retail ($3), 2 = institutional ($8)
        uint256 expiresAt;
    }

    // ─────────────────────────────────────────────
    //  State
    // ─────────────────────────────────────────────

    Pillar[4] public pillars;
    HealthReport[] public reports;

    mapping(address => Subscriber) public subscribers;

    uint256 public retailFeePerMonth;       // in OICD wei
    uint256 public institutionalFeePerMonth; // in OICD wei
    uint256 public transactionFeeBps;        // 9 bps

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────

    event MetricUpdated(uint8 pillarIdx, uint8 metricIdx, uint8 score, string name);
    event HealthReportPublished(uint256 indexed reportId, uint16 totalScore, address reporter);
    event SubscriberAdded(address indexed subscriber, uint8 tier, uint256 expiresAt);

    // ─────────────────────────────────────────────
    //  Initializer
    // ─────────────────────────────────────────────

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        retailFeePerMonth        = 3 * 1e18;   // $3 equivalent in OICD
        institutionalFeePerMonth = 8 * 1e18;   // $8 equivalent in OICD
        transactionFeeBps        = 9;           // 0.09%

        // ── Pillar 1: Public Market Health ──────────────────────────
        pillars[0].name = "Public Market Health";
        pillars[0].metrics[0] = Metric("Market Liquidity Index",    75, "Bid-ask spread and depth across DTX centers", 0);
        pillars[0].metrics[1] = Metric("Price Discovery Efficiency", 80, "Time for price convergence after news events",  0);
        pillars[0].metrics[2] = Metric("Volatility Index",          70, "30-day rolling volatility vs baseline",         0);
        pillars[0].metrics[3] = Metric("Trading Volume Growth",     65, "Quarter-over-quarter volume change (%)",         0);

        // ── Pillar 2: Global Market Health ──────────────────────────
        pillars[1].name = "Global Market Health";
        pillars[1].metrics[0] = Metric("Cross-Border Flow Index",   72, "DTX-to-DTX cross-center settlement efficiency", 0);
        pillars[1].metrics[1] = Metric("FX Stability Score",        68, "OICD vs fiat basket volatility",                0);
        pillars[1].metrics[2] = Metric("Global Exchange Coverage",  85, "% of 80+ stock exchanges integrated",           0);
        pillars[1].metrics[3] = Metric("Port Trade Activity",       77, "Cargo volume across 500+ world ports",          0);

        // ── Pillar 3: Corporate Financial Health ────────────────────
        pillars[2].name = "Corporate Financial Health";
        pillars[2].metrics[0] = Metric("EPS Growth Rate",           73, "Earnings-per-share growth across DTX listings", 0);
        pillars[2].metrics[1] = Metric("Debt-to-Equity Ratio",      60, "Average leverage ratio of listed companies",    0);
        pillars[2].metrics[2] = Metric("Dividend Yield",            78, "Avg. dividend yield, DTX-listed companies",     0);
        pillars[2].metrics[3] = Metric("Revenue Growth",            82, "Quarter-over-quarter revenue growth (%)",       0);

        // ── Pillar 4: Public Financial Health ───────────────────────
        pillars[3].name = "Public Financial Health";
        pillars[3].metrics[0] = Metric("Orion Score Average",       76, "Average Orion 9-variable score across nations", 0);
        pillars[3].metrics[1] = Metric("Sovereign Debt Rating",     71, "Avg. sovereign debt-to-GDP across member states",0);
        pillars[3].metrics[2] = Metric("Inflation Control Index",   74, "CPI stability vs OICD anchor",                  0);
        pillars[3].metrics[3] = Metric("Banking System Score",      79, "Reserve ratios and systemic risk exposure",     0);

        _recalcPillarScores();
    }

    // ─────────────────────────────────────────────
    //  Metric Updates (Owner / Oracle)
    // ─────────────────────────────────────────────

    /**
     * @notice Update a single metric score.
     * @param _pillarIdx  Pillar index (0–3)
     * @param _metricIdx  Metric index (0–3)
     * @param _score      New score (0–100)
     */
    function updateMetric(uint8 _pillarIdx, uint8 _metricIdx, uint8 _score) external onlyOwner {
        require(_pillarIdx < PILLARS, "DCM: invalid pillar");
        require(_metricIdx < METRICS, "DCM: invalid metric");
        require(_score <= 100, "DCM: score > 100");

        Metric storage m = pillars[_pillarIdx].metrics[_metricIdx];
        m.score     = _score;
        m.updatedAt = block.timestamp;

        _recalcPillarScores();

        emit MetricUpdated(_pillarIdx, _metricIdx, _score, m.name);
    }

    /**
     * @notice Batch-update all 16 metrics at once.
     * @param _scores Flat array [p0m0, p0m1, p0m2, p0m3, p1m0, ...] (16 values, each 0–100)
     */
    function updateAllMetrics(uint8[16] calldata _scores) external onlyOwner {
        for (uint8 p = 0; p < PILLARS; p++) {
            for (uint8 m = 0; m < METRICS; m++) {
                uint8 s = _scores[p * METRICS + m];
                require(s <= 100, "DCM: score > 100");
                pillars[p].metrics[m].score     = s;
                pillars[p].metrics[m].updatedAt = block.timestamp;
            }
        }
        _recalcPillarScores();
    }

    /**
     * @notice Publish a health report (snapshot) on-chain.
     */
    function publishReport() external returns (uint256 reportId) {
        _recalcPillarScores();

        uint16 total = uint16(pillars[0].pillarScore)
                     + uint16(pillars[1].pillarScore)
                     + uint16(pillars[2].pillarScore)
                     + uint16(pillars[3].pillarScore);

        reportId = reports.length;
        reports.push(HealthReport({
            totalScore: total,
            pillar1:    pillars[0].pillarScore,
            pillar2:    pillars[1].pillarScore,
            pillar3:    pillars[2].pillarScore,
            pillar4:    pillars[3].pillarScore,
            reportedAt: block.timestamp,
            reportedBy: msg.sender
        }));

        emit HealthReportPublished(reportId, total, msg.sender);
    }

    // ─────────────────────────────────────────────
    //  Subscriptions
    // ─────────────────────────────────────────────

    /**
     * @notice Register or renew a subscription.
     * @param _subscriber Address to subscribe
     * @param _tier       1 = retail, 2 = institutional
     * @param _months     Number of months
     */
    function subscribe(address _subscriber, uint8 _tier, uint256 _months) external onlyOwner {
        require(_tier == 1 || _tier == 2, "DCM: invalid tier");
        require(_months > 0, "DCM: zero months");

        Subscriber storage s = subscribers[_subscriber];
        uint256 expiry = block.timestamp > s.expiresAt
            ? block.timestamp + (_months * 30 days)
            : s.expiresAt + (_months * 30 days);

        s.active    = true;
        s.tier      = _tier;
        s.expiresAt = expiry;

        emit SubscriberAdded(_subscriber, _tier, expiry);
    }

    function isActiveSubscriber(address _addr) external view returns (bool) {
        Subscriber memory s = subscribers[_addr];
        return s.active && block.timestamp <= s.expiresAt;
    }

    // ─────────────────────────────────────────────
    //  Admin
    // ─────────────────────────────────────────────

    function setFees(uint256 _retailFee, uint256 _institutionalFee) external onlyOwner {
        retailFeePerMonth        = _retailFee;
        institutionalFeePerMonth = _institutionalFee;
    }

    // ─────────────────────────────────────────────
    //  View Helpers
    // ─────────────────────────────────────────────

    function getCurrentScore() external view returns (uint16 total, uint8 p1, uint8 p2, uint8 p3, uint8 p4) {
        p1 = pillars[0].pillarScore;
        p2 = pillars[1].pillarScore;
        p3 = pillars[2].pillarScore;
        p4 = pillars[3].pillarScore;
        total = uint16(p1) + uint16(p2) + uint16(p3) + uint16(p4);
    }

    function getPillar(uint8 _idx) external view returns (
        string memory name,
        uint8 score,
        string[4] memory metricNames,
        uint8[4]  memory metricScores
    ) {
        Pillar storage p = pillars[_idx];
        name  = p.name;
        score = p.pillarScore;
        for (uint8 i = 0; i < 4; i++) {
            metricNames[i]  = p.metrics[i].name;
            metricScores[i] = p.metrics[i].score;
        }
    }

    function getReport(uint256 _id) external view returns (HealthReport memory) {
        return reports[_id];
    }

    function reportCount() external view returns (uint256) { return reports.length; }

    // ─────────────────────────────────────────────
    //  Internal
    // ─────────────────────────────────────────────

    function _recalcPillarScores() internal {
        for (uint8 p = 0; p < PILLARS; p++) {
            uint16 sum = 0;
            for (uint8 m = 0; m < METRICS; m++) {
                sum += pillars[p].metrics[m].score;
            }
            pillars[p].pillarScore = uint8(sum / METRICS);
            pillars[p].updatedAt   = block.timestamp;
        }
    }

    // ─────────────────────────────────────────────
    //  UUPS
    // ─────────────────────────────────────────────

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
