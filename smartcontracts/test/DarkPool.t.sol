// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../src/DarkPool.sol";

/// @notice Minimal ERC1155 mock used as whitelisted trading tokens
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }
}

/// @notice Mock ZK Verifier that allows controlling proof validity in tests
contract MockZKVerifier {
    bool public shouldVerify;

    constructor(bool _shouldVerify) {
        shouldVerify = _shouldVerify;
    }

    function setShouldVerify(bool v) external {
        shouldVerify = v;
    }

    function verifyProof(
        uint256[2] memory,
        uint256[2][2] memory,
        uint256[2] memory,
        uint256[] memory
    ) external view returns (bool) {
        return shouldVerify;
    }

    function isNullifierUsed(bytes32) external pure returns (bool) {
        return false;
    }

    function isCommitmentVerified(bytes32) external pure returns (bool) {
        return true;
    }
}

contract DarkPoolTest is Test {
    DarkPool public pool;
    MockERC1155 public token;
    MockZKVerifier public zkVerifier;

    address public admin    = address(1);
    address public operator = address(2);
    address public trader   = address(3);
    address public trader2  = address(4);
    address public feeCollector = address(5);
    address public unauthorized = address(6);

    uint256 public constant TOKEN_ID     = 1;
    uint256 public constant MIN_ORDER    = 100;
    uint256 public constant MAX_ORDER    = 1_000_000 * 1e18;
    uint256 public constant TRADING_FEE  = 50;   // 50 bps = 0.5%

    bytes32 public constant VERIFIED_TRADER_ROLE = keccak256("VERIFIED_TRADER_ROLE");
    bytes32 public constant ADMIN_ROLE   = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ─── Setup ────────────────────────────────────────────────────────────────

    function setUp() public {
        DarkPool impl = new DarkPool();
        bytes memory init = abi.encodeCall(
            DarkPool.initialize,
            (admin, MIN_ORDER, MAX_ORDER, TRADING_FEE, feeCollector)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        pool = DarkPool(payable(address(proxy)));

        token = new MockERC1155();
        zkVerifier = new MockZKVerifier(true);

        // Grant trader the VERIFIED_TRADER_ROLE and operator the OPERATOR_ROLE
        vm.startPrank(admin);
        pool.grantRole(VERIFIED_TRADER_ROLE, trader);
        pool.grantRole(VERIFIED_TRADER_ROLE, trader2);
        pool.grantRole(OPERATOR_ROLE, operator);
        // Whitelist the token
        pool.whitelistToken(address(token), true);
        // Set ZK verifier
        pool.setZKVerifier(address(zkVerifier));
        vm.stopPrank();

        // Mint tokens to traders
        token.mint(trader,  TOKEN_ID, 10_000 * 1e18);
        token.mint(trader2, TOKEN_ID, 10_000 * 1e18);

        // Approve pool to spend tokens
        vm.prank(trader);
        token.setApprovalForAll(address(pool), true);
        vm.prank(trader2);
        token.setApprovalForAll(address(pool), true);
    }

    // ─── Initialization ───────────────────────────────────────────────────────

    function test_Initialize_AdminRoles() public view {
        assertTrue(pool.hasRole(ADMIN_ROLE, admin));
        assertTrue(pool.hasRole(OPERATOR_ROLE, admin));
        assertTrue(pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_Initialize_Parameters() public view {
        assertEq(pool.minOrderSize(), MIN_ORDER);
        assertEq(pool.maxOrderSize(), MAX_ORDER);
        assertEq(pool.tradingFee(), TRADING_FEE);
        assertEq(pool.feeCollector(), feeCollector);
    }

    function test_Initialize_CountersAtZero() public view {
        assertEq(pool.orderCounter(), 0);
        assertEq(pool.matchCounter(), 0);
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        pool.initialize(admin, MIN_ORDER, MAX_ORDER, TRADING_FEE, feeCollector);
    }

    // ─── Whitelist Token ──────────────────────────────────────────────────────

    function test_WhitelistToken_ByAdmin() public view {
        assertTrue(pool.whitelistedTokens(address(token)));
    }

    function test_WhitelistToken_EmitsEvent() public {
        MockERC1155 newToken = new MockERC1155();

        vm.expectEmit(true, false, false, false);
        emit DarkPool.TokenWhitelisted(address(newToken));

        vm.prank(admin);
        pool.whitelistToken(address(newToken), true);
    }

    function test_WhitelistToken_Delist() public {
        vm.prank(admin);
        pool.whitelistToken(address(token), false);
        assertFalse(pool.whitelistedTokens(address(token)));
    }

    function test_WhitelistToken_RevertsNonAdmin() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        pool.whitelistToken(address(token), true);
    }

    // ─── Set ZK Verifier ──────────────────────────────────────────────────────

    function test_SetZKVerifier_ByAdmin() public view {
        assertEq(address(pool.zkVerifier()), address(zkVerifier));
    }

    function test_SetZKVerifier_EmitsEvent() public {
        MockZKVerifier newVerifier = new MockZKVerifier(true);

        vm.expectEmit(true, true, false, false);
        emit DarkPool.ZKVerifierUpdated(address(zkVerifier), address(newVerifier));

        vm.prank(admin);
        pool.setZKVerifier(address(newVerifier));
    }

    function test_SetZKVerifier_RevertsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid verifier address");
        pool.setZKVerifier(address(0));
    }

    function test_SetZKVerifier_RevertsNonAdmin() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        pool.setZKVerifier(address(zkVerifier));
    }

    // ─── Commit Order ─────────────────────────────────────────────────────────

    function test_CommitOrder_StoresCommitment() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.prank(trader);
        pool.commitOrder(commitment);

        assertTrue(pool.isCommitmentPending(commitment));
    }

    function test_CommitOrder_SetsOwner() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.prank(trader);
        pool.commitOrder(commitment);

        (bool exists, , address owner, , ) = pool.getCommitmentDetails(commitment);
        assertTrue(exists);
        assertEq(owner, trader);
    }

    function test_CommitOrder_WithEscrow() public {
        bytes32 commitment = keccak256("buy-commitment");

        vm.deal(trader, 1 ether);
        vm.prank(trader);
        pool.commitOrder{value: 1 ether}(commitment);

        (, , , uint256 escrowAmt, ) = pool.getCommitmentDetails(commitment);
        assertEq(escrowAmt, 1 ether);
    }

    function test_CommitOrder_EmitsEvent() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.expectEmit(true, true, false, true);
        emit DarkPool.OrderCommitted(commitment, trader, 0);

        vm.prank(trader);
        pool.commitOrder(commitment);
    }

    function test_CommitOrder_RevertsZeroCommitment() public {
        vm.prank(trader);
        vm.expectRevert("Invalid commitment");
        pool.commitOrder(bytes32(0));
    }

    function test_CommitOrder_RevertsDuplicateCommitment() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.prank(trader);
        pool.commitOrder(commitment);

        vm.prank(trader);
        vm.expectRevert("Commitment already exists");
        pool.commitOrder(commitment);
    }

    function test_CommitOrder_RevertsNonVerifiedTrader() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.prank(unauthorized);
        vm.expectRevert();
        pool.commitOrder(commitment);
    }

    function test_CommitOrder_RevertsWhenPaused() public {
        vm.prank(admin);
        pool.pause();

        bytes32 commitment = keccak256("test-commitment");

        vm.prank(trader);
        vm.expectRevert();
        pool.commitOrder(commitment);
    }

    // ─── Cancel Commitment ────────────────────────────────────────────────────

    function test_CancelCommitment_RemovesCommitment() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.prank(trader);
        pool.commitOrder(commitment);

        vm.prank(trader);
        pool.cancelCommitment(commitment);

        assertFalse(pool.isCommitmentPending(commitment));
    }

    function test_CancelCommitment_RefundsEscrow() public {
        bytes32 commitment = keccak256("buy-commitment");

        vm.deal(trader, 2 ether);
        vm.prank(trader);
        pool.commitOrder{value: 1 ether}(commitment);

        uint256 balBefore = trader.balance;

        vm.prank(trader);
        pool.cancelCommitment(commitment);

        assertEq(trader.balance, balBefore + 1 ether);
    }

    function test_CancelCommitment_EmitsEvent() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.prank(trader);
        pool.commitOrder(commitment);

        vm.expectEmit(true, true, false, true);
        emit DarkPool.CommitmentCancelled(commitment, trader, 0);

        vm.prank(trader);
        pool.cancelCommitment(commitment);
    }

    function test_CancelCommitment_RevertsNotOwner() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.prank(trader);
        pool.commitOrder(commitment);

        vm.prank(trader2);
        vm.expectRevert("Not commitment owner");
        pool.cancelCommitment(commitment);
    }

    function test_CancelCommitment_RevertsNonExistent() public {
        vm.prank(trader);
        vm.expectRevert("Commitment does not exist");
        pool.cancelCommitment(keccak256("ghost"));
    }

    // ─── Get Commitment Details ────────────────────────────────────────────────

    function test_GetCommitmentDetails_CanRevealAfterDelay() public {
        bytes32 commitment = keccak256("test-commitment");

        vm.prank(trader);
        pool.commitOrder(commitment);

        (, , , , bool canRevealBefore) = pool.getCommitmentDetails(commitment);
        assertFalse(canRevealBefore, "Should not be revealable immediately");

        vm.warp(block.timestamp + pool.REVEAL_DELAY() + 1);

        (, , , , bool canRevealAfter) = pool.getCommitmentDetails(commitment);
        assertTrue(canRevealAfter, "Should be revealable after delay");
    }

    // ─── Place Order (public, direct) ─────────────────────────────────────────

    function _placePublicSellOrder(
        address _trader,
        uint256 amount,
        uint256 price
    ) internal returns (bytes32 orderHash) {
        uint256 expiry = block.timestamp + 1 days;

        vm.prank(_trader);
        orderHash = pool.placeOrder(
            address(token),
            TOKEN_ID,
            DarkPool.OrderType.Limit,
            DarkPool.OrderSide.Sell,
            amount,
            price,
            0,       // minFillAmount
            expiry,
            true     // isPublic
        );
    }

    function _placePublicBuyOrder(
        address _trader,
        uint256 amount,
        uint256 price
    ) internal returns (bytes32 orderHash) {
        uint256 expiry = block.timestamp + 1 days;
        uint256 escrow = amount * price;

        vm.deal(_trader, escrow);
        vm.prank(_trader);
        orderHash = pool.placeOrder{value: escrow}(
            address(token),
            TOKEN_ID,
            DarkPool.OrderType.Limit,
            DarkPool.OrderSide.Buy,
            amount,
            price,
            0,
            expiry,
            true
        );
    }

    function test_PlaceOrder_SellOrder_EscrowsTokens() public {
        uint256 amount = 1_000;
        uint256 balBefore = token.balanceOf(trader, TOKEN_ID);

        _placePublicSellOrder(trader, amount, 1 ether);

        assertEq(token.balanceOf(address(pool), TOKEN_ID), amount);
        assertEq(token.balanceOf(trader, TOKEN_ID), balBefore - amount);
    }

    function test_PlaceOrder_EmitsOrderPlacedEvent() public {
        uint256 amount = 1_000;

        vm.expectEmit(false, true, false, false);
        emit DarkPool.OrderPlaced(bytes32(0), trader, DarkPool.OrderType.Limit, amount);

        _placePublicSellOrder(trader, amount, 1 ether);
    }

    function test_PlaceOrder_StoresInUserOrders() public {
        bytes32 hash = _placePublicSellOrder(trader, 1_000, 1 ether);

        bytes32[] memory userOrderHashes = pool.getUserOrders(trader);
        assertEq(userOrderHashes.length, 1);
        assertEq(userOrderHashes[0], hash);
    }

    function test_PlaceOrder_IncrementOrderCounter() public {
        assertEq(pool.orderCounter(), 0);
        _placePublicSellOrder(trader, 1_000, 1 ether);
        assertEq(pool.orderCounter(), 1);
    }

    function test_PlaceOrder_RevertsNonWhitelistedToken() public {
        MockERC1155 foreignToken = new MockERC1155();
        foreignToken.mint(trader, TOKEN_ID, 1_000);

        vm.prank(trader);
        foreignToken.setApprovalForAll(address(pool), true);

        vm.prank(trader);
        vm.expectRevert("Token not whitelisted");
        pool.placeOrder(
            address(foreignToken),
            TOKEN_ID,
            DarkPool.OrderType.Limit,
            DarkPool.OrderSide.Sell,
            1_000,
            1 ether,
            0,
            block.timestamp + 1 days,
            true
        );
    }

    function test_PlaceOrder_RevertsExpiredTimestamp() public {
        vm.prank(trader);
        vm.expectRevert("Invalid expiry");
        pool.placeOrder(
            address(token),
            TOKEN_ID,
            DarkPool.OrderType.Limit,
            DarkPool.OrderSide.Sell,
            1_000,
            1 ether,
            0,
            block.timestamp - 1,  // in the past
            true
        );
    }

    function test_PlaceOrder_RevertsAmountTooSmall() public {
        vm.prank(trader);
        vm.expectRevert("Invalid amount");
        pool.placeOrder(
            address(token),
            TOKEN_ID,
            DarkPool.OrderType.Limit,
            DarkPool.OrderSide.Sell,
            MIN_ORDER - 1,  // below minimum
            1 ether,
            0,
            block.timestamp + 1 days,
            true
        );
    }

    function test_PlaceOrder_RevertsNonVerifiedTrader() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        pool.placeOrder(
            address(token),
            TOKEN_ID,
            DarkPool.OrderType.Limit,
            DarkPool.OrderSide.Sell,
            1_000,
            1 ether,
            0,
            block.timestamp + 1 days,
            true
        );
    }

    // ─── Cancel Order ─────────────────────────────────────────────────────────

    function test_CancelOrder_SellOrder_ReturnsTokens() public {
        uint256 amount = 1_000;
        bytes32 orderHash = _placePublicSellOrder(trader, amount, 1 ether);

        uint256 balBefore = token.balanceOf(trader, TOKEN_ID);

        vm.prank(trader);
        pool.cancelOrder(orderHash);

        DarkPool.DarkOrder memory o = pool.getOrder(orderHash);
        assertEq(uint8(o.status), uint8(DarkPool.OrderStatus.Cancelled));
        assertEq(token.balanceOf(trader, TOKEN_ID), balBefore + amount);
    }

    function test_CancelOrder_EmitsEvent() public {
        bytes32 orderHash = _placePublicSellOrder(trader, 1_000, 1 ether);

        vm.expectEmit(true, false, false, false);
        emit DarkPool.OrderCancelled(orderHash);

        vm.prank(trader);
        pool.cancelOrder(orderHash);
    }

    function test_CancelOrder_RevertsNotOwner() public {
        bytes32 orderHash = _placePublicSellOrder(trader, 1_000, 1 ether);

        vm.prank(trader2);
        vm.expectRevert("Not order owner");
        pool.cancelOrder(orderHash);
    }

    // ─── Match Orders ─────────────────────────────────────────────────────────

    function test_MatchOrders_ByOperator() public {
        uint256 amount = 1_000;
        uint256 price  = 1 ether;

        bytes32 buyHash  = _placePublicBuyOrder(trader2, amount, price);
        bytes32 sellHash = _placePublicSellOrder(trader, amount, price);

        vm.prank(operator);
        vm.expectEmit(false, false, false, false);
        emit DarkPool.OrderMatched(0, buyHash, sellHash, amount, price);

        pool.matchOrders(buyHash, sellHash, amount);

        assertEq(pool.matchCounter(), 1);
    }

    function test_MatchOrders_UpdatesFilledAmounts() public {
        uint256 amount = 1_000;
        uint256 price  = 1 ether;

        bytes32 buyHash  = _placePublicBuyOrder(trader2, amount, price);
        bytes32 sellHash = _placePublicSellOrder(trader, amount, price);

        vm.prank(operator);
        pool.matchOrders(buyHash, sellHash, amount);

        DarkPool.DarkOrder memory buy  = pool.getOrder(buyHash);
        DarkPool.DarkOrder memory sell = pool.getOrder(sellHash);

        assertEq(buy.filledAmount, amount);
        assertEq(sell.filledAmount, amount);
        assertEq(uint8(buy.status),  uint8(DarkPool.OrderStatus.Filled));
        assertEq(uint8(sell.status), uint8(DarkPool.OrderStatus.Filled));
    }

    function test_MatchOrders_UpdatesStatistics() public {
        uint256 amount = 1_000;
        uint256 price  = 1 ether;

        bytes32 buyHash  = _placePublicBuyOrder(trader2, amount, price);
        bytes32 sellHash = _placePublicSellOrder(trader, amount, price);

        vm.prank(operator);
        pool.matchOrders(buyHash, sellHash, amount);

        DarkPool.TradeStatistics memory stats = pool.getStatistics(address(token), TOKEN_ID);
        assertEq(stats.totalVolume, amount);
        assertEq(stats.totalTrades, 1);
        assertEq(stats.lastPrice, price);
    }

    function test_MatchOrders_RevertsNonOperator() public {
        uint256 amount = 1_000;
        uint256 price  = 1 ether;

        bytes32 buyHash  = _placePublicBuyOrder(trader2, amount, price);
        bytes32 sellHash = _placePublicSellOrder(trader, amount, price);

        vm.prank(unauthorized);
        vm.expectRevert();
        pool.matchOrders(buyHash, sellHash, amount);
    }

    function test_MatchOrders_RevertsTokenMismatch() public {
        // Create a second whitelisted token
        MockERC1155 token2 = new MockERC1155();
        vm.prank(admin);
        pool.whitelistToken(address(token2), true);
        token2.mint(trader, TOKEN_ID, 10_000 * 1e18);
        token2.mint(trader2, TOKEN_ID, 10_000 * 1e18);
        vm.prank(trader);
        token2.setApprovalForAll(address(pool), true);
        vm.prank(trader2);
        token2.setApprovalForAll(address(pool), true);

        uint256 price = 1 ether;
        uint256 amount = 1_000;
        uint256 escrow = amount * price;
        vm.deal(trader2, escrow);

        bytes32 buyHash = _placePublicBuyOrder(trader2, amount, price);

        // Sell order for different token
        vm.prank(trader);
        bytes32 sellHash = pool.placeOrder(
            address(token2),
            TOKEN_ID,
            DarkPool.OrderType.Limit,
            DarkPool.OrderSide.Sell,
            amount,
            price,
            0,
            block.timestamp + 1 days,
            true
        );

        vm.prank(operator);
        vm.expectRevert("Token mismatch");
        pool.matchOrders(buyHash, sellHash, amount);
    }

    // ─── Admin: Trading Fee & Order Limits ────────────────────────────────────

    function test_SetTradingFee_ByAdmin() public {
        vm.prank(admin);
        pool.setTradingFee(100);
        assertEq(pool.tradingFee(), 100);
    }

    function test_SetTradingFee_RevertsTooHigh() public {
        vm.prank(admin);
        vm.expectRevert("Fee too high");
        pool.setTradingFee(501);
    }

    function test_SetTradingFee_RevertsNonAdmin() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        pool.setTradingFee(100);
    }

    function test_SetOrderLimits_ByAdmin() public {
        vm.prank(admin);
        pool.setOrderLimits(500, 2_000_000 * 1e18);
        assertEq(pool.minOrderSize(), 500);
        assertEq(pool.maxOrderSize(), 2_000_000 * 1e18);
    }

    function test_SetOrderLimits_RevertsInvalidLimits() public {
        vm.prank(admin);
        vm.expectRevert("Invalid limits");
        pool.setOrderLimits(1_000, 500); // min > max
    }

    // ─── Pause / Unpause ──────────────────────────────────────────────────────

    function test_Pause_ByAdmin() public {
        vm.prank(admin);
        pool.pause();
        assertTrue(pool.paused());
    }

    function test_Unpause_ByAdmin() public {
        vm.startPrank(admin);
        pool.pause();
        pool.unpause();
        vm.stopPrank();
        assertFalse(pool.paused());
    }

    function test_Pause_RevertsNonAdmin() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        pool.pause();
    }

    // ─── Get Active Orders Count ───────────────────────────────────────────────

    function test_GetActiveOrdersCount_CountsPendingOrders() public {
        _placePublicSellOrder(trader, 1_000, 1 ether);
        _placePublicSellOrder(trader, 2_000, 2 ether);

        assertEq(pool.getActiveOrdersCount(), 2);
    }

    function test_GetActiveOrdersCount_ExcludesCancelledOrders() public {
        bytes32 h1 = _placePublicSellOrder(trader, 1_000, 1 ether);
        _placePublicSellOrder(trader, 2_000, 2 ether);

        vm.prank(trader);
        pool.cancelOrder(h1);

        assertEq(pool.getActiveOrdersCount(), 1);
    }
}
