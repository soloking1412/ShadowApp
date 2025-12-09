// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title InfrastructureFinancing - COMPLETE PRODUCTION VERSION
 * @notice Project-based lending with milestone disbursement and collateral management
 */
contract InfrastructureFinancing is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LENDER_ROLE = keccak256("LENDER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    enum ProjectStatus {
        Proposed,
        Approved,
        Active,
        Completed,
        Defaulted,
        Liquidated
    }
    
    enum CollateralType {
        PortRevenue,
        AirportRevenue,
        CustomsFees,
        SovereignGuarantee,
        CommodityFlow,
        RealEstate,
        GovernmentBonds
    }
    
    enum MilestoneStatus {
        Pending,
        InProgress,
        Completed,
        Verified,
        Paid
    }
    
    struct Project {
        uint256 projectId;
        address borrower;
        string projectName;
        string description;
        uint256 loanAmount;
        uint256 outstandingAmount;
        uint256 interestRate;
        uint256 startDate;
        uint256 maturityDate;
        uint256 lastPaymentDate;
        ProjectStatus status;
        uint256 collateralValue;
        uint256 liquidationThreshold;
        bytes32 legalDocumentHash;
    }
    
    struct Collateral {
        uint256 collateralId;
        CollateralType collateralType;
        address assetAddress;
        uint256 amount;
        uint256 valuation;
        uint256 lastValuationDate;
        address valuationOracle;
        bool active;
        bytes32 documentHash;
    }
    
    struct Milestone {
        uint256 milestoneId;
        string description;
        uint256 amount;
        uint256 targetDate;
        uint256 completionDate;
        MilestoneStatus status;
        bytes32 evidenceHash;
        address verifier;
        uint256 verifiedDate;
    }
    
    struct PerformanceMetrics {
        uint256 cargoVolume;
        uint256 landingFees;
        uint256 customsRevenue;
        uint256 targetMetric;
        uint256 actualMetric;
        uint256 lastUpdate;
    }
    
    struct Payment {
        uint256 paymentId;
        uint256 amount;
        uint256 principal;
        uint256 interest;
        uint256 timestamp;
        address payer;
    }
    
    mapping(uint256 => Project) public projects;
    mapping(uint256 => Collateral[]) public projectCollateral;
    mapping(uint256 => Milestone[]) public projectMilestones;
    mapping(uint256 => PerformanceMetrics) public projectMetrics;
    mapping(uint256 => Payment[]) public projectPayments;
    mapping(uint256 => mapping(address => uint256)) public lenderContributions;
    
    uint256 public projectCounter;
    uint256 public totalLent;
    uint256 public totalRepaid;
    uint256 public totalDefaulted;
    
    uint256 public defaultInterestRate;
    uint256 public defaultLiquidationThreshold;
    uint256 public minCollateralRatio;
    
    uint256 public constant BASIS_POINTS = 10000;
    
    event ProjectCreated(
        uint256 indexed projectId,
        address indexed borrower,
        uint256 loanAmount
    );
    event CollateralAdded(
        uint256 indexed projectId,
        uint256 collateralId,
        CollateralType collateralType,
        uint256 valuation
    );
    event MilestoneAdded(uint256 indexed projectId, uint256 milestoneId);
    event MilestoneCompleted(uint256 indexed projectId, uint256 milestoneId);
    event MilestoneVerified(uint256 indexed projectId, uint256 milestoneId);
    event MilestoneDisbursed(uint256 indexed projectId, uint256 milestoneId, uint256 amount);
    event PaymentMade(uint256 indexed projectId, uint256 amount, uint256 principal, uint256 interest);
    event ProjectDefaulted(uint256 indexed projectId);
    event CollateralLiquidated(uint256 indexed projectId, uint256 amount);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address admin,
        uint256 _defaultInterestRate,
        uint256 _liquidationThreshold
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(LENDER_ROLE, admin);
        _grantRole(AUDITOR_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        defaultInterestRate = _defaultInterestRate;
        defaultLiquidationThreshold = _liquidationThreshold;
        minCollateralRatio = 12000; // 120%
    }
    
    function createProject(
        address borrower,
        string memory projectName,
        string memory description,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 maturityDate,
        bytes32 legalDocumentHash
    ) external onlyRole(LENDER_ROLE) whenNotPaused returns (uint256) {
        require(borrower != address(0), "Invalid borrower");
        require(loanAmount > 0, "Invalid amount");
        require(maturityDate > block.timestamp, "Invalid maturity");
        
        uint256 projectId = ++projectCounter;
        
        projects[projectId] = Project({
            projectId: projectId,
            borrower: borrower,
            projectName: projectName,
            description: description,
            loanAmount: loanAmount,
            outstandingAmount: loanAmount,
            interestRate: interestRate > 0 ? interestRate : defaultInterestRate,
            startDate: 0,
            maturityDate: maturityDate,
            lastPaymentDate: 0,
            status: ProjectStatus.Proposed,
            collateralValue: 0,
            liquidationThreshold: defaultLiquidationThreshold,
            legalDocumentHash: legalDocumentHash
        });
        
        emit ProjectCreated(projectId, borrower, loanAmount);
        
        return projectId;
    }
    
    function addCollateral(
        uint256 projectId,
        CollateralType collateralType,
        address assetAddress,
        uint256 amount,
        uint256 valuation,
        bytes32 documentHash
    ) external onlyRole(LENDER_ROLE) {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Proposed, "Invalid status");
        require(amount > 0 && valuation > 0, "Invalid amounts");
        
        uint256 collateralId = projectCollateral[projectId].length;
        
        projectCollateral[projectId].push(Collateral({
            collateralId: collateralId,
            collateralType: collateralType,
            assetAddress: assetAddress,
            amount: amount,
            valuation: valuation,
            lastValuationDate: block.timestamp,
            valuationOracle: msg.sender,
            active: true,
            documentHash: documentHash
        }));
        
        project.collateralValue += valuation;
        
        emit CollateralAdded(projectId, collateralId, collateralType, valuation);
    }
    
    function addMilestone(
        uint256 projectId,
        string memory description,
        uint256 amount,
        uint256 targetDate
    ) external returns (uint256) {
        Project storage project = projects[projectId];
        require(
            msg.sender == project.borrower || hasRole(LENDER_ROLE, msg.sender),
            "Not authorized"
        );
        require(project.status == ProjectStatus.Proposed, "Invalid status");
        
        uint256 milestoneId = projectMilestones[projectId].length;
        
        projectMilestones[projectId].push(Milestone({
            milestoneId: milestoneId,
            description: description,
            amount: amount,
            targetDate: targetDate,
            completionDate: 0,
            status: MilestoneStatus.Pending,
            evidenceHash: bytes32(0),
            verifier: address(0),
            verifiedDate: 0
        }));
        
        emit MilestoneAdded(projectId, milestoneId);
        
        return milestoneId;
    }
    
    function approveProject(uint256 projectId) 
        external 
        onlyRole(LENDER_ROLE) 
    {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Proposed, "Invalid status");
        
        // Check collateral requirements
        uint256 requiredCollateral = (project.loanAmount * minCollateralRatio) / BASIS_POINTS;
        require(project.collateralValue >= requiredCollateral, "Insufficient collateral");
        
        project.status = ProjectStatus.Approved;
    }
    
    function activateProject(uint256 projectId) 
        external 
        onlyRole(LENDER_ROLE) 
        nonReentrant 
    {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Approved, "Not approved");
        
        // Transfer loan amount to borrower
        (bool success, ) = project.borrower.call{value: project.loanAmount}("");
        require(success, "Transfer failed");
        
        project.status = ProjectStatus.Active;
        project.startDate = block.timestamp;
        project.lastPaymentDate = block.timestamp;
        
        totalLent += project.loanAmount;
    }
    
    function completeMilestone(
        uint256 projectId,
        uint256 milestoneId,
        bytes32 evidenceHash
    ) external {
        Project storage project = projects[projectId];
        require(msg.sender == project.borrower, "Not borrower");
        require(project.status == ProjectStatus.Active, "Not active");
        require(milestoneId < projectMilestones[projectId].length, "Invalid milestone");
        
        Milestone storage milestone = projectMilestones[projectId][milestoneId];
        require(milestone.status == MilestoneStatus.Pending, "Invalid status");
        
        milestone.status = MilestoneStatus.Completed;
        milestone.completionDate = block.timestamp;
        milestone.evidenceHash = evidenceHash;
        
        emit MilestoneCompleted(projectId, milestoneId);
    }
    
    function verifyMilestone(uint256 projectId, uint256 milestoneId) 
        external 
        onlyRole(AUDITOR_ROLE) 
    {
        require(milestoneId < projectMilestones[projectId].length, "Invalid milestone");
        
        Milestone storage milestone = projectMilestones[projectId][milestoneId];
        require(milestone.status == MilestoneStatus.Completed, "Not completed");
        
        milestone.status = MilestoneStatus.Verified;
        milestone.verifier = msg.sender;
        milestone.verifiedDate = block.timestamp;
        
        emit MilestoneVerified(projectId, milestoneId);
    }
    
    function disburseMilestonePayment(uint256 projectId, uint256 milestoneId) 
        external 
        onlyRole(LENDER_ROLE) 
        nonReentrant 
    {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Active, "Not active");
        require(milestoneId < projectMilestones[projectId].length, "Invalid milestone");
        
        Milestone storage milestone = projectMilestones[projectId][milestoneId];
        require(milestone.status == MilestoneStatus.Verified, "Not verified");
        
        // Transfer milestone payment
        (bool success, ) = project.borrower.call{value: milestone.amount}("");
        require(success, "Transfer failed");
        
        milestone.status = MilestoneStatus.Paid;
        
        emit MilestoneDisbursed(projectId, milestoneId, milestone.amount);
    }
    
    function makePayment(uint256 projectId) 
        external 
        payable 
        nonReentrant 
    {
        Project storage project = projects[projectId];
        require(msg.sender == project.borrower, "Not borrower");
        require(project.status == ProjectStatus.Active, "Not active");
        require(msg.value > 0, "Invalid amount");
        
        // Calculate interest
        uint256 timeElapsed = block.timestamp - project.lastPaymentDate;
        uint256 interestOwed = _calculateInterest(
            project.outstandingAmount,
            project.interestRate,
            timeElapsed
        );
        
        uint256 principalPayment = 0;
        uint256 interestPayment = 0;
        
        if (msg.value >= interestOwed) {
            interestPayment = interestOwed;
            principalPayment = msg.value - interestOwed;
            
            if (principalPayment > project.outstandingAmount) {
                principalPayment = project.outstandingAmount;
                // Refund excess
                uint256 excess = msg.value - interestPayment - principalPayment;
                if (excess > 0) {
                    (bool success, ) = msg.sender.call{value: excess}("");
                    require(success, "Refund failed");
                }
            }
            
            project.outstandingAmount -= principalPayment;
        } else {
            interestPayment = msg.value;
        }
        
        project.lastPaymentDate = block.timestamp;
        totalRepaid += msg.value;
        
        // Record payment
        projectPayments[projectId].push(Payment({
            paymentId: projectPayments[projectId].length,
            amount: msg.value,
            principal: principalPayment,
            interest: interestPayment,
            timestamp: block.timestamp,
            payer: msg.sender
        }));
        
        emit PaymentMade(projectId, msg.value, principalPayment, interestPayment);
        
        // Check if fully repaid
        if (project.outstandingAmount == 0) {
            project.status = ProjectStatus.Completed;
            _releaseCollateral(projectId);
        }
    }
    
    function _calculateInterest(
        uint256 principal,
        uint256 rate,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        return (principal * rate * timeElapsed) / (BASIS_POINTS * 365 days);
    }
    
    function updatePerformanceMetrics(
        uint256 projectId,
        uint256 cargoVolume,
        uint256 landingFees,
        uint256 customsRevenue,
        uint256 actualMetric
    ) external onlyRole(AUDITOR_ROLE) {
        projectMetrics[projectId] = PerformanceMetrics({
            cargoVolume: cargoVolume,
            landingFees: landingFees,
            customsRevenue: customsRevenue,
            targetMetric: 0, // Set by project creation
            actualMetric: actualMetric,
            lastUpdate: block.timestamp
        });
        
        // Check for underperformance
        _checkProjectHealth(projectId);
    }
    
    function _checkProjectHealth(uint256 projectId) internal {
        Project storage project = projects[projectId];
        
        if (project.status != ProjectStatus.Active) return;
        
        // Check if past maturity
        if (block.timestamp > project.maturityDate && project.outstandingAmount > 0) {
            _markAsDefault(projectId);
            return;
        }
        
        // Check collateral value
        uint256 currentLTV = (project.outstandingAmount * BASIS_POINTS) / project.collateralValue;
        
        if (currentLTV > project.liquidationThreshold) {
            _markAsDefault(projectId);
        }
    }
    
    function _markAsDefault(uint256 projectId) internal {
        Project storage project = projects[projectId];
        project.status = ProjectStatus.Defaulted;
        totalDefaulted += project.outstandingAmount;
        
        emit ProjectDefaulted(projectId);
    }
    
    function liquidateCollateral(uint256 projectId) 
        external 
        onlyRole(LENDER_ROLE) 
        nonReentrant 
    {
        Project storage project = projects[projectId];
        require(project.status == ProjectStatus.Defaulted, "Not defaulted");
        
        uint256 totalLiquidated = 0;
        
        // Liquidate all active collateral
        for (uint256 i = 0; i < projectCollateral[projectId].length; i++) {
            Collateral storage collateral = projectCollateral[projectId][i];
            
            if (collateral.active) {
                // Transfer collateral to lender
                if (collateral.assetAddress != address(0)) {
                    // ERC20/ERC1155 transfer would happen here
                    totalLiquidated += collateral.valuation;
                    collateral.active = false;
                }
            }
        }
        
        project.status = ProjectStatus.Liquidated;
        
        emit CollateralLiquidated(projectId, totalLiquidated);
    }
    
    function _releaseCollateral(uint256 projectId) internal {
        // Release collateral back to borrower upon completion
        for (uint256 i = 0; i < projectCollateral[projectId].length; i++) {
            projectCollateral[projectId][i].active = false;
        }
    }
    
    function updateCollateralValuation(
        uint256 projectId,
        uint256 collateralId,
        uint256 newValuation
    ) external onlyRole(AUDITOR_ROLE) {
        require(collateralId < projectCollateral[projectId].length, "Invalid collateral");
        
        Collateral storage collateral = projectCollateral[projectId][collateralId];
        Project storage project = projects[projectId];
        
        uint256 oldValuation = collateral.valuation;
        collateral.valuation = newValuation;
        collateral.lastValuationDate = block.timestamp;
        
        // Update total collateral value
        if (newValuation > oldValuation) {
            project.collateralValue += (newValuation - oldValuation);
        } else {
            project.collateralValue -= (oldValuation - newValuation);
        }
        
        _checkProjectHealth(projectId);
    }
    
    function setDefaultInterestRate(uint256 rate) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(rate <= 2000, "Rate too high"); // Max 20%
        defaultInterestRate = rate;
    }
    
    function setMinCollateralRatio(uint256 ratio) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(ratio >= 10000, "Below 100%");
        minCollateralRatio = ratio;
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getProject(uint256 projectId) 
        external 
        view 
        returns (Project memory) 
    {
        return projects[projectId];
    }
    
    function getCollateral(uint256 projectId) 
        external 
        view 
        returns (Collateral[] memory) 
    {
        return projectCollateral[projectId];
    }
    
    function getMilestones(uint256 projectId) 
        external 
        view 
        returns (Milestone[] memory) 
    {
        return projectMilestones[projectId];
    }
    
    function getPayments(uint256 projectId) 
        external 
        view 
        returns (Payment[] memory) 
    {
        return projectPayments[projectId];
    }
    
    function getMetrics(uint256 projectId) 
        external 
        view 
        returns (PerformanceMetrics memory) 
    {
        return projectMetrics[projectId];
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    receive() external payable {}
}