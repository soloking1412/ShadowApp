// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ICFLending.sol";

contract ICFLendingTest is Test {
    ICFLending instance;
    address admin = address(1);
    address borrower = address(2);
    address borrower2 = address(3);

    function setUp() public {
        ICFLending impl = new ICFLending();
        bytes memory init = abi.encodeCall(ICFLending.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = ICFLending(address(proxy));
    }

    // ── G Score ────────────────────────────────────────────────────────────

    function test_SetGScore() public {
        vm.prank(admin);
        instance.setGScore(borrower, 75);
        assertEq(instance.getGScore(borrower), 75);
    }

    function test_SetGScoreAbove100Reverts() public {
        vm.prank(admin);
        vm.expectRevert("Max 100");
        instance.setGScore(borrower, 101);
    }

    function test_SetGScoreOnlyOwner() public {
        vm.prank(borrower);
        vm.expectRevert();
        instance.setGScore(borrower, 50);
    }

    // ── ICF Standard Loan ──────────────────────────────────────────────────

    function test_ApplyICFLoanMicro() public {
        vm.prank(admin);
        instance.setGScore(borrower, 15); // minGScore for Micro = 10

        vm.prank(borrower);
        uint256 loanId = instance.applyICFLoan(
            ICFLending.LoanTier.Micro,
            2e24, // $2M OICD
            0,    // Y5 term
            "Build infrastructure"
        );

        assertEq(loanId, 1);
        ICFLending.Loan memory l = instance.getLoan(1);
        assertEq(l.borrower, borrower);
        assertEq(uint8(l.loanType), uint8(ICFLending.LoanType.ICF));
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Applied));
        assertEq(l.principalOICD, 2e24);
        assertEq(l.interestRateBps, 850); // Micro default rate
    }

    function test_ApplyICFLoanInsufficientGScoreReverts() public {
        vm.prank(admin);
        instance.setGScore(borrower, 5); // below Micro min of 10

        vm.prank(borrower);
        vm.expectRevert("G-score too low for this tier");
        instance.applyICFLoan(ICFLending.LoanTier.Micro, 2e24, 0, "test");
    }

    function test_ApplyICFLoanOutOfRangeReverts() public {
        vm.prank(admin);
        instance.setGScore(borrower, 50);

        vm.prank(borrower);
        vm.expectRevert("Amount out of tier range");
        instance.applyICFLoan(
            ICFLending.LoanTier.Micro,
            500e24, // way over micro max
            0,
            "too much"
        );
    }

    // ── Approve / Reject / Default ─────────────────────────────────────────

    function test_ApproveLoan() public {
        vm.prank(admin);
        instance.setGScore(borrower, 15);
        vm.prank(borrower);
        uint256 loanId = instance.applyICFLoan(ICFLending.LoanTier.Micro, 2e24, 0, "purpose");

        vm.prank(admin);
        instance.approveLoan(loanId);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Active));
        assertEq(instance.totalLoansIssued(), 1);
        assertEq(instance.activeLoans(), 1);
    }

    function test_RejectLoan() public {
        vm.prank(admin);
        instance.setGScore(borrower, 15);
        vm.prank(borrower);
        uint256 loanId = instance.applyICFLoan(ICFLending.LoanTier.Micro, 2e24, 0, "purpose");

        vm.prank(admin);
        instance.rejectLoan(loanId, "Credit risk too high");

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Rejected));
    }

    function test_MarkDefault() public {
        vm.prank(admin);
        instance.setGScore(borrower, 30);
        vm.prank(borrower);
        uint256 loanId = instance.applyICFLoan(ICFLending.LoanTier.Small, 15e24, 0, "");
        vm.prank(admin);
        instance.approveLoan(loanId);

        vm.prank(admin);
        instance.markDefault(loanId);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Defaulted));
        assertEq(instance.activeLoans(), 0);
        // G score should drop by 20 (from 30 to 10)
        assertEq(instance.getGScore(borrower), 10);
    }

    // ── Repayment ──────────────────────────────────────────────────────────

    function test_RepayLoanPartial() public {
        vm.prank(admin);
        instance.setGScore(borrower, 15);
        vm.prank(borrower);
        uint256 loanId = instance.applyICFLoan(ICFLending.LoanTier.Micro, 2e24, 0, "repay test");
        vm.prank(admin);
        instance.approveLoan(loanId);

        vm.prank(borrower);
        instance.repayLoan(loanId, 1e24);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertEq(l.repaidOICD, 1e24);
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Active)); // not fully repaid
    }

    function test_RepayLoanFull() public {
        vm.prank(admin);
        instance.setGScore(borrower, 15);
        vm.prank(borrower);
        uint256 loanId = instance.applyICFLoan(ICFLending.LoanTier.Micro, 2e24, 0, "");
        vm.prank(admin);
        instance.approveLoan(loanId);

        vm.prank(borrower);
        instance.repayLoan(loanId, 2e24);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Completed));
        assertEq(instance.activeLoans(), 0);
        // G score +5 on successful repayment (15 -> 20)
        assertEq(instance.getGScore(borrower), 20);
    }

    function test_RepayLoanNotBorrowerReverts() public {
        vm.prank(admin);
        instance.setGScore(borrower, 15);
        vm.prank(borrower);
        uint256 loanId = instance.applyICFLoan(ICFLending.LoanTier.Micro, 2e24, 0, "");
        vm.prank(admin);
        instance.approveLoan(loanId);

        vm.prank(borrower2);
        vm.expectRevert("Not borrower");
        instance.repayLoan(loanId, 1e24);
    }

    // ── First90 Loan ───────────────────────────────────────────────────────

    function test_ApplyFirst90() public {
        vm.prank(borrower);
        uint256 loanId = instance.applyFirst90(7e24, "Launch my business");

        assertEq(loanId, 1);
        assertEq(instance.first90Counter(), 1);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertEq(uint8(l.loanType), uint8(ICFLending.LoanType.First90));
        assertEq(l.interestRateBps, 0); // interest-free
        assertEq(instance.activeFirst90(borrower), loanId);
    }

    function test_First90DuplicateReverts() public {
        vm.prank(borrower);
        instance.applyFirst90(7e24, "first");

        vm.prank(borrower);
        vm.expectRevert("Already have active First90 loan");
        instance.applyFirst90(7e24, "second");
    }

    function test_First90OutOfRangeReverts() public {
        vm.prank(borrower);
        vm.expectRevert("First90: $5M-$10M OICD");
        instance.applyFirst90(1e24, "too little");
    }

    function test_ProveRevenue() public {
        vm.prank(borrower);
        uint256 loanId = instance.applyFirst90(7e24, "business");

        vm.prank(borrower);
        instance.proveRevenue(loanId);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertTrue(l.revenueProven);
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Active));
        assertEq(instance.first90Successes(), 1);
    }

    // ── FFE Loan ───────────────────────────────────────────────────────────

    function test_ApplyFFE() public {
        vm.prank(borrower);
        uint256 loanId = instance.applyFFE(50_000 * 1e18, "MIT");

        assertEq(loanId, 1);
        assertEq(instance.ffeCounter(), 1);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertEq(uint8(l.loanType), uint8(ICFLending.LoanType.FFE));
        assertEq(l.interestRateBps, 350);
        assertEq(l.institution, "MIT");
    }

    function test_ConfirmEmployment() public {
        vm.prank(borrower);
        uint256 loanId = instance.applyFFE(50_000 * 1e18, "Harvard");

        vm.prank(borrower);
        instance.confirmEmployment(loanId);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertTrue(l.employed);
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Active));
        assertGt(l.dueAt, block.timestamp);
    }

    // ── Debt Restructuring ─────────────────────────────────────────────────

    function test_ApplyDebtRestructuring() public {
        vm.prank(admin);
        uint256 loanId = instance.applyDebtRestructuring("VZ", 500, 1000e24, 500, 0);

        assertEq(loanId, 1);
        assertEq(instance.debtRestructuringCounter(), 1);

        ICFLending.Loan memory l = instance.getLoan(loanId);
        assertEq(uint8(l.loanType), uint8(ICFLending.LoanType.DebtRestructuring));
        assertEq(uint8(l.status), uint8(ICFLending.LoanStatus.Approved));
        assertEq(l.countryCode, "VZ");
    }

    function test_DebtRestructuringInvalidRateReverts() public {
        vm.prank(admin);
        vm.expectRevert("Rate 2.5%-10%");
        instance.applyDebtRestructuring("VZ", 500, 1000e24, 200, 0); // 200 bps < min 250
    }

    // ── Platform Stats ─────────────────────────────────────────────────────

    function test_PlatformStats() public {
        vm.prank(admin);
        instance.setGScore(borrower, 15);
        vm.prank(borrower);
        instance.applyICFLoan(ICFLending.LoanTier.Micro, 2e24, 0, "");
        vm.prank(borrower2);
        instance.applyFirst90(7e24, "biz");
        vm.prank(borrower2);
        instance.applyFFE(10_000 * 1e18, "Oxford");

        (
            ,
            ,
            ,
            ,
            uint256 first90Count,
            ,
            uint256 ffeCount,
            ,

        ) = instance.platformStats();

        assertEq(first90Count, 1);
        assertEq(ffeCount, 1);
    }

    function test_GetBorrowerLoans() public {
        vm.prank(admin);
        instance.setGScore(borrower, 15);
        vm.prank(borrower);
        instance.applyICFLoan(ICFLending.LoanTier.Micro, 2e24, 0, "a");
        vm.prank(borrower);
        instance.applyICFLoan(ICFLending.LoanTier.Micro, 3e24, 0, "b");

        uint256[] memory ids = instance.getBorrowerLoans(borrower);
        assertEq(ids.length, 2);
    }

    function test_GetTierConfig() public view {
        ICFLending.TierConfig memory tc = instance.getTierConfig(ICFLending.LoanTier.Institutional);
        assertEq(tc.minOICD, 200e24);
        assertEq(tc.maxOICD, 1000e24);
        assertEq(tc.minGScore, 70);
        assertEq(tc.defaultRateBps, 250);
    }
}
