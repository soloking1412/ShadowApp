// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/OZFParliament.sol";

contract OZFParliamentTest is Test {
    OZFParliament instance;

    address chairman     = address(1);
    address pm           = address(2);
    address treasury     = address(3);
    address seatHolder1  = address(4);
    address seatHolder2  = address(5);
    address seatHolder3  = address(6);
    address nobody       = address(7);

    function setUp() public {
        OZFParliament impl = new OZFParliament();
        bytes memory init = abi.encodeCall(
            OZFParliament.initialize,
            (chairman, pm, treasury)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = OZFParliament(address(proxy));
    }

    // -----------------------------------------------------------------------
    // 1. Initialization
    // -----------------------------------------------------------------------
    function test_Initialization() public view {
        assertEq(instance.chairman(), chairman);
        assertEq(instance.primeMinister(), pm);
        assertEq(instance.treasuryGovernor(), treasury);

        assertTrue(instance.hasRole(instance.DEFAULT_ADMIN_ROLE(), chairman));
        assertTrue(instance.hasRole(instance.CHAIRMAN_ROLE(), chairman));
        assertTrue(instance.hasRole(instance.PRIME_MINISTER_ROLE(), pm));
        assertTrue(instance.hasRole(instance.ADMIN_ROLE(), chairman));

        assertEq(instance.activeSeats(), 0);
        assertEq(instance.electionCounter(), 0);
        assertEq(instance.proposalCounter(), 0);
    }

    function test_Constants() public view {
        assertEq(instance.TOTAL_SEATS(), 216);
        assertEq(instance.ELECTION_THRESHOLD(), 5500);
        assertEq(instance.BASIS_POINTS(), 10000);
        assertEq(instance.VOTING_PERIOD(), 7 days);
    }

    // -----------------------------------------------------------------------
    // 2. Seat Assignment
    // -----------------------------------------------------------------------
    function test_AssignSeat() public {
        vm.expectEmit(true, true, false, true);
        emit OZFParliament.SeatAssigned(
            1,
            seatHolder1,
            "Delegation Alpha",
            block.timestamp + instance.TERM_DURATION()
        );

        vm.prank(chairman);
        instance.assignSeat(1, seatHolder1, "Delegation Alpha", "TradeBlock A", "US");

        (address holder, string memory del, , , bool active) = instance.getSeat(1);
        assertEq(holder, seatHolder1);
        assertEq(del, "Delegation Alpha");
        assertTrue(active);
        assertEq(instance.activeSeats(), 1);
        assertEq(instance.seatHolderToNumber(seatHolder1), 1);
        assertTrue(instance.hasRole(instance.SEAT_HOLDER_ROLE(), seatHolder1));
    }

    function test_AssignSeat_Reverts_NonChairman() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.assignSeat(1, seatHolder1, "Del", "TB", "US");
    }

    function test_AssignSeat_Reverts_InvalidSeatNumber_Zero() public {
        vm.prank(chairman);
        vm.expectRevert("Invalid seat number");
        instance.assignSeat(0, seatHolder1, "Del", "TB", "US");
    }

    function test_AssignSeat_Reverts_InvalidSeatNumber_TooHigh() public {
        vm.prank(chairman);
        vm.expectRevert("Invalid seat number");
        instance.assignSeat(217, seatHolder1, "Del", "TB", "US");
    }

    function test_AssignSeat_Reverts_ZeroAddress() public {
        vm.prank(chairman);
        vm.expectRevert("Invalid holder");
        instance.assignSeat(1, address(0), "Del", "TB", "US");
    }

    function test_AssignSeat_Reverts_AlreadyOccupied() public {
        vm.startPrank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");
        vm.expectRevert("Seat already occupied");
        instance.assignSeat(1, seatHolder2, "Del B", "TB B", "US");
        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // 3. Elections
    // -----------------------------------------------------------------------
    function test_StartElection() public {
        vm.prank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");

        address[] memory candidates = new address[](2);
        candidates[0] = address(10);
        candidates[1] = address(11);

        vm.expectEmit(true, true, false, false);
        emit OZFParliament.ElectionStarted(1, 1, block.timestamp + 30 days);

        vm.prank(chairman);
        instance.startElection(1, candidates);

        assertEq(instance.electionCounter(), 1);
    }

    function test_StartElection_Reverts_NonChairman() public {
        address[] memory candidates = new address[](1);
        candidates[0] = address(10);

        vm.prank(nobody);
        vm.expectRevert();
        instance.startElection(1, candidates);
    }

    function test_StartElection_Reverts_NoCandidates() public {
        address[] memory candidates = new address[](0);

        vm.prank(chairman);
        vm.expectRevert("No candidates");
        instance.startElection(1, candidates);
    }

    function test_VoteInElection() public {
        // Setup: assign seat so seatHolder1 has SEAT_HOLDER_ROLE
        vm.prank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");

        address candidate = address(10);
        address[] memory candidates = new address[](1);
        candidates[0] = candidate;

        vm.prank(chairman);
        instance.startElection(1, candidates);

        vm.expectEmit(true, true, true, false);
        emit OZFParliament.VoteCast(1, seatHolder1, candidate);

        vm.prank(seatHolder1);
        instance.voteInElection(1, candidate);
    }

    function test_VoteInElection_Reverts_AlreadyVoted() public {
        vm.prank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");

        address candidate = address(10);
        address[] memory candidates = new address[](1);
        candidates[0] = candidate;

        vm.prank(chairman);
        instance.startElection(1, candidates);

        vm.startPrank(seatHolder1);
        instance.voteInElection(1, candidate);
        vm.expectRevert("Already voted");
        instance.voteInElection(1, candidate);
        vm.stopPrank();
    }

    function test_VoteInElection_Reverts_InvalidCandidate() public {
        vm.prank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");

        address candidate = address(10);
        address[] memory candidates = new address[](1);
        candidates[0] = candidate;

        vm.prank(chairman);
        instance.startElection(1, candidates);

        vm.prank(seatHolder1);
        vm.expectRevert("Invalid candidate");
        instance.voteInElection(1, address(99));
    }

    function test_VoteInElection_Reverts_NonSeatHolder() public {
        vm.prank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");

        address[] memory candidates = new address[](1);
        candidates[0] = address(10);

        vm.prank(chairman);
        instance.startElection(1, candidates);

        vm.prank(nobody);
        vm.expectRevert();
        instance.voteInElection(1, candidates[0]);
    }

    function test_ConcludeElection() public {
        // Assign 3 seats so activeSeats = 3 for threshold math
        vm.startPrank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");
        instance.assignSeat(2, seatHolder2, "Del B", "TB B", "GB");
        instance.assignSeat(3, seatHolder3, "Del C", "TB C", "DE");
        vm.stopPrank();

        address winner = address(10);
        address[] memory candidates = new address[](1);
        candidates[0] = winner;

        vm.prank(chairman);
        instance.startElection(1, candidates);

        // All 3 seat holders vote for winner
        vm.prank(seatHolder1);
        instance.voteInElection(1, winner);
        vm.prank(seatHolder2);
        instance.voteInElection(1, winner);
        vm.prank(seatHolder3);
        instance.voteInElection(1, winner);

        // Advance past 30-day election period
        vm.warp(block.timestamp + 31 days);

        // 3/3 votes = 100% > 55% threshold
        vm.prank(chairman);
        instance.concludeElection(1);

        (address holder, , , , bool active) = instance.getSeat(1);
        assertEq(holder, winner);
        assertTrue(active);
        assertTrue(instance.hasRole(instance.SEAT_HOLDER_ROLE(), winner));
    }

    function test_ConcludeElection_Reverts_ThresholdNotMet() public {
        // Assign 10 seats; winner gets 1 vote => 10% < 55%
        vm.startPrank(chairman);
        for (uint256 i = 1; i <= 10; i++) {
            instance.assignSeat(i, address(uint160(100 + i)), "Del", "TB", "US");
        }
        vm.stopPrank();

        address winner = address(10);
        address[] memory candidates = new address[](1);
        candidates[0] = winner;

        vm.prank(chairman);
        instance.startElection(1, candidates);

        // Only seat holder 1 votes
        vm.prank(address(101));
        instance.voteInElection(1, winner);

        vm.warp(block.timestamp + 31 days);

        vm.prank(chairman);
        vm.expectRevert("Threshold not met");
        instance.concludeElection(1);
    }

    // -----------------------------------------------------------------------
    // 4. Proposals
    // -----------------------------------------------------------------------
    function _assignAndGetSeatHolder() internal returns (address) {
        vm.prank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");
        return seatHolder1;
    }

    function test_CreateProposal() public {
        address sh = _assignAndGetSeatHolder();

        vm.expectEmit(true, true, false, true);
        emit OZFParliament.ProposalCreated(1, sh, OZFParliament.ProposalType.Trade, "Trade Deal");

        vm.prank(sh);
        uint256 pid = instance.createProposal(
            OZFParliament.ProposalType.Trade,
            "Trade Deal",
            "Expand trade with Region X",
            "TradeBlock A",
            1000 ether,
            ""
        );

        assertEq(pid, 1);
        assertEq(instance.proposalCounter(), 1);

        // Check seat proposalsCreated incremented
        (address holder,,,,) = instance.getSeat(1);
        assertEq(holder, sh);
    }

    function test_CreateProposal_Reverts_NonSeatHolder() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.createProposal(
            OZFParliament.ProposalType.Trade,
            "Trade Deal",
            "Desc",
            "TB",
            0,
            ""
        );
    }

    function test_CreateProposal_Reverts_WhenPaused() public {
        _assignAndGetSeatHolder();

        vm.prank(chairman);
        instance.pause();

        vm.prank(seatHolder1);
        vm.expectRevert();
        instance.createProposal(
            OZFParliament.ProposalType.Trade,
            "Trade Deal",
            "Desc",
            "TB",
            0,
            ""
        );
    }

    // -----------------------------------------------------------------------
    // 5. Proposal Voting
    // -----------------------------------------------------------------------
    function test_VoteOnProposal() public {
        _assignAndGetSeatHolder();
        vm.prank(chairman);
        instance.assignSeat(2, seatHolder2, "Del B", "TB B", "GB");

        vm.prank(seatHolder1);
        uint256 pid = instance.createProposal(
            OZFParliament.ProposalType.Legislative,
            "Law A",
            "Desc",
            "TB A",
            0,
            ""
        );

        vm.expectEmit(true, true, false, true);
        emit OZFParliament.ProposalVoted(pid, seatHolder2, true);

        vm.prank(seatHolder2);
        instance.voteOnProposal(pid, true);
    }

    function test_VoteOnProposal_Reverts_AlreadyVoted() public {
        _assignAndGetSeatHolder();
        vm.prank(chairman);
        instance.assignSeat(2, seatHolder2, "Del B", "TB B", "GB");

        vm.prank(seatHolder1);
        uint256 pid = instance.createProposal(
            OZFParliament.ProposalType.Commerce,
            "Commerce",
            "Desc",
            "TB A",
            0,
            ""
        );

        vm.startPrank(seatHolder2);
        instance.voteOnProposal(pid, true);
        vm.expectRevert("Already voted");
        instance.voteOnProposal(pid, true);
        vm.stopPrank();
    }

    function test_VoteOnProposal_Reverts_AfterDeadline() public {
        _assignAndGetSeatHolder();
        vm.prank(chairman);
        instance.assignSeat(2, seatHolder2, "Del B", "TB B", "GB");

        vm.prank(seatHolder1);
        uint256 pid = instance.createProposal(
            OZFParliament.ProposalType.Business,
            "Biz",
            "Desc",
            "TB A",
            0,
            ""
        );

        vm.warp(block.timestamp + 8 days);

        vm.prank(seatHolder2);
        vm.expectRevert("Voting ended");
        instance.voteOnProposal(pid, true);
    }

    // -----------------------------------------------------------------------
    // 6. Execute Proposal
    // -----------------------------------------------------------------------
    function test_ExecuteProposal_Passed() public {
        // Setup 3 seat holders
        vm.startPrank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");
        instance.assignSeat(2, seatHolder2, "Del B", "TB B", "GB");
        instance.assignSeat(3, seatHolder3, "Del C", "TB C", "DE");
        vm.stopPrank();

        vm.prank(seatHolder1);
        uint256 pid = instance.createProposal(
            OZFParliament.ProposalType.Investment,
            "Investment Act",
            "Desc",
            "TB A",
            0,
            ""
        );

        // 2 for, 0 against => 100% approval
        vm.prank(seatHolder2);
        instance.voteOnProposal(pid, true);
        vm.prank(seatHolder3);
        instance.voteOnProposal(pid, true);

        vm.warp(block.timestamp + 8 days);

        vm.expectEmit(true, false, false, true);
        emit OZFParliament.ProposalExecuted(pid, OZFParliament.ProposalStatus.Executed);

        vm.prank(chairman);
        instance.executeProposal(pid);
    }

    function test_ExecuteProposal_Rejected() public {
        vm.startPrank(chairman);
        instance.assignSeat(1, seatHolder1, "Del A", "TB A", "US");
        instance.assignSeat(2, seatHolder2, "Del B", "TB B", "GB");
        vm.stopPrank();

        vm.prank(seatHolder1);
        uint256 pid = instance.createProposal(
            OZFParliament.ProposalType.Negotiation,
            "Negotiation",
            "Desc",
            "TB A",
            0,
            ""
        );

        // 0 for, 1 against => <55%
        vm.prank(seatHolder2);
        instance.voteOnProposal(pid, false);

        vm.warp(block.timestamp + 8 days);

        vm.expectEmit(true, false, false, true);
        emit OZFParliament.ProposalExecuted(pid, OZFParliament.ProposalStatus.Rejected);

        vm.prank(chairman);
        instance.executeProposal(pid);
    }

    function test_ExecuteProposal_Reverts_VotingStillActive() public {
        _assignAndGetSeatHolder();

        vm.prank(seatHolder1);
        uint256 pid = instance.createProposal(
            OZFParliament.ProposalType.Trade,
            "Trade",
            "Desc",
            "TB",
            0,
            ""
        );

        vm.prank(chairman);
        vm.expectRevert("Voting still active");
        instance.executeProposal(pid);
    }

    function test_ExecuteProposal_Reverts_Unauthorized() public {
        _assignAndGetSeatHolder();

        vm.prank(seatHolder1);
        uint256 pid = instance.createProposal(
            OZFParliament.ProposalType.Trade,
            "Trade",
            "Desc",
            "TB",
            0,
            ""
        );

        vm.warp(block.timestamp + 8 days);

        vm.prank(nobody);
        vm.expectRevert("Not authorized");
        instance.executeProposal(pid);
    }

    // -----------------------------------------------------------------------
    // 7. Update Chairman
    // -----------------------------------------------------------------------
    function test_UpdateChairman() public {
        address newChairman = address(20);

        vm.expectEmit(true, true, false, false);
        emit OZFParliament.ChairmanUpdated(chairman, newChairman);

        vm.prank(chairman);
        instance.updateChairman(newChairman);

        assertEq(instance.chairman(), newChairman);
        assertTrue(instance.hasRole(instance.CHAIRMAN_ROLE(), newChairman));
        assertFalse(instance.hasRole(instance.CHAIRMAN_ROLE(), chairman));
    }

    function test_UpdateChairman_Reverts_ZeroAddress() public {
        vm.prank(chairman);
        vm.expectRevert("Invalid address");
        instance.updateChairman(address(0));
    }

    function test_UpdateChairman_Reverts_NonChairman() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.updateChairman(address(20));
    }

    // -----------------------------------------------------------------------
    // 8. Pause / Unpause
    // -----------------------------------------------------------------------
    function test_PauseAndUnpause() public {
        vm.prank(chairman);
        instance.pause();
        assertTrue(instance.paused());

        vm.prank(chairman);
        instance.unpause();
        assertFalse(instance.paused());
    }

    function test_Pause_Reverts_NonChairman() public {
        vm.prank(nobody);
        vm.expectRevert();
        instance.pause();
    }

    // -----------------------------------------------------------------------
    // 9. getSeat view
    // -----------------------------------------------------------------------
    function test_GetSeat_ReturnsCorrectData() public {
        vm.prank(chairman);
        instance.assignSeat(5, seatHolder1, "Delegation Five", "TB Five", "JP");

        (address holder, string memory del, string memory tb, uint256 termEnd, bool active) =
            instance.getSeat(5);

        assertEq(holder, seatHolder1);
        assertEq(del, "Delegation Five");
        assertEq(tb, "TB Five");
        assertApproxEqAbs(termEnd, block.timestamp + instance.TERM_DURATION(), 1);
        assertTrue(active);
    }
}
