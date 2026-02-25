// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/PreAllocation.sol";

contract PreAllocationTest is Test {
    PreAllocation instance;
    address admin = address(1);
    address validator = address(2);
    address shareholder = address(3);
    address validator2 = address(4);

    function setUp() public {
        PreAllocation impl = new PreAllocation();
        bytes memory init = abi.encodeCall(PreAllocation.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = PreAllocation(address(proxy));
    }

    // ── Schedules ──────────────────────────────────────────────────────────

    function test_ValidatorSchedule() public view {
        uint256[5] memory sched = instance.getValidatorSchedule();
        assertEq(sched[0], 2_000_000 * 1e18);   // Month 1: $2M
        assertEq(sched[1], 8_000_000 * 1e18);   // Month 2: $8M
        assertEq(sched[2], 32_000_000 * 1e18);  // Month 3: $32M
        assertEq(sched[3], 128_000_000 * 1e18); // Month 4: $128M
        assertEq(sched[4], 512_000_000 * 1e18); // Month 5: $512M
    }

    function test_ShareholderSchedule() public view {
        uint256[8] memory sched = instance.getShareholderSchedule();
        assertEq(sched[0], 2_000_000 * 1e18);   // Month 1: $2M
        assertEq(sched[7], 256_000_000 * 1e18); // Month 8: $256M
    }

    function test_Constants() public view {
        assertEq(instance.SIGNUP_BONUS_OICD(), 150_000 * 1e18);
        assertEq(instance.VALIDATOR_LOCKED_PCT(), 67);
        assertEq(instance.VALIDATOR_FREE_PCT(), 33);
        assertEq(instance.TARGET_VALIDATORS(), 250_000);
    }

    // ── Validator Registration ──────────────────────────────────────────────

    function test_RegisterAsValidator() public {
        vm.prank(validator);
        instance.registerAsValidator("US");

        assertEq(instance.totalValidators(), 1);
        assertEq(instance.totalMembersRegistered(), 1);

        PreAllocation.Member memory m = instance.getMember(validator);
        assertEq(uint8(m.memberType), uint8(PreAllocation.MemberType.Validator));
        assertEq(uint8(m.status), uint8(PreAllocation.MemberStatus.Registered));
        assertEq(m.signupBonus, 150_000 * 1e18);
        assertFalse(m.signupBonusClaimed);
        assertEq(m.country, "US");
    }

    function test_RegisterValidatorTwiceReverts() public {
        vm.prank(validator);
        instance.registerAsValidator("US");

        vm.prank(validator);
        vm.expectRevert("Already registered");
        instance.registerAsValidator("US");
    }

    // ── Shareholder Registration ────────────────────────────────────────────

    function test_RegisterAsShareholder() public {
        vm.prank(shareholder);
        instance.registerAsShareholder("UK");

        assertEq(instance.totalShareholders(), 1);
        assertEq(instance.totalMembersRegistered(), 1);

        PreAllocation.Member memory m = instance.getMember(shareholder);
        assertEq(uint8(m.memberType), uint8(PreAllocation.MemberType.Shareholder));
    }

    function test_CannotRegisterBothTypesReverts() public {
        vm.prank(validator);
        instance.registerAsValidator("AU");

        vm.prank(validator);
        vm.expectRevert("Already registered");
        instance.registerAsShareholder("AU");
    }

    // ── Signup Bonus ────────────────────────────────────────────────────────

    function test_ClaimSignupBonus() public {
        vm.prank(validator);
        instance.registerAsValidator("CA");

        vm.prank(validator);
        instance.claimSignupBonus();

        PreAllocation.Member memory m = instance.getMember(validator);
        assertTrue(m.signupBonusClaimed);
        assertEq(m.totalAllocated, 150_000 * 1e18);
        assertEq(instance.totalAllocatedOICD(), 150_000 * 1e18);
    }

    function test_ClaimSignupBonusTwiceReverts() public {
        vm.prank(validator);
        instance.registerAsValidator("CA");
        vm.prank(validator);
        instance.claimSignupBonus();

        vm.prank(validator);
        vm.expectRevert("Already claimed");
        instance.claimSignupBonus();
    }

    function test_ClaimSignupBonusNotMemberReverts() public {
        vm.prank(validator);
        vm.expectRevert("Not registered");
        instance.claimSignupBonus();
    }

    // ── Monthly Allocation ──────────────────────────────────────────────────

    function test_ClaimMonth1ValidatorAllocation() public {
        vm.prank(validator);
        instance.registerAsValidator("AU");

        // Advance 30 days
        vm.warp(block.timestamp + 31 days);

        vm.prank(validator);
        instance.claimMonthlyAllocation();

        PreAllocation.Member memory m = instance.getMember(validator);
        assertEq(m.monthsClaimed, 1);

        // Validator: 2M total, 67% locked, 33% free
        uint256 allocation = 2_000_000 * 1e18;
        uint256 locked = (allocation * 67) / 100;
        uint256 free = allocation - locked;

        assertEq(m.lockedOICD, locked);
        assertEq(m.totalAllocated, allocation);
        assertEq(instance.totalLockedOICD(), locked);
        assertEq(instance.networkLiquidityPool(), locked);

        // freeOICD starts at signupBonus and adds free portion
        assertEq(m.freeOICD, 150_000 * 1e18 + free);
    }

    function test_ClaimMonth1ShareholderAllocation() public {
        vm.prank(shareholder);
        instance.registerAsShareholder("UK");

        vm.warp(block.timestamp + 31 days);

        vm.prank(shareholder);
        instance.claimMonthlyAllocation();

        PreAllocation.Member memory m = instance.getMember(shareholder);
        assertEq(m.monthsClaimed, 1);
        assertEq(m.lockedOICD, 0); // shareholders: no lock
        // freeOICD = signupBonus + 2M
        assertEq(m.freeOICD, 150_000 * 1e18 + 2_000_000 * 1e18);
    }

    function test_ClaimBeforeMonthElapsedReverts() public {
        vm.prank(validator);
        instance.registerAsValidator("AU");

        vm.prank(validator);
        vm.expectRevert("Month not elapsed");
        instance.claimMonthlyAllocation();
    }

    function test_ClaimAllValidatorMonths() public {
        vm.prank(validator);
        instance.registerAsValidator("DE");

        uint256 registeredAt = block.timestamp;
        vm.warp(registeredAt + 31 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 62 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 93 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 124 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 155 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        PreAllocation.Member memory m = instance.getMember(validator);
        assertEq(m.monthsClaimed, 5);
        assertEq(uint8(m.status), uint8(PreAllocation.MemberStatus.Completed));
    }

    function test_ClaimBeyondMaxMonthsReverts() public {
        vm.prank(validator);
        instance.registerAsValidator("DE");

        uint256 registeredAt = block.timestamp;
        vm.warp(registeredAt + 31 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 62 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 93 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 124 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 155 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.warp(registeredAt + 186 days);
        vm.prank(validator);
        vm.expectRevert("All months claimed");
        instance.claimMonthlyAllocation();
    }

    // ── Early Exit ──────────────────────────────────────────────────────────

    function test_ExitEarly() public {
        vm.prank(validator);
        instance.registerAsValidator("JP");

        vm.warp(block.timestamp + 31 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        vm.prank(validator);
        instance.exitEarly();

        PreAllocation.Member memory m = instance.getMember(validator);
        assertTrue(m.exited);
        assertEq(uint8(m.status), uint8(PreAllocation.MemberStatus.Exited));
    }

    function test_ExitEarlyTwiceReverts() public {
        vm.prank(validator);
        instance.registerAsValidator("JP");
        vm.prank(validator);
        instance.exitEarly();

        vm.prank(validator);
        vm.expectRevert("Already exited");
        instance.exitEarly();
    }

    function test_ClaimAfterExitReverts() public {
        vm.prank(validator);
        instance.registerAsValidator("JP");
        vm.prank(validator);
        instance.exitEarly();

        vm.warp(block.timestamp + 31 days);
        vm.prank(validator);
        vm.expectRevert("Exited");
        instance.claimMonthlyAllocation();
    }

    // ── Network Stats ───────────────────────────────────────────────────────

    function test_NetworkStats() public {
        vm.prank(validator);
        instance.registerAsValidator("US");
        vm.prank(shareholder);
        instance.registerAsShareholder("UK");

        (
            uint256 validators,
            uint256 shareholders,
            uint256 total,
            ,
            ,
            uint256 target,
            uint256 progress
        ) = instance.networkStats();

        assertEq(validators, 1);
        assertEq(shareholders, 1);
        assertEq(total, 2);
        assertEq(target, 250_000);
        assertEq(progress, 0); // 1 / 250_000 = 0
    }

    // ── GetNextClaimAmount ──────────────────────────────────────────────────

    function test_GetNextClaimAmountValidator() public {
        vm.prank(validator);
        instance.registerAsValidator("FR");

        (uint256 nextAmount, uint256 remaining) = instance.getNextClaimAmount(validator);
        assertEq(nextAmount, 2_000_000 * 1e18); // Month 1
        assertEq(remaining, 5);
    }

    function test_GetNextClaimAmountAfterClaim() public {
        vm.prank(validator);
        instance.registerAsValidator("FR");

        vm.warp(block.timestamp + 31 days);
        vm.prank(validator);
        instance.claimMonthlyAllocation();

        (uint256 nextAmount, uint256 remaining) = instance.getNextClaimAmount(validator);
        assertEq(nextAmount, 8_000_000 * 1e18); // Month 2
        assertEq(remaining, 4);
    }
}
