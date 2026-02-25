// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/SGMToken.sol";

contract SGMTokenTest is Test {
    SGMToken public token;

    address public owner   = address(1);
    address public alice   = address(2);
    address public bob     = address(3);
    address public charlie = address(4);

    uint256 constant TOTAL_SUPPLY = 250_000_000_000 * 10**18;

    // ─────────────────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────────────────

    function setUp() public {
        SGMToken impl = new SGMToken();
        bytes memory initData = abi.encodeCall(SGMToken.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        token = SGMToken(address(proxy));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Initialization
    // ─────────────────────────────────────────────────────────────────────────

    function test_initialize_ownerSet() public view {
        assertEq(token.owner(), owner);
    }

    function test_initialize_oicdPairRate() public view {
        assertEq(token.oicdPairRate(), 1e15);
    }

    function test_initialize_circulatingSupply() public view {
        // 40% public float
        assertEq(token.circulatingSupply(), TOTAL_SUPPLY * 40 / 100);
    }

    function test_initialize_totalSupplyConstant() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function test_initialize_investmentPoolsSeeded() public view {
        SGMToken.InvestmentPool memory p1 = token.getPool(1);
        assertEq(p1.name, "OZF Infrastructure Fund");
        assertTrue(p1.active);
        assertEq(p1.targetReturn, 800);

        SGMToken.InvestmentPool memory p2 = token.getPool(2);
        assertEq(p2.name, "SGM Growth Portfolio");
        assertTrue(p2.active);

        SGMToken.InvestmentPool memory p3 = token.getPool(3);
        assertEq(p3.name, "OICD Liquidity Pool");
        assertTrue(p3.active);
    }

    function test_initialize_yieldPoolSeeded() public view {
        (uint256 totalStaked, uint256 rewardRate, ) = token.yieldPool();
        assertEq(totalStaked,  0);
        assertEq(rewardRate,   250); // 2.5%
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Registration
    // ─────────────────────────────────────────────────────────────────────────

    function test_register_success() public {
        vm.prank(alice);
        token.register();

        assertTrue(token.registered(alice));
        assertEq(token.totalMembers(), 1);

        SGMToken.Member memory m = token.getMember(alice);
        assertTrue(m.isRegistered);
        assertEq(m.gScore, 1);
    }

    function test_register_emitsMemberRegistered() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, false);
        emit SGMToken.MemberRegistered(alice);
        token.register();
    }

    function test_register_revertsIfAlreadyRegistered() public {
        vm.prank(alice);
        token.register();

        vm.prank(alice);
        vm.expectRevert("Already registered");
        token.register();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Minting
    // ─────────────────────────────────────────────────────────────────────────

    function test_mint_onlyOwner() public {
        uint256 amount = 1_000 ether;
        vm.prank(owner);
        token.mint(alice, amount);

        SGMToken.Member memory m = token.getMember(alice);
        assertEq(m.balance, amount);
    }

    function test_mint_emitsTokensMinted() public {
        uint256 amount = 500 ether;
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SGMToken.TokensMinted(alice, amount);
        token.mint(alice, amount);
    }

    function test_mint_revertsIfExceedsSupply() public {
        // circulatingSupply already set to 40% at initialization
        // Try to mint more than remaining (60%)
        uint256 remaining = TOTAL_SUPPLY - token.circulatingSupply();
        vm.prank(owner);
        vm.expectRevert("Exceeds supply");
        token.mint(alice, remaining + 1);
    }

    function test_mint_revertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100 ether);
    }

    function test_mint_incrementsCirculatingSupply() public {
        uint256 before = token.circulatingSupply();
        uint256 amount = 1_000 ether;
        vm.prank(owner);
        token.mint(alice, amount);
        assertEq(token.circulatingSupply(), before + amount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Staking
    // ─────────────────────────────────────────────────────────────────────────

    function _mintAndRegister(address addr, uint256 amount) internal {
        vm.prank(addr);
        token.register();
        vm.prank(owner);
        token.mint(addr, amount);
    }

    function test_stake_movesBalanceToStaked() public {
        uint256 amount = 1_000 ether;
        _mintAndRegister(alice, amount);

        vm.prank(alice);
        token.stake(amount);

        SGMToken.Member memory m = token.getMember(alice);
        assertEq(m.balance,       0);
        assertEq(m.stakedBalance, amount);
        assertEq(token.totalStaked(), amount);
    }

    function test_stake_emitsTokensStaked() public {
        _mintAndRegister(alice, 200 ether);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit SGMToken.TokensStaked(alice, 200 ether);
        token.stake(200 ether);
    }

    function test_stake_revertsIfNotRegistered() public {
        vm.prank(owner);
        token.mint(alice, 100 ether); // mint without register

        vm.prank(alice);
        vm.expectRevert("Not registered");
        token.stake(100 ether);
    }

    function test_stake_revertsInsufficientBalance() public {
        _mintAndRegister(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        token.stake(200 ether);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Unstaking and Yield
    // ─────────────────────────────────────────────────────────────────────────

    function test_unstake_returnsBalanceAndAccruesYield() public {
        uint256 amount = 1_000 ether;
        _mintAndRegister(alice, amount);

        vm.prank(alice);
        token.stake(amount);

        vm.prank(alice);
        token.unstake(amount);

        SGMToken.Member memory m = token.getMember(alice);
        assertEq(m.balance,       amount);
        assertEq(m.stakedBalance, 0);
        // yield = amount * 250 / 10000
        assertEq(m.yieldAccrued,  (amount * 250) / 10000);
    }

    function test_unstake_revertsInsufficientStake() public {
        _mintAndRegister(alice, 500 ether);
        vm.prank(alice);
        token.stake(500 ether);

        vm.prank(alice);
        vm.expectRevert("Insufficient staked");
        token.unstake(600 ether);
    }

    function test_claimYield_transfersYieldToBalance() public {
        uint256 amount = 10_000 ether;
        _mintAndRegister(alice, amount);

        vm.prank(alice);
        token.stake(amount);

        vm.prank(alice);
        token.unstake(amount);

        uint256 expectedYield = (amount * 250) / 10000;

        vm.prank(alice);
        uint256 claimed = token.claimYield();

        assertEq(claimed, expectedYield);
        assertEq(token.getMember(alice).yieldAccrued, 0);
        // balance should now be original amount + yield
        assertEq(token.getMember(alice).balance, amount + expectedYield);
    }

    function test_claimYield_revertsNoYield() public {
        _mintAndRegister(alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert("No yield");
        token.claimYield();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Investment Pools
    // ─────────────────────────────────────────────────────────────────────────

    function test_depositToPool_success() public {
        uint256 deposit = 2_000 ether; // above pool 1 minDeposit of 1000 ether
        _mintAndRegister(alice, deposit);

        vm.prank(alice);
        token.depositToPool(1, deposit);

        SGMToken.Member memory m = token.getMember(alice);
        assertEq(m.balance,           0);
        assertEq(m.investmentBalance, deposit);
        assertEq(token.getPool(1).totalDeposited, deposit);
        assertEq(token.poolDeposits(alice, 1), deposit);
    }

    function test_depositToPool_emitsEvent() public {
        _mintAndRegister(alice, 5_000 ether);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit SGMToken.InvestmentDeposited(alice, 1, 5_000 ether);
        token.depositToPool(1, 5_000 ether);
    }

    function test_depositToPool_revertsInactivePool() public {
        _mintAndRegister(alice, 1_000 ether);

        // Pool 99 doesn't exist / inactive
        vm.prank(alice);
        vm.expectRevert("Pool inactive");
        token.depositToPool(99, 1_000 ether);
    }

    function test_depositToPool_revertsBelowMinimum() public {
        // Pool 1 requires 1000 ether minimum
        _mintAndRegister(alice, 500 ether);

        vm.prank(alice);
        vm.expectRevert("Below minimum");
        token.depositToPool(1, 500 ether);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Governance — Proposals and Voting (1 person = 1 vote)
    // ─────────────────────────────────────────────────────────────────────────

    function test_createProposal_success() public {
        vm.prank(alice);
        token.register();

        vm.prank(alice);
        uint256 id = token.createProposal("Upgrade Treasury", "Details", "governance", 7);

        assertEq(id, 1);
        SGMToken.Proposal memory p = token.getProposal(1);
        assertEq(p.title,        "Upgrade Treasury");
        assertEq(p.proposalType, "governance");
        assertFalse(p.executed);
    }

    function test_createProposal_revertsIfNotRegistered() public {
        vm.prank(alice);
        vm.expectRevert("Not registered");
        token.createProposal("Test", "Desc", "governance", 3);
    }

    function test_vote_forAndAgainst() public {
        vm.prank(alice);
        token.register();
        vm.prank(bob);
        token.register();

        vm.prank(alice);
        uint256 id = token.createProposal("Fund pool", "Desc", "investment", 5);

        vm.prank(alice);
        token.vote(id, true);

        vm.prank(bob);
        token.vote(id, false);

        SGMToken.Proposal memory p = token.getProposal(id);
        assertEq(p.votesFor,     1);
        assertEq(p.votesAgainst, 1);
    }

    function test_vote_incrementsGScore() public {
        vm.prank(alice);
        token.register();
        vm.prank(alice);
        uint256 id = token.createProposal("Test", "D", "governance", 3);

        vm.prank(alice);
        token.vote(id, true);

        assertEq(token.getMember(alice).gScore, 2); // started at 1, now 2
    }

    function test_vote_revertsDoubleVote() public {
        vm.prank(alice);
        token.register();
        vm.prank(alice);
        uint256 id = token.createProposal("Test", "D", "governance", 3);

        vm.prank(alice);
        token.vote(id, true);

        vm.prank(alice);
        vm.expectRevert("Already voted");
        token.vote(id, true);
    }

    function test_vote_revertsAfterDeadline() public {
        vm.prank(alice);
        token.register();
        vm.prank(alice);
        uint256 id = token.createProposal("Test", "D", "governance", 1); // 1 day

        vm.warp(block.timestamp + 2 days);

        vm.prank(alice);
        vm.expectRevert("Voting ended");
        token.vote(id, true);
    }

    function test_executeProposal_afterDeadline() public {
        vm.prank(alice);
        token.register();
        vm.prank(bob);
        token.register();

        vm.prank(alice);
        uint256 id = token.createProposal("Test", "D", "governance", 3);

        vm.prank(alice);
        token.vote(id, true);
        vm.prank(bob);
        token.vote(id, false);

        vm.warp(block.timestamp + 4 days);

        token.executeProposal(id);

        SGMToken.Proposal memory p = token.getProposal(id);
        assertTrue(p.executed);
        assertFalse(p.passed); // 1 for, 1 against → tie → false (not strictly greater)
    }

    function test_executeProposal_revertsIfStillActive() public {
        vm.prank(alice);
        token.register();
        vm.prank(alice);
        uint256 id = token.createProposal("Test", "D", "governance", 5);

        vm.expectRevert("Still active");
        token.executeProposal(id);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Liquidity and Pair Rate
    // ─────────────────────────────────────────────────────────────────────────

    function test_addLiquidity_updatesReserves() public {
        vm.prank(owner);
        token.addLiquidity(1_000 ether, 500 ether);

        assertEq(token.liquidityReserveSGM(),  1_000 ether);
        assertEq(token.liquidityReserveOICD(), 500 ether);
    }

    function test_addLiquidity_revertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.addLiquidity(100 ether, 100 ether);
    }

    function test_updateOICDPairRate() public {
        uint256 newRate = 2e15;
        vm.prank(owner);
        token.updateOICDPairRate(newRate);
        assertEq(token.oicdPairRate(), newRate);
    }

    function test_updateOICDPairRate_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit SGMToken.PairRateUpdated(5e15);
        token.updateOICDPairRate(5e15);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Global Stats View
    // ─────────────────────────────────────────────────────────────────────────

    function test_globalStats_returnsCorrectValues() public {
        (
            uint256 supply,
            uint256 circulating,
            uint256 staked,
            uint256 members,
            uint256 pools,
            uint256 rate
        ) = token.globalStats();

        assertEq(supply,      TOTAL_SUPPLY);
        assertEq(circulating, TOTAL_SUPPLY * 40 / 100);
        assertEq(staked,      0);
        assertEq(members,     0);
        assertEq(pools,       3);
        assertEq(rate,        1e15);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. UUPS Upgrade Authorization
    // ─────────────────────────────────────────────────────────────────────────

    function test_upgradeReverts_nonOwner() public {
        SGMToken impl2 = new SGMToken();
        vm.prank(alice);
        vm.expectRevert();
        token.upgradeToAndCall(address(impl2), "");
    }
}
