// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/OTDToken.sol";

contract OTDTokenTest is Test {
    OTDToken instance;
    address admin = address(1);
    address holder1 = address(2);
    address holder2 = address(3);
    address holder3 = address(4);

    function setUp() public {
        OTDToken impl = new OTDToken();
        bytes memory init = abi.encodeCall(OTDToken.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = OTDToken(address(proxy));
    }

    // ── Constants & Initialization ──────────────────────────────────────────

    function test_TokenConstants() public view {
        assertEq(instance.OTD_NAME(), "Ozhumanill Trade Dollar");
        assertEq(instance.OTD_SYMBOL(), "OTD");
        assertEq(instance.GIC_NAME(), "Orion Infrastructure Corporation");
        assertEq(instance.GIC_SYMBOL(), "GIC");
        assertEq(instance.DECIMALS(), 18);
    }

    function test_InitialPublicReserve() public view {
        uint256 expectedReserve = instance.OTD_TOTAL_SUPPLY() * 30 / 100;
        assertEq(instance.publicReserveOTD(), expectedReserve);
        assertEq(instance.otdCirculating(), expectedReserve);
    }

    function test_InitialGICReserve() public view {
        uint256 expectedGICReserve = instance.GIC_INITIAL_SUPPLY() * 30 / 100;
        assertEq(instance.publicReserveGIC(), expectedGICReserve);
        assertEq(instance.gicCirculating(), expectedGICReserve);
    }

    // ── Registration ────────────────────────────────────────────────────────

    function test_RegisterAsValidator() public {
        vm.prank(holder1);
        instance.registerAsValidator();

        assertTrue(instance.registeredHolders(holder1));
        assertEq(instance.totalValidators(), 1);
        assertEq(instance.totalHolders(), 1);

        OTDToken.Holder memory h = instance.getHolder(holder1);
        assertTrue(h.isValidator);
        assertEq(uint8(h.holderType), uint8(OTDToken.AllocationType.Validator));
        assertEq(h.gScore, 10);
        assertGt(h.lockedUntil, block.timestamp);
    }

    function test_RegisterAsShareholder() public {
        vm.prank(holder1);
        instance.registerAsShareholder();

        assertTrue(instance.registeredHolders(holder1));
        assertEq(instance.totalShareholders(), 1);

        OTDToken.Holder memory h = instance.getHolder(holder1);
        assertFalse(h.isValidator);
        assertEq(uint8(h.holderType), uint8(OTDToken.AllocationType.Shareholder));
        assertEq(h.gScore, 5);
    }

    function test_DoubleRegistrationReverts() public {
        vm.prank(holder1);
        instance.registerAsValidator();

        vm.prank(holder1);
        vm.expectRevert("Already registered");
        instance.registerAsShareholder();
    }

    // ── OTD Allocation ──────────────────────────────────────────────────────

    function test_AllocateOTD() public {
        uint256 amount = 1_000_000 * 1e18;

        vm.prank(admin);
        instance.allocateOTD(holder1, amount, OTDToken.AllocationType.Validator);

        OTDToken.Holder memory h = instance.getHolder(holder1);
        assertEq(h.otdBalance, amount);

        uint256 initialCirc = instance.OTD_TOTAL_SUPPLY() * 30 / 100;
        assertEq(instance.otdCirculating(), initialCirc + amount);
    }

    function test_AllocateOTDOnlyOwner() public {
        vm.prank(holder1);
        vm.expectRevert();
        instance.allocateOTD(holder2, 1e18, OTDToken.AllocationType.Community);
    }

    function test_AllocateOTDExceedsSupplyReverts() public {
        // Try to allocate more than remaining supply
        uint256 remaining = instance.OTD_TOTAL_SUPPLY() - instance.otdCirculating();

        vm.prank(admin);
        vm.expectRevert("Exceeds OTD supply");
        instance.allocateOTD(holder1, remaining + 1, OTDToken.AllocationType.PublicReserve);
    }

    // ── GIC Allocation ──────────────────────────────────────────────────────

    function test_AllocateGIC() public {
        uint256 amount = 500_000 * 1e18;

        vm.prank(admin);
        instance.allocateGIC(holder1, amount, OTDToken.AllocationType.Development);

        OTDToken.Holder memory h = instance.getHolder(holder1);
        assertEq(h.gicBalance, amount);
    }

    // ── Country Allocation ──────────────────────────────────────────────────

    function test_AllocateToCountry() public {
        uint256 otdAmt = 10_000_000 * 1e18;
        uint256 gicAmt = 1_000_000 * 1e18;

        vm.prank(admin);
        instance.allocateToCountry("LK", otdAmt, gicAmt);

        OTDToken.CountryAllocation memory ca = instance.getCountryAllocation("LK");
        assertEq(ca.countryCode, "LK");
        assertEq(ca.otdAmount, otdAmt);
        assertEq(ca.gicAmount, gicAmt);
        assertFalse(ca.disbursed);
    }

    // ── Governance ──────────────────────────────────────────────────────────

    function test_CreateGovernanceVote() public {
        vm.prank(holder1);
        instance.registerAsValidator();

        vm.prank(holder1);
        uint256 voteId = instance.createGovernanceVote("Proposal: increase reserve ratio", 7);

        assertEq(voteId, 1);
        assertEq(instance.voteCounter(), 1);

        OTDToken.GovernanceVote memory v = instance.getVote(1);
        assertEq(v.votesFor, 0);
        assertEq(v.votesAgainst, 0);
        assertFalse(v.executed);
        assertGt(v.endsAt, block.timestamp);
    }

    function test_CreateVoteUnregisteredReverts() public {
        vm.prank(holder1);
        vm.expectRevert("Must be registered holder");
        instance.createGovernanceVote("Test", 7);
    }

    function test_CastVoteFor() public {
        vm.prank(holder1);
        instance.registerAsValidator();
        vm.prank(holder2);
        instance.registerAsShareholder();

        vm.prank(holder1);
        uint256 voteId = instance.createGovernanceVote("Test proposal", 7);

        vm.prank(holder1);
        instance.castVote(voteId, true);
        vm.prank(holder2);
        instance.castVote(voteId, false);

        OTDToken.GovernanceVote memory v = instance.getVote(voteId);
        assertEq(v.votesFor, 1);
        assertEq(v.votesAgainst, 1);
    }

    function test_CastVoteDoubleVoteReverts() public {
        vm.prank(holder1);
        instance.registerAsValidator();
        vm.prank(holder1);
        uint256 voteId = instance.createGovernanceVote("Test", 7);

        vm.prank(holder1);
        instance.castVote(voteId, true);

        vm.prank(holder1);
        vm.expectRevert("Already voted");
        instance.castVote(voteId, true);
    }

    function test_CastVoteAfterEndReverts() public {
        vm.prank(holder1);
        instance.registerAsValidator();
        vm.prank(holder1);
        uint256 voteId = instance.createGovernanceVote("Test", 1);

        vm.warp(block.timestamp + 2 days);

        vm.prank(holder1);
        vm.expectRevert("Vote ended");
        instance.castVote(voteId, true);
    }

    function test_VoteIncreasesGScore() public {
        vm.prank(holder1);
        instance.registerAsValidator(); // gScore = 10

        vm.prank(holder1);
        uint256 voteId = instance.createGovernanceVote("Test", 7);

        vm.prank(holder1);
        instance.castVote(voteId, true);

        OTDToken.Holder memory h = instance.getHolder(holder1);
        assertEq(h.gScore, 11); // +1 for participation
    }

    function test_ExecuteVote() public {
        vm.prank(holder1);
        instance.registerAsValidator();
        vm.prank(holder2);
        instance.registerAsShareholder();

        vm.prank(holder1);
        uint256 voteId = instance.createGovernanceVote("Proposal", 1);

        vm.prank(holder1);
        instance.castVote(voteId, true);
        vm.prank(holder2);
        instance.castVote(voteId, false); // 1-1 tie, not passed

        vm.warp(block.timestamp + 2 days);
        instance.executeVote(voteId);

        OTDToken.GovernanceVote memory v = instance.getVote(voteId);
        assertTrue(v.executed);
        assertFalse(v.passed); // tie means not passed
    }

    function test_ExecuteVoteBeforeEndReverts() public {
        vm.prank(holder1);
        instance.registerAsValidator();
        vm.prank(holder1);
        uint256 voteId = instance.createGovernanceVote("Proposal", 7);

        vm.expectRevert("Vote still active");
        instance.executeVote(voteId);
    }

    // ── G Score & Stats ─────────────────────────────────────────────────────

    function test_UpdateGScore() public {
        vm.prank(admin);
        instance.updateGScore(holder1, 85);

        OTDToken.Holder memory h = instance.getHolder(holder1);
        assertEq(h.gScore, 85);
    }

    function test_UpdateGScoreAbove100Reverts() public {
        vm.prank(admin);
        vm.expectRevert("Max 100");
        instance.updateGScore(holder1, 101);
    }

    function test_TokenStats() public view {
        (
            uint256 otdSupply,
            uint256 otdOut,
            uint256 gicSupply,
            uint256 gicOut,
            uint256 reserve,
            ,

        ) = instance.tokenStats();

        assertEq(otdSupply, instance.OTD_TOTAL_SUPPLY());
        assertEq(gicSupply, instance.GIC_INITIAL_SUPPLY());
        assertEq(reserve, instance.publicReserveOTD());
        assertEq(otdOut, instance.otdCirculating());
        assertEq(gicOut, instance.gicCirculating());
    }

    function test_VoterHistory() public {
        vm.prank(holder1);
        instance.registerAsValidator();
        vm.prank(holder1);
        uint256 voteId1 = instance.createGovernanceVote("V1", 7);
        vm.prank(holder1);
        uint256 voteId2 = instance.createGovernanceVote("V2", 7);

        vm.prank(holder1);
        instance.castVote(voteId1, true);
        vm.prank(holder1);
        instance.castVote(voteId2, false);

        uint256[] memory history = instance.getVoterHistory(holder1);
        assertEq(history.length, 2);
        assertEq(history[0], voteId1);
        assertEq(history[1], voteId2);
    }
}
