// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title OICDEscrow - COMPLETE PRODUCTION VERSION
 * @notice Milestone-based escrow with dispute resolution
 */
contract OICDEscrow is 
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    enum EscrowState {
        Proposed,
        Active,
        Completed,
        Disputed,
        Resolved,
        Cancelled,
        Released
    }
    
    enum MilestoneState {
        Pending,
        InProgress,
        Completed,
        Verified,
        Disputed
    }
    
    struct Escrow {
        uint256 escrowId;
        address buyer;
        address seller;
        address arbiter;
        address token;
        uint256 tokenId;
        uint256 amount;
        uint256 fee;
        EscrowState state;
        uint256 createdAt;
        uint256 timelockDuration;
        uint256 unlockTime;
        bool hasMilestones;
        bytes32 agreementHash;
    }
    
    struct Milestone {
        uint256 milestoneId;
        string description;
        uint256 amount;
        MilestoneState state;
        uint256 dueDate;
        uint256 completedAt;
        bool buyerApproved;
        bool sellerConfirmed;
        bytes32 evidenceHash;
    }
    
    struct Dispute {
        uint256 disputeId;
        uint256 escrowId;
        address initiator;
        string reason;
        uint256 createdAt;
        uint256 resolvedAt;
        address resolver;
        string resolution;
        bool resolved;
    }
    
    mapping(uint256 => Escrow) public escrows;
    mapping(uint256 => Milestone[]) public escrowMilestones;
    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => uint256) public escrowToDispute;
    
    uint256 public escrowCounter;
    uint256 public disputeCounter;
    
    uint256 public feeRate;
    address public feeCollector;
    uint256 public defaultTimelockDuration;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public totalFeesCollected;
    
    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed buyer,
        address indexed seller,
        uint256 amount
    );
    event EscrowFunded(uint256 indexed escrowId, uint256 amount);
    event MilestoneAdded(uint256 indexed escrowId, uint256 milestoneId);
    event MilestoneCompleted(uint256 indexed escrowId, uint256 milestoneId);
    event MilestoneVerified(uint256 indexed escrowId, uint256 milestoneId);
    event EscrowReleased(uint256 indexed escrowId, uint256 amount);
    event EscrowCancelled(uint256 indexed escrowId);
    event DisputeCreated(uint256 indexed disputeId, uint256 indexed escrowId);
    event DisputeResolved(uint256 indexed disputeId, string resolution);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address admin,
        address _feeCollector,
        uint256 _feeRate,
        uint256 _timelockDuration
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(ARBITER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        feeCollector = _feeCollector;
        feeRate = _feeRate;
        defaultTimelockDuration = _timelockDuration;
    }
    
    function createEscrow(
        address seller,
        address arbiter,
        address token,
        uint256 tokenId,
        uint256 amount,
        uint256 timelockDuration,
        bytes32 agreementHash
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(seller != address(0) && seller != msg.sender, "Invalid seller");
        require(amount > 0, "Invalid amount");
        
        uint256 escrowId = ++escrowCounter;
        uint256 fee = (amount * feeRate) / BASIS_POINTS;
        
        escrows[escrowId] = Escrow({
            escrowId: escrowId,
            buyer: msg.sender,
            seller: seller,
            arbiter: arbiter != address(0) ? arbiter : address(this),
            token: token,
            tokenId: tokenId,
            amount: amount,
            fee: fee,
            state: EscrowState.Proposed,
            createdAt: block.timestamp,
            timelockDuration: timelockDuration > 0 ? timelockDuration : defaultTimelockDuration,
            unlockTime: 0,
            hasMilestones: false,
            agreementHash: agreementHash
        });
        
        emit EscrowCreated(escrowId, msg.sender, seller, amount);
        
        return escrowId;
    }
    
    function fundEscrow(uint256 escrowId)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.Proposed, "Invalid state");
        require(msg.sender == escrow.buyer, "Not buyer");

        // Transfer tokens to escrow
        if (escrow.token == address(0)) {
            // ETH escrow
            require(msg.value == escrow.amount + escrow.fee, "Incorrect amount");
        } else {
            // ERC-20 or ERC-1155
            IERC1155(escrow.token).safeTransferFrom(
                msg.sender,
                address(this),
                escrow.tokenId,
                escrow.amount + escrow.fee,
                ""
            );
        }
        
        escrow.state = EscrowState.Active;
        escrow.unlockTime = block.timestamp + escrow.timelockDuration;
        
        emit EscrowFunded(escrowId, escrow.amount);
    }
    
    function addMilestone(
        uint256 escrowId,
        string memory description,
        uint256 amount,
        uint256 dueDate
    ) external returns (uint256) {
        Escrow storage escrow = escrows[escrowId];
        require(
            msg.sender == escrow.buyer || msg.sender == escrow.seller,
            "Not authorized"
        );
        require(escrow.state == EscrowState.Proposed, "Invalid state");
        
        uint256 milestoneId = escrowMilestones[escrowId].length;
        
        escrowMilestones[escrowId].push(Milestone({
            milestoneId: milestoneId,
            description: description,
            amount: amount,
            state: MilestoneState.Pending,
            dueDate: dueDate,
            completedAt: 0,
            buyerApproved: false,
            sellerConfirmed: false,
            evidenceHash: bytes32(0)
        }));
        
        escrow.hasMilestones = true;
        
        emit MilestoneAdded(escrowId, milestoneId);
        
        return milestoneId;
    }
    
    function completeMilestone(
        uint256 escrowId,
        uint256 milestoneId,
        bytes32 evidenceHash
    ) external {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.seller, "Not seller");
        require(escrow.state == EscrowState.Active, "Invalid escrow state");
        require(milestoneId < escrowMilestones[escrowId].length, "Invalid milestone");
        
        Milestone storage milestone = escrowMilestones[escrowId][milestoneId];
        require(milestone.state == MilestoneState.Pending || milestone.state == MilestoneState.InProgress, "Invalid state");
        
        milestone.state = MilestoneState.Completed;
        milestone.completedAt = block.timestamp;
        milestone.sellerConfirmed = true;
        milestone.evidenceHash = evidenceHash;
        
        emit MilestoneCompleted(escrowId, milestoneId);
    }
    
    function verifyMilestone(uint256 escrowId, uint256 milestoneId) 
        external 
    {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.buyer, "Not buyer");
        require(milestoneId < escrowMilestones[escrowId].length, "Invalid milestone");
        
        Milestone storage milestone = escrowMilestones[escrowId][milestoneId];
        require(milestone.state == MilestoneState.Completed, "Not completed");
        
        milestone.state = MilestoneState.Verified;
        milestone.buyerApproved = true;
        
        // Release milestone payment
        _releaseMilestonePayment(escrowId, milestoneId);
        
        emit MilestoneVerified(escrowId, milestoneId);
    }
    
    function _releaseMilestonePayment(uint256 escrowId, uint256 milestoneId) 
        internal 
    {
        Escrow storage escrow = escrows[escrowId];
        Milestone storage milestone = escrowMilestones[escrowId][milestoneId];
        
        uint256 milestoneAmount = milestone.amount;
        uint256 milestoneFee = (milestoneAmount * feeRate) / BASIS_POINTS;
        uint256 netAmount = milestoneAmount - milestoneFee;
        
        // Transfer to seller
        if (escrow.token == address(0)) {
            payable(escrow.seller).transfer(netAmount);
            payable(feeCollector).transfer(milestoneFee);
        } else {
            IERC1155(escrow.token).safeTransferFrom(
                address(this),
                escrow.seller,
                escrow.tokenId,
                netAmount,
                ""
            );
            IERC1155(escrow.token).safeTransferFrom(
                address(this),
                feeCollector,
                escrow.tokenId,
                milestoneFee,
                ""
            );
        }
        
        totalFeesCollected += milestoneFee;
    }
    
    function releaseEscrow(uint256 escrowId) 
        external 
        nonReentrant 
    {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.Active, "Invalid state");
        require(
            msg.sender == escrow.buyer || 
            (msg.sender == escrow.arbiter && block.timestamp >= escrow.unlockTime),
            "Not authorized"
        );
        
        // Check all milestones completed if applicable
        if (escrow.hasMilestones) {
            for (uint256 i = 0; i < escrowMilestones[escrowId].length; i++) {
                require(
                    escrowMilestones[escrowId][i].state == MilestoneState.Verified,
                    "Milestones not completed"
                );
            }
        }
        
        uint256 netAmount = escrow.amount - escrow.fee;
        
        // Transfer to seller
        if (escrow.token == address(0)) {
            payable(escrow.seller).transfer(netAmount);
            payable(feeCollector).transfer(escrow.fee);
        } else {
            IERC1155(escrow.token).safeTransferFrom(
                address(this),
                escrow.seller,
                escrow.tokenId,
                netAmount,
                ""
            );
            IERC1155(escrow.token).safeTransferFrom(
                address(this),
                feeCollector,
                escrow.tokenId,
                escrow.fee,
                ""
            );
        }
        
        escrow.state = EscrowState.Released;
        totalFeesCollected += escrow.fee;
        
        emit EscrowReleased(escrowId, netAmount);
    }
    
    function cancelEscrow(uint256 escrowId) 
        external 
        nonReentrant 
    {
        Escrow storage escrow = escrows[escrowId];
        require(
            escrow.state == EscrowState.Proposed || escrow.state == EscrowState.Active,
            "Invalid state"
        );
        require(
            msg.sender == escrow.buyer || msg.sender == escrow.seller,
            "Not authorized"
        );
        
        if (escrow.state == EscrowState.Active) {
            // Refund to buyer (minus cancellation fee)
            uint256 cancellationFee = (escrow.amount * 100) / BASIS_POINTS; // 1% cancellation fee
            uint256 refundAmount = escrow.amount + escrow.fee - cancellationFee;
            
            if (escrow.token == address(0)) {
                payable(escrow.buyer).transfer(refundAmount);
                payable(feeCollector).transfer(cancellationFee);
            } else {
                IERC1155(escrow.token).safeTransferFrom(
                    address(this),
                    escrow.buyer,
                    escrow.tokenId,
                    refundAmount,
                    ""
                );
                IERC1155(escrow.token).safeTransferFrom(
                    address(this),
                    feeCollector,
                    escrow.tokenId,
                    cancellationFee,
                    ""
                );
            }
            
            totalFeesCollected += cancellationFee;
        }
        
        escrow.state = EscrowState.Cancelled;
        
        emit EscrowCancelled(escrowId);
    }
    
    function createDispute(uint256 escrowId, string memory reason) 
        external 
        returns (uint256) 
    {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.state == EscrowState.Active, "Invalid state");
        require(
            msg.sender == escrow.buyer || msg.sender == escrow.seller,
            "Not authorized"
        );
        require(escrowToDispute[escrowId] == 0, "Dispute already exists");
        
        uint256 disputeId = ++disputeCounter;
        
        disputes[disputeId] = Dispute({
            disputeId: disputeId,
            escrowId: escrowId,
            initiator: msg.sender,
            reason: reason,
            createdAt: block.timestamp,
            resolvedAt: 0,
            resolver: address(0),
            resolution: "",
            resolved: false
        });
        
        escrowToDispute[escrowId] = disputeId;
        escrow.state = EscrowState.Disputed;
        
        emit DisputeCreated(disputeId, escrowId);
        
        return disputeId;
    }
    
    function resolveDispute(
        uint256 disputeId,
        bool favorBuyer,
        uint256 buyerAmount,
        uint256 sellerAmount,
        string memory resolution
    ) external onlyRole(ARBITER_ROLE) nonReentrant {
        Dispute storage dispute = disputes[disputeId];
        require(!dispute.resolved, "Already resolved");
        
        Escrow storage escrow = escrows[dispute.escrowId];
        require(escrow.state == EscrowState.Disputed, "Not disputed");
        
        require(
            buyerAmount + sellerAmount <= escrow.amount + escrow.fee,
            "Amounts exceed total"
        );
        
        // Transfer amounts
        if (escrow.token == address(0)) {
            if (buyerAmount > 0) {
                payable(escrow.buyer).transfer(buyerAmount);
            }
            if (sellerAmount > 0) {
                payable(escrow.seller).transfer(sellerAmount);
            }
            // Remainder goes to fee collector
            uint256 remainder = escrow.amount + escrow.fee - buyerAmount - sellerAmount;
            if (remainder > 0) {
                payable(feeCollector).transfer(remainder);
                totalFeesCollected += remainder;
            }
        } else {
            if (buyerAmount > 0) {
                IERC1155(escrow.token).safeTransferFrom(
                    address(this),
                    escrow.buyer,
                    escrow.tokenId,
                    buyerAmount,
                    ""
                );
            }
            if (sellerAmount > 0) {
                IERC1155(escrow.token).safeTransferFrom(
                    address(this),
                    escrow.seller,
                    escrow.tokenId,
                    sellerAmount,
                    ""
                );
            }
            uint256 remainder = escrow.amount + escrow.fee - buyerAmount - sellerAmount;
            if (remainder > 0) {
                IERC1155(escrow.token).safeTransferFrom(
                    address(this),
                    feeCollector,
                    escrow.tokenId,
                    remainder,
                    ""
                );
                totalFeesCollected += remainder;
            }
        }
        
        dispute.resolved = true;
        dispute.resolvedAt = block.timestamp;
        dispute.resolver = msg.sender;
        dispute.resolution = resolution;
        
        escrow.state = EscrowState.Resolved;
        
        emit DisputeResolved(disputeId, resolution);
    }
    
    function setFeeRate(uint256 _feeRate) external onlyRole(ADMIN_ROLE) {
        require(_feeRate <= 1000, "Fee too high"); // Max 10%
        feeRate = _feeRate;
    }
    
    function setFeeCollector(address _feeCollector) external onlyRole(ADMIN_ROLE) {
        require(_feeCollector != address(0), "Invalid address");
        feeCollector = _feeCollector;
    }
    
    function setDefaultTimelockDuration(uint256 duration) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        defaultTimelockDuration = duration;
    }
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    function getEscrow(uint256 escrowId) 
        external 
        view 
        returns (Escrow memory) 
    {
        return escrows[escrowId];
    }
    
    function getMilestones(uint256 escrowId) 
        external 
        view 
        returns (Milestone[] memory) 
    {
        return escrowMilestones[escrowId];
    }
    
    function getDispute(uint256 disputeId) 
        external 
        view 
        returns (Dispute memory) 
    {
        return disputes[disputeId];
    }
    
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    receive() external payable {}
    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

interface IERC1155 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}