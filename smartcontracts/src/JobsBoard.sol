// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title JobsBoard — OICD Employment Marketplace
/// @notice Implements Obsidian Capital's employment ecosystem.
///         Members earn OICD for completing jobs across 5 clearance levels:
///
///         STANDARD:
///           Small:  1–15,000 OICD
///           Medium: 15,001–35,000 OICD
///           Large:  35,001–70,000 OICD
///
///         SPECIAL CONTRACTS (Alpha–Echo clearance required):
///           Alpha:  $100K–$1M OICD
///           Bravo:  $10M OICD + stock (management clearance)
///           Charlie: stock only (30K–70K OTD stock)
///           Delta:  stock only (1M–10M OTD stock)
///           Echo:   stock + break % recurring revenue
contract JobsBoard is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    enum JobLevel { Small, Medium, Large, Alpha, Bravo, Charlie, Delta, Echo }

    enum JobCategory {
        Finance, Marketing, Technology, Creative, Videography,
        DataAnalysis, Infrastructure, Research, Legal, Operations
    }

    enum JobStatus { Open, Filled, InProgress, Completed, Cancelled, Disputed }

    enum ClearanceLevel { None, Alpha, Bravo, Charlie, Delta, Echo }

    struct Job {
        uint256 jobId;
        address poster;
        JobLevel level;
        JobCategory category;
        JobStatus status;
        string  title;
        string  description;
        uint256 payOICD;          // 1e18 scaled
        uint256 stockUnits;       // OTD stock units (for Bravo/Charlie/Delta/Echo)
        uint256 breakPct;         // recurring revenue % (for Echo), in bps: 300 = 3%
        ClearanceLevel clearance;
        uint256 postedAt;
        uint256 deadline;
        address assignedWorker;
        uint256 completedAt;
        bool    paid;
        string  ipfsDetails;      // additional job details
    }

    struct Application {
        uint256 applicationId;
        uint256 jobId;
        address applicant;
        string  coverNote;
        uint256 appliedAt;
        bool    accepted;
        bool    rejected;
    }

    struct WorkerProfile {
        address worker;
        uint256 totalEarnedOICD;
        uint256 totalStockEarned;
        uint256 jobsCompleted;
        ClearanceLevel clearance;
        uint8   reputationScore;  // 0–100
        uint256[] completedJobIds;
        bool    exists;
    }

    // -- Storage --
    uint256 public jobCounter;
    uint256 public applicationCounter;
    uint256 public totalJobsPosted;
    uint256 public totalJobsCompleted;
    uint256 public totalOICDDistributed;
    uint256 public totalStockDistributed;

    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Application) public applications;
    mapping(address => uint256[]) public posterJobs;
    mapping(address => uint256[]) public workerApplications;
    mapping(address => WorkerProfile) public workerProfiles;
    mapping(uint256 => uint256[]) public jobApplications;  // jobId => applicationIds
    mapping(address => bool) public authorizedPosters;

    // Pay ranges (in OICD units * 1e18)
    uint256 public constant SMALL_MIN   = 1 * 1e18;
    uint256 public constant SMALL_MAX   = 15_000 * 1e18;
    uint256 public constant MEDIUM_MIN  = 15_001 * 1e18;
    uint256 public constant MEDIUM_MAX  = 35_000 * 1e18;
    uint256 public constant LARGE_MIN   = 35_001 * 1e18;
    uint256 public constant LARGE_MAX   = 70_000 * 1e18;
    uint256 public constant ALPHA_MIN   = 100_000 * 1e18;
    uint256 public constant ALPHA_MAX   = 1_000_000 * 1e18;
    uint256 public constant BRAVO_MIN   = 10_000_000 * 1e18;

    // -- Events --
    event JobPosted(uint256 indexed jobId, address poster, JobLevel level, uint256 payOICD, string title);
    event JobApplied(uint256 indexed applicationId, uint256 indexed jobId, address applicant);
    event WorkerHired(uint256 indexed jobId, address worker);
    event JobCompleted(uint256 indexed jobId, address worker, uint256 payOICD, uint256 stock);
    event JobCancelled(uint256 indexed jobId);
    event ClearanceGranted(address indexed worker, ClearanceLevel clearance);
    event ReputationUpdated(address indexed worker, uint8 score);
    event PosterAuthorized(address poster, bool status);

    modifier onlyPoster() {
        require(authorizedPosters[msg.sender] || msg.sender == owner(), "Not authorized poster");
        _;
    }

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    // -- Poster Management --

    function authorizePoster(address poster, bool status) external onlyOwner {
        authorizedPosters[poster] = status;
        emit PosterAuthorized(poster, status);
    }

    // -- Post Jobs --

    function postJob(
        JobLevel level,
        JobCategory category,
        string calldata title,
        string calldata description,
        uint256 payOICD,
        uint256 stockUnits,
        uint256 breakPct,
        ClearanceLevel clearance,
        uint256 deadlineDays,
        string calldata ipfsDetails
    ) external onlyPoster returns (uint256 jobId) {
        _validateJobPay(level, payOICD);

        jobId = ++jobCounter;
        jobs[jobId] = Job({
            jobId: jobId,
            poster: msg.sender,
            level: level,
            category: category,
            status: JobStatus.Open,
            title: title,
            description: description,
            payOICD: payOICD,
            stockUnits: stockUnits,
            breakPct: breakPct,
            clearance: clearance,
            postedAt: block.timestamp,
            deadline: block.timestamp + deadlineDays * 1 days,
            assignedWorker: address(0),
            completedAt: 0,
            paid: false,
            ipfsDetails: ipfsDetails
        });

        posterJobs[msg.sender].push(jobId);
        totalJobsPosted++;
        emit JobPosted(jobId, msg.sender, level, payOICD, title);
    }

    function _validateJobPay(JobLevel level, uint256 pay) internal pure {
        if (level == JobLevel.Small)  require(pay >= SMALL_MIN  && pay <= SMALL_MAX,  "Small: 1-15K OICD");
        if (level == JobLevel.Medium) require(pay >= MEDIUM_MIN && pay <= MEDIUM_MAX, "Medium: 15K-35K OICD");
        if (level == JobLevel.Large)  require(pay >= LARGE_MIN  && pay <= LARGE_MAX,  "Large: 35K-70K OICD");
        if (level == JobLevel.Alpha)  require(pay >= ALPHA_MIN  && pay <= ALPHA_MAX,  "Alpha: 100K-1M OICD");
        if (level == JobLevel.Bravo)  require(pay >= BRAVO_MIN,                       "Bravo: 10M+ OICD");
    }

    // -- Apply for Jobs --

    function applyForJob(uint256 jobId, string calldata coverNote) external returns (uint256 applicationId) {
        Job storage j = jobs[jobId];
        require(j.status == JobStatus.Open, "Job not open");
        require(j.deadline == 0 || block.timestamp < j.deadline, "Past deadline");
        require(j.poster != msg.sender, "Cannot apply to own job");

        // Check clearance
        WorkerProfile storage wp = workerProfiles[msg.sender];
        if (j.clearance != ClearanceLevel.None) {
            require(uint8(wp.clearance) >= uint8(j.clearance), "Insufficient clearance");
        }

        // Register worker profile if first time
        if (!wp.exists) {
            wp.worker = msg.sender;
            wp.clearance = ClearanceLevel.None;
            wp.reputationScore = 50;
            wp.exists = true;
        }

        applicationId = ++applicationCounter;
        applications[applicationId] = Application({
            applicationId: applicationId,
            jobId: jobId,
            applicant: msg.sender,
            coverNote: coverNote,
            appliedAt: block.timestamp,
            accepted: false,
            rejected: false
        });

        workerApplications[msg.sender].push(applicationId);
        jobApplications[jobId].push(applicationId);
        emit JobApplied(applicationId, jobId, msg.sender);
    }

    // -- Hire Worker --

    function hireWorker(uint256 jobId, address worker) external {
        Job storage j = jobs[jobId];
        require(j.poster == msg.sender || msg.sender == owner(), "Not poster");
        require(j.status == JobStatus.Open, "Job not open");
        require(worker != address(0), "Invalid worker");

        j.status = JobStatus.InProgress;
        j.assignedWorker = worker;
        emit WorkerHired(jobId, worker);
    }

    // -- Complete & Pay --

    function markJobComplete(uint256 jobId) external nonReentrant {
        Job storage j = jobs[jobId];
        require(j.poster == msg.sender || msg.sender == owner(), "Not poster");
        require(j.status == JobStatus.InProgress, "Not in progress");
        require(j.assignedWorker != address(0), "No worker assigned");

        j.status = JobStatus.Completed;
        j.completedAt = block.timestamp;
        j.paid = true;

        // Update worker profile
        WorkerProfile storage wp = workerProfiles[j.assignedWorker];
        if (!wp.exists) {
            wp.worker = j.assignedWorker;
            wp.clearance = ClearanceLevel.None;
            wp.reputationScore = 50;
            wp.exists = true;
        }
        wp.totalEarnedOICD += j.payOICD;
        wp.totalStockEarned += j.stockUnits;
        wp.jobsCompleted++;
        wp.completedJobIds.push(jobId);
        if (wp.reputationScore < 95) wp.reputationScore += 5;

        totalJobsCompleted++;
        totalOICDDistributed += j.payOICD;
        totalStockDistributed += j.stockUnits;

        emit JobCompleted(jobId, j.assignedWorker, j.payOICD, j.stockUnits);
    }

    function cancelJob(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(j.poster == msg.sender || msg.sender == owner(), "Not poster");
        require(j.status == JobStatus.Open || j.status == JobStatus.InProgress, "Cannot cancel");
        j.status = JobStatus.Cancelled;
        emit JobCancelled(jobId);
    }

    // -- Clearance Management --

    function grantClearance(address worker, ClearanceLevel clearance) external onlyOwner {
        if (!workerProfiles[worker].exists) {
            workerProfiles[worker].worker = worker;
            workerProfiles[worker].reputationScore = 50;
            workerProfiles[worker].exists = true;
        }
        workerProfiles[worker].clearance = clearance;
        emit ClearanceGranted(worker, clearance);
    }

    function updateReputation(address worker, uint8 score) external onlyOwner {
        require(score <= 100, "Max 100");
        workerProfiles[worker].reputationScore = score;
        emit ReputationUpdated(worker, score);
    }

    // -- Views --

    function getJob(uint256 jobId) external view returns (Job memory) {
        return jobs[jobId];
    }

    function getApplication(uint256 appId) external view returns (Application memory) {
        return applications[appId];
    }

    function getWorkerProfile(address worker) external view returns (WorkerProfile memory) {
        return workerProfiles[worker];
    }

    function getPosterJobs(address poster) external view returns (uint256[] memory) {
        return posterJobs[poster];
    }

    function getWorkerApplications(address worker) external view returns (uint256[] memory) {
        return workerApplications[worker];
    }

    function getJobApplications(uint256 jobId) external view returns (uint256[] memory) {
        return jobApplications[jobId];
    }

    function boardStats() external view returns (
        uint256 totalPosted,
        uint256 totalCompleted,
        uint256 totalOICD,
        uint256 totalStock
    ) {
        totalPosted    = totalJobsPosted;
        totalCompleted = totalJobsCompleted;
        totalOICD      = totalOICDDistributed;
        totalStock     = totalStockDistributed;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
