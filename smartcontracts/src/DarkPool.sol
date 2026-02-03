// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title IZKVerifier
 * @notice Interface for Zero-Knowledge proof verification
 */
interface IZKVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory publicInputs
    ) external returns (bool);

    function isNullifierUsed(bytes32 nullifier) external view returns (bool);
    function isCommitmentVerified(bytes32 commitment) external view returns (bool);
}

/**
 * @title DarkPool - Anonymous Trading Venue with ZK Privacy
 * @notice Private, stealth trading for institutional and retail investors
 * @dev Implements dark pool mechanics with ZK-SNARK privacy-preserving features
 */
contract DarkPool is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant VERIFIED_TRADER_ROLE = keccak256("VERIFIED_TRADER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ZK Privacy - Commit-Reveal Pattern
    IZKVerifier public zkVerifier;

    // Commitment storage for hidden orders
    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => uint256) public commitmentTimestamps;
    mapping(bytes32 => address) public commitmentOwners;
    mapping(bytes32 => uint256) public commitmentEscrow; // Escrowed ETH for buy orders

    // MEV protection: minimum delay before reveal
    uint256 public constant REVEAL_DELAY = 30 minutes;

    // Commitment expiry (prevent stale commitments)
    uint256 public constant COMMITMENT_EXPIRY = 24 hours;

    enum OrderType {
        Market,
        Limit,
        Iceberg,
        VWAP,
        TWAP
    }

    enum OrderSide {
        Buy,
        Sell
    }

    enum OrderStatus {
        Pending,
        PartiallyFilled,
        Filled,
        Cancelled,
        Expired
    }

    struct DarkOrder {
        uint256 orderId;
        bytes32 orderHash;
        address trader;
        address tokenAddress;
        uint256 tokenId;
        OrderType orderType;
        OrderSide side;
        uint256 amount;
        uint256 filledAmount;
        uint256 price;
        uint256 minFillAmount;
        uint256 timestamp;
        uint256 expiry;
        OrderStatus status;
        bool isPublic; // If false, completely hidden
        uint256 escrowedPayment; // SECURITY: Escrowed payment for buy orders
    }

    struct IcebergOrder {
        uint256 orderId;
        uint256 totalAmount;
        uint256 visibleAmount;
        uint256 executedAmount;
    }

    struct Match {
        uint256 matchId;
        bytes32 buyOrderHash;
        bytes32 sellOrderHash;
        uint256 amount;
        uint256 price;
        uint256 timestamp;
        bool settled;
    }

    struct TradeStatistics {
        uint256 totalVolume;
        uint256 totalTrades;
        uint256 lastPrice;
        uint256 highPrice;
        uint256 lowPrice;
        uint256 lastUpdate;
    }

    mapping(bytes32 => DarkOrder) public orders;
    mapping(uint256 => IcebergOrder) public icebergOrders;
    mapping(uint256 => Match) public matches;
    mapping(address => mapping(uint256 => TradeStatistics)) public statistics;
    mapping(address => bytes32[]) public userOrders;
    mapping(address => bool) public whitelistedTokens;

    bytes32[] public activeOrders;
    uint256 public matchCounter;
    uint256 public orderCounter;

    uint256 public minOrderSize;
    uint256 public maxOrderSize;
    uint256 public tradingFee; // Basis points
    address public feeCollector;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SETTLEMENT_PERIOD = 1 hours;

    event OrderPlaced(
        bytes32 indexed orderHash,
        address indexed trader,
        OrderType orderType,
        uint256 amount
    );
    event OrderMatched(
        uint256 indexed matchId,
        bytes32 buyOrderHash,
        bytes32 sellOrderHash,
        uint256 amount,
        uint256 price
    );
    event OrderCancelled(bytes32 indexed orderHash);
    event TradeSettled(uint256 indexed matchId);
    event TokenWhitelisted(address indexed token);

    // ZK Privacy Events
    event OrderCommitted(bytes32 indexed commitment, address indexed trader, uint256 escrowAmount);
    event OrderRevealed(bytes32 indexed commitment, bytes32 indexed orderHash, address indexed trader);
    event CommitmentCancelled(bytes32 indexed commitment, address indexed trader, uint256 refundAmount);
    event ZKVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        uint256 _minOrderSize,
        uint256 _maxOrderSize,
        uint256 _tradingFee,
        address _feeCollector
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        minOrderSize = _minOrderSize;
        maxOrderSize = _maxOrderSize;
        tradingFee = _tradingFee;
        feeCollector = _feeCollector;
    }

    // ============ ZK VERIFIER MANAGEMENT ============

    /**
     * @notice Set the ZK Verifier contract address
     * @param _zkVerifier Address of the ZKVerifier contract
     */
    function setZKVerifier(address _zkVerifier) external onlyRole(ADMIN_ROLE) {
        require(_zkVerifier != address(0), "Invalid verifier address");
        address oldVerifier = address(zkVerifier);
        zkVerifier = IZKVerifier(_zkVerifier);
        emit ZKVerifierUpdated(oldVerifier, _zkVerifier);
    }

    // ============ COMMIT-REVEAL PATTERN FOR PRIVATE ORDERS ============

    /**
     * @notice Commit to a hidden order (Phase 1 of commit-reveal)
     * @param commitment The Poseidon hash commitment of order details
     * @dev For buy orders, ETH must be escrowed with the commitment
     */
    function commitOrder(bytes32 commitment) external payable onlyRole(VERIFIED_TRADER_ROLE) whenNotPaused {
        require(commitment != bytes32(0), "Invalid commitment");
        require(!commitments[commitment], "Commitment already exists");

        commitments[commitment] = true;
        commitmentTimestamps[commitment] = block.timestamp;
        commitmentOwners[commitment] = msg.sender;

        // Store escrowed ETH for buy orders
        if (msg.value > 0) {
            commitmentEscrow[commitment] = msg.value;
        }

        emit OrderCommitted(commitment, msg.sender, msg.value);
    }

    /**
     * @notice Reveal a committed order with ZK proof (Phase 2 of commit-reveal)
     * @param a Groth16 proof element A
     * @param b Groth16 proof element B
     * @param c Groth16 proof element C
     * @param publicInputs Public inputs [commitment, nullifier]
     * @param tokenAddress Token contract address
     * @param tokenId Token ID
     * @param orderType Type of order
     * @param side Buy or Sell
     * @param amount Order amount
     * @param price Order price
     * @param minFillAmount Minimum fill requirement
     * @param expiry Order expiration timestamp
     */
    function revealOrder(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory publicInputs,
        address tokenAddress,
        uint256 tokenId,
        OrderType orderType,
        OrderSide side,
        uint256 amount,
        uint256 price,
        uint256 minFillAmount,
        uint256 expiry
    ) external onlyRole(VERIFIED_TRADER_ROLE) whenNotPaused nonReentrant returns (bytes32) {
        require(address(zkVerifier) != address(0), "ZK verifier not set");
        require(publicInputs.length == 2, "Invalid public inputs");

        bytes32 commitment = bytes32(publicInputs[0]);

        // Verify commitment exists and belongs to caller
        require(commitments[commitment], "Commitment does not exist");
        require(commitmentOwners[commitment] == msg.sender, "Not commitment owner");

        // Enforce reveal delay (MEV protection)
        require(
            block.timestamp >= commitmentTimestamps[commitment] + REVEAL_DELAY,
            "Reveal too early"
        );

        // Check commitment hasn't expired
        require(
            block.timestamp <= commitmentTimestamps[commitment] + COMMITMENT_EXPIRY,
            "Commitment expired"
        );

        // Verify ZK proof
        require(zkVerifier.verifyProof(a, b, c, publicInputs), "Invalid ZK proof");

        // Mark commitment as used
        delete commitments[commitment];

        // Get escrowed amount for buy orders
        uint256 escrowedAmount = commitmentEscrow[commitment];
        delete commitmentEscrow[commitment];
        delete commitmentTimestamps[commitment];
        delete commitmentOwners[commitment];

        // Execute order placement (internal)
        return _placeOrderInternal(
            tokenAddress,
            tokenId,
            orderType,
            side,
            amount,
            price,
            minFillAmount,
            expiry,
            false, // ZK orders are always private
            escrowedAmount,
            commitment
        );
    }

    /**
     * @notice Cancel a pending commitment and reclaim escrowed funds
     * @param commitment The commitment to cancel
     */
    function cancelCommitment(bytes32 commitment) external nonReentrant {
        require(commitments[commitment], "Commitment does not exist");
        require(commitmentOwners[commitment] == msg.sender, "Not commitment owner");

        // Mark as cancelled
        delete commitments[commitment];
        delete commitmentTimestamps[commitment];
        delete commitmentOwners[commitment];

        // Refund escrowed ETH
        uint256 escrowAmount = commitmentEscrow[commitment];
        delete commitmentEscrow[commitment];

        if (escrowAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: escrowAmount}("");
            require(success, "Refund failed");
        }

        emit CommitmentCancelled(commitment, msg.sender, escrowAmount);
    }

    /**
     * @notice Check if a commitment is valid and pending
     * @param commitment The commitment hash to check
     */
    function isCommitmentPending(bytes32 commitment) external view returns (bool) {
        return commitments[commitment];
    }

    /**
     * @notice Get commitment details
     * @param commitment The commitment hash
     */
    function getCommitmentDetails(bytes32 commitment) external view returns (
        bool exists,
        uint256 timestamp,
        address owner,
        uint256 escrowAmount,
        bool canReveal
    ) {
        exists = commitments[commitment];
        timestamp = commitmentTimestamps[commitment];
        owner = commitmentOwners[commitment];
        escrowAmount = commitmentEscrow[commitment];
        canReveal = exists && (block.timestamp >= timestamp + REVEAL_DELAY);
    }

    // ============ INTERNAL ORDER PLACEMENT ============

    /**
     * @notice Internal function to place order (used by both direct and ZK reveal)
     */
    function _placeOrderInternal(
        address tokenAddress,
        uint256 tokenId,
        OrderType orderType,
        OrderSide side,
        uint256 amount,
        uint256 price,
        uint256 minFillAmount,
        uint256 expiry,
        bool isPublic,
        uint256 escrowedPayment,
        bytes32 zkCommitment
    ) internal returns (bytes32) {
        require(whitelistedTokens[tokenAddress], "Token not whitelisted");
        require(amount >= minOrderSize && amount <= maxOrderSize, "Invalid amount");
        require(expiry > block.timestamp, "Invalid expiry");
        require(minFillAmount <= amount, "Invalid min fill");

        // For buy orders, verify sufficient escrow
        if (side == OrderSide.Buy) {
            uint256 totalPayment = amount * price;
            require(escrowedPayment >= totalPayment, "Insufficient payment for buy order");
        }

        uint256 orderId = orderCounter++;
        bytes32 orderHash = keccak256(
            abi.encodePacked(
                orderId,
                msg.sender,
                tokenAddress,
                tokenId,
                orderType,
                side,
                amount,
                price,
                block.timestamp,
                zkCommitment // Include ZK commitment in hash for traceability
            )
        );

        orders[orderHash] = DarkOrder({
            orderId: orderId,
            orderHash: orderHash,
            trader: msg.sender,
            tokenAddress: tokenAddress,
            tokenId: tokenId,
            orderType: orderType,
            side: side,
            amount: amount,
            filledAmount: 0,
            price: price,
            minFillAmount: minFillAmount,
            timestamp: block.timestamp,
            expiry: expiry,
            status: OrderStatus.Pending,
            isPublic: isPublic,
            escrowedPayment: escrowedPayment
        });

        activeOrders.push(orderHash);
        userOrders[msg.sender].push(orderHash);

        // For Iceberg orders, track hidden volume
        if (orderType == OrderType.Iceberg) {
            uint256 visibleAmount = amount / 10; // Show 10% of order
            icebergOrders[orderId] = IcebergOrder({
                orderId: orderId,
                totalAmount: amount,
                visibleAmount: visibleAmount,
                executedAmount: 0
            });
        }

        // Transfer tokens to contract for escrow (sell orders)
        if (side == OrderSide.Sell) {
            IERC1155(tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                amount,
                ""
            );
        }

        emit OrderPlaced(orderHash, msg.sender, orderType, amount);

        if (zkCommitment != bytes32(0)) {
            emit OrderRevealed(zkCommitment, orderHash, msg.sender);
        }

        return orderHash;
    }

    // ============ PUBLIC ORDER PLACEMENT (NON-ZK) ============

    /**
     * @notice Place a public order directly (non-ZK)
     * @dev For private orders, use commitOrder + revealOrder instead
     */
    function placeOrder(
        address tokenAddress,
        uint256 tokenId,
        OrderType orderType,
        OrderSide side,
        uint256 amount,
        uint256 price,
        uint256 minFillAmount,
        uint256 expiry,
        bool isPublic
    ) external payable onlyRole(VERIFIED_TRADER_ROLE) whenNotPaused nonReentrant returns (bytes32) {
        // For public/direct orders, use the internal function
        return _placeOrderInternal(
            tokenAddress,
            tokenId,
            orderType,
            side,
            amount,
            price,
            minFillAmount,
            expiry,
            isPublic,
            msg.value, // Pass ETH as escrow
            bytes32(0) // No ZK commitment for direct orders
        );
    }

    function matchOrders(
        bytes32 buyOrderHash,
        bytes32 sellOrderHash,
        uint256 matchAmount
    ) external onlyRole(OPERATOR_ROLE) nonReentrant returns (uint256) {
        DarkOrder storage buyOrder = orders[buyOrderHash];
        DarkOrder storage sellOrder = orders[sellOrderHash];

        require(buyOrder.status == OrderStatus.Pending || buyOrder.status == OrderStatus.PartiallyFilled, "Invalid buy order");
        require(sellOrder.status == OrderStatus.Pending || sellOrder.status == OrderStatus.PartiallyFilled, "Invalid sell order");
        require(buyOrder.side == OrderSide.Buy, "Not a buy order");
        require(sellOrder.side == OrderSide.Sell, "Not a sell order");
        require(buyOrder.tokenAddress == sellOrder.tokenAddress, "Token mismatch");
        require(buyOrder.tokenId == sellOrder.tokenId, "Token ID mismatch");

        uint256 buyRemaining = buyOrder.amount - buyOrder.filledAmount;
        uint256 sellRemaining = sellOrder.amount - sellOrder.filledAmount;

        require(matchAmount <= buyRemaining && matchAmount <= sellRemaining, "Invalid match amount");

        // Price matching logic
        uint256 executionPrice;
        if (buyOrder.orderType == OrderType.Market) {
            executionPrice = sellOrder.price;
        } else if (sellOrder.orderType == OrderType.Market) {
            executionPrice = buyOrder.price;
        } else {
            require(buyOrder.price >= sellOrder.price, "Price mismatch");
            executionPrice = (buyOrder.price + sellOrder.price) / 2; // Mid-point
        }

        uint256 matchId = matchCounter++;

        matches[matchId] = Match({
            matchId: matchId,
            buyOrderHash: buyOrderHash,
            sellOrderHash: sellOrderHash,
            amount: matchAmount,
            price: executionPrice,
            timestamp: block.timestamp,
            settled: false
        });

        // Update order filled amounts
        buyOrder.filledAmount += matchAmount;
        sellOrder.filledAmount += matchAmount;

        // Update order status
        if (buyOrder.filledAmount == buyOrder.amount) {
            buyOrder.status = OrderStatus.Filled;
        } else {
            buyOrder.status = OrderStatus.PartiallyFilled;
        }

        if (sellOrder.filledAmount == sellOrder.amount) {
            sellOrder.status = OrderStatus.Filled;
        } else {
            sellOrder.status = OrderStatus.PartiallyFilled;
        }

        // Update Iceberg orders
        if (buyOrder.orderType == OrderType.Iceberg) {
            IcebergOrder storage iceberg = icebergOrders[buyOrder.orderId];
            iceberg.executedAmount += matchAmount;
        }

        if (sellOrder.orderType == OrderType.Iceberg) {
            IcebergOrder storage iceberg = icebergOrders[sellOrder.orderId];
            iceberg.executedAmount += matchAmount;
        }

        // Update statistics
        _updateStatistics(buyOrder.tokenAddress, buyOrder.tokenId, matchAmount, executionPrice);

        emit OrderMatched(matchId, buyOrderHash, sellOrderHash, matchAmount, executionPrice);

        // Auto-settle
        _settleMatch(matchId);

        return matchId;
    }

    function _settleMatch(uint256 matchId) internal {
        Match storage matchData = matches[matchId];
        require(!matchData.settled, "Already settled");

        DarkOrder storage buyOrder = orders[matchData.buyOrderHash];
        DarkOrder storage sellOrder = orders[matchData.sellOrderHash];

        uint256 totalCost = matchData.amount * matchData.price;
        uint256 fee = (totalCost * tradingFee) / BASIS_POINTS;
        uint256 sellerProceeds = totalCost - fee;

        // Transfer tokens from escrow to buyer
        IERC1155(sellOrder.tokenAddress).safeTransferFrom(
            address(this),
            buyOrder.trader,
            sellOrder.tokenId,
            matchData.amount,
            ""
        );

        (bool successSeller, ) = payable(sellOrder.trader).call{value: sellerProceeds}("");
        require(successSeller, "Seller transfer failed");

        if (fee > 0) {
            (bool successFee, ) = payable(feeCollector).call{value: fee}("");
            require(successFee, "Fee transfer failed");
        }

        matchData.settled = true;

        emit TradeSettled(matchId);
    }

    function cancelOrder(bytes32 orderHash) external nonReentrant {
        DarkOrder storage order = orders[orderHash];
        require(order.trader == msg.sender, "Not order owner");
        require(order.status == OrderStatus.Pending || order.status == OrderStatus.PartiallyFilled, "Cannot cancel");

        uint256 remainingAmount = order.amount - order.filledAmount;

        // Return escrowed tokens if sell order
        if (order.side == OrderSide.Sell && remainingAmount > 0) {
            IERC1155(order.tokenAddress).safeTransferFrom(
                address(this),
                msg.sender,
                order.tokenId,
                remainingAmount,
                ""
            );
        }

        if (order.side == OrderSide.Buy && order.escrowedPayment > 0) {
            uint256 refundAmount = (order.escrowedPayment * remainingAmount) / order.amount;
            if (refundAmount > 0) {
                (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
                require(success, "Refund transfer failed");
            }
        }

        order.status = OrderStatus.Cancelled;

        emit OrderCancelled(orderHash);
    }

    function _updateStatistics(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 price
    ) internal {
        TradeStatistics storage stats = statistics[tokenAddress][tokenId];

        stats.totalVolume += amount;
        stats.totalTrades += 1;
        stats.lastPrice = price;

        if (price > stats.highPrice || stats.highPrice == 0) {
            stats.highPrice = price;
        }

        if (price < stats.lowPrice || stats.lowPrice == 0) {
            stats.lowPrice = price;
        }

        stats.lastUpdate = block.timestamp;
    }

    function whitelistToken(address token, bool status)
        external
        onlyRole(ADMIN_ROLE)
    {
        whitelistedTokens[token] = status;
        if (status) {
            emit TokenWhitelisted(token);
        }
    }

    function setTradingFee(uint256 fee) external onlyRole(ADMIN_ROLE) {
        require(fee <= 500, "Fee too high"); // Max 5%
        tradingFee = fee;
    }

    function setOrderLimits(uint256 minSize, uint256 maxSize)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(minSize < maxSize, "Invalid limits");
        minOrderSize = minSize;
        maxOrderSize = maxSize;
    }

    function getOrder(bytes32 orderHash)
        external
        view
        returns (DarkOrder memory)
    {
        return orders[orderHash];
    }

    function getUserOrders(address user)
        external
        view
        returns (bytes32[] memory)
    {
        return userOrders[user];
    }

    function getStatistics(address tokenAddress, uint256 tokenId)
        external
        view
        returns (TradeStatistics memory)
    {
        return statistics[tokenAddress][tokenId];
    }

    function getActiveOrdersCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < activeOrders.length; i++) {
            DarkOrder memory order = orders[activeOrders[i]];
            if (order.status == OrderStatus.Pending || order.status == OrderStatus.PartiallyFilled) {
                count++;
            }
        }
        return count;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

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

    receive() external payable {}
}

