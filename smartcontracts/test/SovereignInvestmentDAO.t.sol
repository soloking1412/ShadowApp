// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/SovereignInvestmentDAO.sol";

contract SovereignInvestmentDAOTest is Test {
    SovereignInvestmentDAO instance;

    address admin    = address(1);
    address proposer = address(2);
    address ministry1 = address(3);
    address ministry2 = address(4);
    address user     = address(5);

    uint256 constant VOTING_PERIOD   = 3 days;
    uint256 constant EXECUTION_DELAY = 1 days;
    uint256 constant QUORUM_PCT      = 20;

    function setUp() public {
        SovereignInvestmentDAO impl = new SovereignInvestmentDAO();
        bytes memory init = abi.encodeCall(
            SovereignInvestmentDAO.initialize,
            (admin, VOTING_PERIOD, EXECUTION_DELAY, QUORUM_PCT)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = SovereignInvestmentDAO(address(proxy));

        // Grant PROPOSER_ROLE to proposer
        bytes32 proposerRole = instance.PROPOSER_ROLE();
        vm.prank(admin);
        instance.grantRole(proposerRole, proposer);
    }

    // -----------------------------------------------------------------------
    // 1. Initialization
    // -----------------------------------------------------------------------
    function test_Initialization() public view {
        assertEq(instance.votingPeriod(), VOTING_PERIOD);
        assertEq(instance.executionDelay(), EXECUTION_DELAY);
        assertEq(instance.quorumPercentage(), QUORUM_PCT);
        assertEq(instance.ministryQuorum(), 55);
        assertEq(instance.emergencyQuorum(), 60);
        assertTrue(instance.hasRole(instance.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.UPGRADER_ROLE(), admin));
        assertTrue(instance.hasRole(instance.MINISTRY_ROLE(), admin));
        assertTrue(instance.hasRole(instance.PROPOSER_ROLE(), admin));
    }

    function test_MinistryWeightsInitialized() public view {
        assertEq(instance.ministryWeights(SovereignInvestmentDAO.MinistryType.Treasury),      20);
        assertEq(instance.ministryWeights(SovereignInvestmentDAO.MinistryType.Finance),       18);
        assertEq(instance.ministryWeights(SovereignInvestmentDAO.MinistryType.Infrastructure),15);
        assertEq(instance.ministryWeights(SovereignInvestmentDAO.MinistryType.Trade),         13);
        assertEq(instance.ministryWeights(SovereignInvestmentDAO.MinistryType.Defense),       12);
        assertEq(instance.ministryWeights(SovereignInvestmentDAO.MinistryType.Energy),        12);
        assertEq(instance.ministryWeights(SovereignInvestmentDAO.MinistryType.Technology),    10);
    }

    // -----------------------------------------------------------------------
    // 2. Ministry Registration
    // -----------------------------------------------------------------------
    function test_RegisterMinistry() public {
        vm.expectEmit(true, false, false, true);
        emit SovereignInvestmentDAO.MinistryRegistered(ministry1, SovereignInvestmentDAO.MinistryType.Treasury);

        vm.prank(admin);
        instance.registerMinistry(ministry1, SovereignInvestmentDAO.MinistryType.Treasury);

        SovereignInvestmentDAO.Ministry memory m = instance.getMinistry(ministry1);
        assertEq(m.ministry, ministry1);
        assertTrue(m.active);
        assertEq(m.votingWeight, 20);
        assertTrue(instance.hasRole(instance.MINISTRY_ROLE(), ministry1));

        address[] memory list = instance.getAllMinistries();
        assertEq(list.length, 1);
        assertEq(list[0], ministry1);
    }

    function test_RegisterMinistry_Reverts_NonAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        instance.registerMinistry(ministry1, SovereignInvestmentDAO.MinistryType.Treasury);
    }

    function test_RegisterMinistry_Reverts_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid ministry");
        instance.registerMinistry(address(0), SovereignInvestmentDAO.MinistryType.Treasury);
    }

    function test_RegisterMinistry_Reverts_Duplicate() public {
        vm.startPrank(admin);
        instance.registerMinistry(ministry1, SovereignInvestmentDAO.MinistryType.Treasury);
        vm.expectRevert("Invalid ministry");
        instance.registerMinistry(ministry1, SovereignInvestmentDAO.MinistryType.Finance);
        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // 3. Proposals
    // -----------------------------------------------------------------------
    function test_CreateProposal() public {
        vm.expectEmit(true, true, false, true);
        emit SovereignInvestmentDAO.ProposalCreated(0, proposer, SovereignInvestmentDAO.ProposalCategory.Policy);

        vm.prank(proposer);
        uint256 proposalId = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            1000,
            keccak256("doc"),
            "Test policy proposal"
        );

        assertEq(proposalId, 0);
        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(proposalId);
        assertEq(p.proposer, proposer);
        assertEq(uint8(p.state), uint8(SovereignInvestmentDAO.ProposalState.Active));
        assertFalse(p.requiresMinistryApproval);
        assertEq(p.endTime, block.timestamp + VOTING_PERIOD);
    }

    function test_CreateProposal_TreasuryRequiresMinistryApproval() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Treasury,
            5000,
            keccak256("doc"),
            "Treasury proposal"
        );
        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertTrue(p.requiresMinistryApproval);
        assertEq(p.requiredMinistryApprovals, 55); // ministryQuorum
    }

    function test_CreateProposal_EmergencyUsesEmergencyQuorum() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Emergency,
            0,
            keccak256("doc"),
            "Emergency"
        );
        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertTrue(p.requiresMinistryApproval);
        assertEq(p.requiredMinistryApprovals, 60); // emergencyQuorum
    }

    function test_CreateProposal_Reverts_NonProposer() public {
        vm.prank(user);
        vm.expectRevert();
        instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Proposal"
        );
    }

    function test_CreateProposal_Reverts_WhenPaused() public {
        vm.prank(admin);
        instance.pause();

        vm.prank(proposer);
        vm.expectRevert();
        instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Proposal"
        );
    }

    // -----------------------------------------------------------------------
    // 4. Voting
    // -----------------------------------------------------------------------
    function test_CastVote() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Vote test"
        );

        vm.expectEmit(true, true, false, true);
        emit SovereignInvestmentDAO.VoteCast(user, pid, 1, 1);

        vm.prank(user);
        instance.castVote(pid, 1); // 1 = for

        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertEq(p.forVotes, 1);
        assertEq(p.againstVotes, 0);
    }

    function test_CastVote_Against() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Against test"
        );

        vm.prank(user);
        instance.castVote(pid, 0); // 0 = against

        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertEq(p.againstVotes, 1);
    }

    function test_CastVote_Abstain() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Abstain test"
        );

        vm.prank(user);
        instance.castVote(pid, 2); // 2 = abstain

        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertEq(p.abstainVotes, 1);
    }

    function test_CastVote_Reverts_DoubleVote() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Double vote test"
        );

        vm.startPrank(user);
        instance.castVote(pid, 1);
        vm.expectRevert("Already voted");
        instance.castVote(pid, 1);
        vm.stopPrank();
    }

    function test_CastVote_Reverts_InvalidSupport() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Invalid support test"
        );

        vm.prank(user);
        vm.expectRevert("Invalid vote");
        instance.castVote(pid, 3);
    }

    function test_CastVote_Reverts_AfterVotingPeriod() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Time test"
        );

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.prank(user);
        vm.expectRevert("Cannot vote");
        instance.castVote(pid, 1);
    }

    // -----------------------------------------------------------------------
    // 5. Ministry Voting
    // -----------------------------------------------------------------------
    function test_CastMinistryVote() public {
        vm.prank(admin);
        instance.registerMinistry(ministry1, SovereignInvestmentDAO.MinistryType.Treasury);

        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Treasury,
            5000,
            keccak256("doc"),
            "Treasury proposal"
        );

        vm.expectEmit(true, true, false, true);
        emit SovereignInvestmentDAO.MinistryVoteCast(pid, ministry1, true);

        vm.prank(ministry1);
        instance.castMinistryVote(pid, true);

        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertEq(p.ministryApprovals, 20); // Treasury weight
        assertTrue(instance.ministryVotes(pid, ministry1));

        SovereignInvestmentDAO.Ministry memory m = instance.getMinistry(ministry1);
        assertEq(m.proposalsVoted, 1);
    }

    function test_CastMinistryVote_Reverts_DoubleVote() public {
        vm.prank(admin);
        instance.registerMinistry(ministry1, SovereignInvestmentDAO.MinistryType.Treasury);

        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Treasury,
            0,
            bytes32(0),
            "Treasury"
        );

        vm.startPrank(ministry1);
        instance.castMinistryVote(pid, true);
        vm.expectRevert("Cannot vote");
        instance.castMinistryVote(pid, true);
        vm.stopPrank();
    }

    function test_CastMinistryVote_Reverts_NonMinistryProposal() public {
        vm.prank(admin);
        instance.registerMinistry(ministry1, SovereignInvestmentDAO.MinistryType.Treasury);

        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Policy - no ministry required"
        );

        vm.prank(ministry1);
        vm.expectRevert("Invalid proposal");
        instance.castMinistryVote(pid, true);
    }

    // -----------------------------------------------------------------------
    // 6. Proposal Execution
    // -----------------------------------------------------------------------
    function test_ExecuteProposal_Succeeded() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Execute test"
        );

        // Cast 5 for votes, 0 against — quorum = 20% of 5 = 1, forVotes (5) > againstVotes (0)
        address[5] memory voters = [address(10), address(11), address(12), address(13), address(14)];
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(voters[i]);
            instance.castVote(pid, 1);
        }

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.expectEmit(true, false, false, false);
        emit SovereignInvestmentDAO.ProposalExecuted(pid);

        vm.prank(admin);
        instance.execute(pid);

        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertTrue(p.executed);
        assertEq(uint8(p.state), uint8(SovereignInvestmentDAO.ProposalState.Executed));
    }

    function test_ExecuteProposal_Reverts_NotSucceeded() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Fail test"
        );

        // No votes => forVotes == 0
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.prank(admin);
        vm.expectRevert("Not succeeded");
        instance.execute(pid);
    }

    function test_ExecuteProposal_Reverts_VotingStillActive() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Early execute test"
        );

        vm.prank(admin);
        vm.expectRevert("Cannot execute");
        instance.execute(pid);
    }

    // -----------------------------------------------------------------------
    // 7. Cancel Proposal
    // -----------------------------------------------------------------------
    function test_CancelProposal_ByProposer() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Cancel test"
        );

        vm.expectEmit(true, false, false, false);
        emit SovereignInvestmentDAO.ProposalCanceled(pid);

        vm.prank(proposer);
        instance.cancel(pid);

        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertTrue(p.canceled);
        assertEq(uint8(p.state), uint8(SovereignInvestmentDAO.ProposalState.Canceled));
    }

    function test_CancelProposal_ByAdmin() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Admin cancel test"
        );

        vm.prank(admin);
        instance.cancel(pid);

        SovereignInvestmentDAO.Proposal memory p = instance.getProposal(pid);
        assertTrue(p.canceled);
    }

    function test_CancelProposal_Reverts_Unauthorized() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Unauthorized cancel"
        );

        vm.prank(user);
        vm.expectRevert("Not authorized");
        instance.cancel(pid);
    }

    function test_CancelProposal_Reverts_AlreadyCanceled() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Double cancel"
        );

        vm.startPrank(proposer);
        instance.cancel(pid);
        vm.expectRevert("Cannot cancel");
        instance.cancel(pid);
        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // 8. Admin Configuration
    // -----------------------------------------------------------------------
    function test_SetVotingPeriod() public {
        vm.prank(admin);
        instance.setVotingPeriod(7 days);
        assertEq(instance.votingPeriod(), 7 days);
    }

    function test_SetVotingPeriod_Reverts_NonAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        instance.setVotingPeriod(7 days);
    }

    function test_SetQuorumPercentage() public {
        vm.prank(admin);
        instance.setQuorumPercentage(30);
        assertEq(instance.quorumPercentage(), 30);
    }

    function test_SetQuorumPercentage_Reverts_Over100() public {
        vm.prank(admin);
        vm.expectRevert("Invalid");
        instance.setQuorumPercentage(101);
    }

    function test_DeactivateMinistry() public {
        vm.startPrank(admin);
        instance.registerMinistry(ministry1, SovereignInvestmentDAO.MinistryType.Technology);
        instance.deactivateMinistry(ministry1);
        vm.stopPrank();

        SovereignInvestmentDAO.Ministry memory m = instance.getMinistry(ministry1);
        assertFalse(m.active);
        assertFalse(instance.hasRole(instance.MINISTRY_ROLE(), ministry1));
    }

    // -----------------------------------------------------------------------
    // 9. Emergency Mode
    // -----------------------------------------------------------------------
    function test_ActivateEmergencyMode() public {
        vm.prank(admin);
        instance.activateEmergencyMode();

        assertTrue(instance.emergencyMode());
        assertTrue(instance.paused());
    }

    function test_DeactivateEmergencyMode() public {
        vm.startPrank(admin);
        instance.activateEmergencyMode();
        instance.deactivateEmergencyMode();
        vm.stopPrank();

        assertFalse(instance.emergencyMode());
        assertFalse(instance.paused());
    }

    // -----------------------------------------------------------------------
    // 10. GetProposalState view
    // -----------------------------------------------------------------------
    function test_GetProposalState_Active() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "State test"
        );
        assertEq(
            uint8(instance.getProposalState(pid)),
            uint8(SovereignInvestmentDAO.ProposalState.Active)
        );
    }

    function test_GetProposalState_Defeated() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Defeated test"
        );

        // No votes => forVotes == 0
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        assertEq(
            uint8(instance.getProposalState(pid)),
            uint8(SovereignInvestmentDAO.ProposalState.Defeated)
        );
    }

    function test_GetProposalState_Canceled() public {
        vm.prank(proposer);
        uint256 pid = instance.propose(
            SovereignInvestmentDAO.ProposalCategory.Policy,
            0,
            bytes32(0),
            "Cancel state test"
        );
        vm.prank(proposer);
        instance.cancel(pid);
        assertEq(
            uint8(instance.getProposalState(pid)),
            uint8(SovereignInvestmentDAO.ProposalState.Canceled)
        );
    }

    // -----------------------------------------------------------------------
    // 11. Pause / Unpause
    // -----------------------------------------------------------------------
    function test_PauseUnpause() public {
        vm.prank(admin);
        instance.pause();
        assertTrue(instance.paused());

        vm.prank(admin);
        instance.unpause();
        assertFalse(instance.paused());
    }

    function test_Pause_Reverts_NonAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        instance.pause();
    }
}
