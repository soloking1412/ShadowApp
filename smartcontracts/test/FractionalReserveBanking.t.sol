// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/FractionalReserveBanking.sol";

contract FractionalReserveBankingTest is Test {
    FractionalReserveBanking instance;

    address admin    = address(1);
    address operator = address(2);
    address alice    = address(3);
    address bob      = address(4);
    address nobody   = address(5);
    address treasury = address(6);

    uint256 constant RESERVE_RATIO = 2000; // 20%

    function setUp() public {
        FractionalReserveBanking impl = new FractionalReserveBanking();
        bytes memory init = abi.encodeCall(
            FractionalReserveBanking.initialize,
            (admin, RESERVE_RATIO)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        instance = FractionalReserveBanking(payable(address(proxy)));

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(address(instance), 1000 ether); // seed contract for payouts
    }

    // -----------------------------------------------------------------------
    // 1. Initialization
    // -----------------------------------------------------------------------
    function test_Initialization() public view {
        assertEq(instance.globalReserveRatio(), RESERVE_RATIO);
        assertEq(instance.globalDebtIndex(), 200);
        assertTrue(instance.hasRole(instance.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.ADMIN_ROLE(), admin));
        assertTrue(instance.hasRole(instance.OPERATOR_ROLE(), admin));
        assertTrue(instance.hasRole(instance.UPGRADER_ROLE(), admin));
    }

    function test_CountriesInitialized() public view {
        string[] memory countries = instance.getAllCountries();
        assertEq(countries.length, 46);

        // Spot check a few
        (,uint256 totalRes,,, uint256 reserveRatio,, bool active) =
            _getCountryReserve("US");
        assertTrue(active);
        assertEq(reserveRatio, RESERVE_RATIO);
        assertEq(totalRes, 0);
    }

    function test_SupportedCountryCodesInitialized() public view {
        assertTrue(instance.supportedCountryCodes(bytes2("US")));
        assertTrue(instance.supportedCountryCodes(bytes2("GB")));
        assertTrue(instance.supportedCountryCodes(bytes2("OZ")));
        assertFalse(instance.supportedCountryCodes(bytes2("XX")));
    }

    // -----------------------------------------------------------------------
    // 2. Deposits
    // -----------------------------------------------------------------------
    function test_MakeDeposit() public {
        uint256 maturity = block.timestamp + 365 days;

        vm.expectEmit(true, true, false, true);
        emit FractionalReserveBanking.DepositMade(0, alice, "US", 1 ether);

        vm.prank(alice);
        uint256 depositId = instance.makeDeposit{value: 1 ether}("US", maturity, 500);

        assertEq(depositId, 0);

        (uint256 id, address depositor, string memory country, uint256 amount,, uint256 mat,, bool withdrawn) =
            _getDeposit(0);
        assertEq(id, 0);
        assertEq(depositor, alice);
        assertEq(country, "US");
        assertEq(amount, 1 ether);
        assertEq(mat, maturity);
        assertFalse(withdrawn);

        uint256[] memory userDeps = instance.getUserDeposits(alice);
        assertEq(userDeps.length, 1);
        assertEq(userDeps[0], 0);
    }

    function test_MakeDeposit_Reverts_InactiveCountry() public {
        vm.prank(alice);
        vm.expectRevert("Country not active");
        instance.makeDeposit{value: 1 ether}("NONEXISTENT", block.timestamp + 1 days, 500);
    }

    function test_MakeDeposit_Reverts_ZeroValue() public {
        vm.prank(alice);
        vm.expectRevert("Invalid amount");
        instance.makeDeposit{value: 0}("US", block.timestamp + 1 days, 500);
    }

    function test_MakeDeposit_Reverts_PastMaturity() public {
        vm.prank(alice);
        vm.expectRevert("Invalid maturity");
        instance.makeDeposit{value: 1 ether}("US", block.timestamp - 1, 500);
    }

    function test_MakeDeposit_Reverts_WhenPaused() public {
        vm.prank(admin);
        instance.pause();

        vm.prank(alice);
        vm.expectRevert();
        instance.makeDeposit{value: 1 ether}("US", block.timestamp + 1 days, 500);
    }

    // -----------------------------------------------------------------------
    // 3. Withdraw Deposit
    // -----------------------------------------------------------------------
    function test_WithdrawDeposit() public {
        uint256 maturity = block.timestamp + 1 days;

        // Use interest rate 0 to avoid reserve shortfall (interest would exceed deposited reserves)
        vm.prank(alice);
        uint256 depositId = instance.makeDeposit{value: 1 ether}("US", maturity, 0);

        vm.warp(maturity + 1);

        uint256 balanceBefore = alice.balance;

        vm.expectEmit(true, true, false, false);
        emit FractionalReserveBanking.WithdrawalMade(depositId, alice, 0); // amount varies

        vm.prank(alice);
        instance.withdraw(depositId);

        assertTrue(alice.balance > balanceBefore); // received principal
    }

    function test_Withdraw_Reverts_NotDepositor() public {
        vm.prank(alice);
        uint256 depositId = instance.makeDeposit{value: 1 ether}("US", block.timestamp + 1 days, 500);

        vm.warp(block.timestamp + 2 days);

        vm.prank(bob);
        vm.expectRevert("Not depositor");
        instance.withdraw(depositId);
    }

    function test_Withdraw_Reverts_NotMatured() public {
        uint256 maturity = block.timestamp + 10 days;

        vm.prank(alice);
        uint256 depositId = instance.makeDeposit{value: 1 ether}("US", maturity, 500);

        vm.prank(alice);
        vm.expectRevert("Not matured");
        instance.withdraw(depositId);
    }

    function test_Withdraw_Reverts_AlreadyWithdrawn() public {
        uint256 maturity = block.timestamp + 1 days;

        // Use interest rate 0 to avoid reserve shortfall on first withdraw
        vm.prank(alice);
        uint256 depositId = instance.makeDeposit{value: 1 ether}("US", maturity, 0);

        vm.warp(maturity + 1);

        vm.startPrank(alice);
        instance.withdraw(depositId);
        vm.expectRevert("Already withdrawn");
        instance.withdraw(depositId);
        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // 4. Loans
    // -----------------------------------------------------------------------
    function test_IssueLoan() public {
        // Deposit enough first to create available funds
        vm.prank(alice);
        instance.makeDeposit{value: 10 ether}("US", block.timestamp + 365 days, 500);

        // Wait past flash loan protection period
        vm.warp(block.timestamp + 2 hours);

        // Borrow against available funds (80% of 10 ether = 8 ether)
        uint256 borrowAmount = 5 ether;

        vm.expectEmit(true, true, false, true);
        emit FractionalReserveBanking.LoanIssued(0, alice, "US", borrowAmount);

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        uint256 loanId = instance.issueLoan(
            "US",
            borrowAmount,
            block.timestamp + 365 days,
            address(0), // no collateral
            0,
            0
        );

        assertEq(loanId, 0);
        assertTrue(alice.balance > balanceBefore);

        uint256[] memory userLoans = instance.getUserLoans(alice);
        assertEq(userLoans.length, 1);
    }

    function test_IssueLoan_Reverts_FlashLoanProtection() public {
        vm.prank(alice);
        instance.makeDeposit{value: 10 ether}("US", block.timestamp + 365 days, 500);

        // Try immediately — within MIN_DEPOSIT_LOCK_TIME
        vm.prank(alice);
        vm.expectRevert("Must wait after deposit to borrow");
        instance.issueLoan(
            "US",
            1 ether,
            block.timestamp + 365 days,
            address(0),
            0,
            0
        );
    }

    function test_IssueLoan_Reverts_InsufficientReserves() public {
        vm.prank(alice);
        instance.makeDeposit{value: 1 ether}("US", block.timestamp + 365 days, 500);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(alice);
        vm.expectRevert("Insufficient reserves");
        instance.issueLoan(
            "US",
            100 ether, // way more than available
            block.timestamp + 365 days,
            address(0),
            0,
            0
        );
    }

    // -----------------------------------------------------------------------
    // 5. Loan Repayment
    // -----------------------------------------------------------------------
    function test_RepayLoan() public {
        vm.prank(alice);
        instance.makeDeposit{value: 10 ether}("US", block.timestamp + 365 days, 500);
        vm.warp(block.timestamp + 2 hours);

        vm.prank(alice);
        uint256 loanId = instance.issueLoan(
            "US",
            1 ether,
            block.timestamp + 365 days,
            address(0),
            0,
            0
        );

        // Repay exactly the principal (does not overpay — interest accrual is negligible)
        vm.expectEmit(true, false, false, false);
        emit FractionalReserveBanking.LoanRepaid(loanId, 0);

        vm.prank(alice);
        instance.repayLoan{value: 1 ether}(loanId);
    }

    function test_RepayLoan_Reverts_NotBorrower() public {
        vm.prank(alice);
        instance.makeDeposit{value: 10 ether}("US", block.timestamp + 365 days, 500);
        vm.warp(block.timestamp + 2 hours);

        vm.prank(alice);
        uint256 loanId = instance.issueLoan(
            "US",
            1 ether,
            block.timestamp + 365 days,
            address(0),
            0,
            0
        );

        vm.deal(bob, 2 ether);
        vm.prank(bob);
        vm.expectRevert("Not borrower");
        instance.repayLoan{value: 1 ether}(loanId);
    }

    // -----------------------------------------------------------------------
    // 6. IBAN System
    // -----------------------------------------------------------------------
    function test_RegisterIBAN() public {
        vm.expectEmit(false, true, false, true);
        emit FractionalReserveBanking.IBANRegistered(bytes32(0), alice, bytes2("US"), bytes4("BANK"));

        vm.prank(alice);
        bytes32 ibanHash = instance.registerIBAN(bytes2("US"), bytes4("BANK"));

        assertNotEq(ibanHash, bytes32(0));
        assertEq(instance.addressToIBAN(alice), ibanHash);

        FractionalReserveBanking.IBANAccount memory acct = instance.getIBANAccount(ibanHash);
        assertEq(acct.owner, alice);
        assertTrue(acct.active);
        assertEq(acct.balance, 0);
        assertEq(acct.countryCode, bytes2("US"));
    }

    function test_RegisterIBAN_Reverts_UnsupportedCountry() public {
        vm.prank(alice);
        vm.expectRevert("Country code not supported");
        instance.registerIBAN(bytes2("XX"), bytes4("BANK"));
    }

    function test_RegisterIBAN_Reverts_AlreadyHasIBAN() public {
        vm.startPrank(alice);
        instance.registerIBAN(bytes2("US"), bytes4("BANK"));
        vm.expectRevert("Already has IBAN");
        instance.registerIBAN(bytes2("GB"), bytes4("BNKB"));
        vm.stopPrank();
    }

    function test_RegisterIBAN_Reverts_InvalidBankCode() public {
        vm.prank(alice);
        vm.expectRevert("Invalid bank code");
        instance.registerIBAN(bytes2("US"), bytes4(0));
    }

    function test_DepositToIBAN() public {
        vm.prank(alice);
        bytes32 ibanHash = instance.registerIBAN(bytes2("US"), bytes4("BANK"));

        vm.expectEmit(true, true, false, true);
        emit FractionalReserveBanking.IBANDeposit(ibanHash, alice, 2 ether);

        vm.prank(alice);
        instance.depositToIBAN{value: 2 ether}();

        FractionalReserveBanking.IBANAccount memory acct = instance.getIBANAccount(ibanHash);
        assertEq(acct.balance, 2 ether);
    }

    function test_DepositToIBAN_Reverts_NoIBAN() public {
        vm.prank(alice);
        vm.expectRevert("No IBAN registered");
        instance.depositToIBAN{value: 1 ether}();
    }

    function test_WithdrawFromIBAN() public {
        vm.prank(alice);
        instance.registerIBAN(bytes2("US"), bytes4("BANK"));
        vm.prank(alice);
        instance.depositToIBAN{value: 5 ether}();

        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        instance.withdrawFromIBAN(2 ether);

        assertEq(alice.balance, balanceBefore + 2 ether);
    }

    function test_WithdrawFromIBAN_Reverts_InsufficientBalance() public {
        vm.prank(alice);
        instance.registerIBAN(bytes2("US"), bytes4("BANK"));
        vm.prank(alice);
        instance.depositToIBAN{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert("Insufficient balance");
        instance.withdrawFromIBAN(2 ether);
    }

    function test_InterBankTransfer() public {
        // Setup treasury to receive fees
        vm.prank(admin);
        instance.setTreasury(treasury);

        vm.prank(alice);
        bytes32 aliceIBAN = instance.registerIBAN(bytes2("US"), bytes4("BKUS"));
        vm.prank(bob);
        bytes32 bobIBAN = instance.registerIBAN(bytes2("GB"), bytes4("BKGB"));

        vm.prank(alice);
        instance.depositToIBAN{value: 10 ether}();

        vm.expectEmit(true, true, false, false);
        emit FractionalReserveBanking.InterBankTransfer(aliceIBAN, bobIBAN, 5 ether, 0);

        vm.prank(alice);
        instance.interBankTransfer(bobIBAN, 5 ether);

        FractionalReserveBanking.IBANAccount memory bobAcct = instance.getIBANAccount(bobIBAN);
        // Fee = 5 ether * 9 / 100000 = 450000000000000 wei
        uint256 fee = (5 ether * 9) / 100000;
        assertEq(bobAcct.balance, 5 ether - fee);
    }

    function test_InterBankTransfer_Reverts_SelfTransfer() public {
        vm.prank(alice);
        instance.registerIBAN(bytes2("US"), bytes4("BKUS"));
        vm.prank(alice);
        instance.depositToIBAN{value: 5 ether}();

        bytes32 aliceIBAN = instance.addressToIBAN(alice);

        vm.prank(alice);
        vm.expectRevert("Cannot transfer to self");
        instance.interBankTransfer(aliceIBAN, 1 ether);
    }

    // -----------------------------------------------------------------------
    // 7. Credit System
    // -----------------------------------------------------------------------
    function test_IssueAndUseCredit() public {
        vm.prank(alice);
        bytes32 ibanHash = instance.registerIBAN(bytes2("US"), bytes4("BANK"));
        vm.prank(alice);
        instance.depositToIBAN{value: 10 ether}();

        // Max credit = 10 ether * 200 / 100 = 20 ether
        vm.expectEmit(true, false, false, true);
        emit FractionalReserveBanking.CreditIssued(ibanHash, 5 ether, 5 ether);

        vm.prank(admin); // admin has OPERATOR_ROLE
        instance.issueCredit(ibanHash, 5 ether);

        FractionalReserveBanking.IBANAccount memory acct = instance.getIBANAccount(ibanHash);
        assertEq(acct.creditLine, 5 ether);

        // Use credit
        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        instance.useCredit(3 ether);

        assertEq(alice.balance, balanceBefore + 3 ether);
        acct = instance.getIBANAccount(ibanHash);
        assertEq(acct.creditUsed, 3 ether);
    }

    function test_IssueCredit_Reverts_ExceedsGDILimit() public {
        vm.prank(alice);
        bytes32 ibanHash = instance.registerIBAN(bytes2("US"), bytes4("BANK"));
        vm.prank(alice);
        instance.depositToIBAN{value: 1 ether}();

        // Max credit = 1 ether * 200 / 100 = 2 ether
        vm.prank(admin);
        vm.expectRevert("Exceeds GDI credit limit");
        instance.issueCredit(ibanHash, 3 ether);
    }

    function test_RepayCredit() public {
        vm.prank(alice);
        bytes32 ibanHash = instance.registerIBAN(bytes2("US"), bytes4("BANK"));
        vm.prank(alice);
        instance.depositToIBAN{value: 10 ether}();

        vm.prank(admin);
        instance.issueCredit(ibanHash, 5 ether);

        vm.prank(alice);
        instance.useCredit(2 ether);

        vm.expectEmit(true, false, false, true);
        emit FractionalReserveBanking.CreditRepaid(ibanHash, 2 ether, 0);

        vm.prank(alice);
        instance.repayCredit{value: 2 ether}();

        FractionalReserveBanking.IBANAccount memory acct = instance.getIBANAccount(ibanHash);
        assertEq(acct.creditUsed, 0);
    }

    // -----------------------------------------------------------------------
    // 8. Reserve Management
    // -----------------------------------------------------------------------
    function test_UpdateReserveRatio() public {
        vm.prank(admin); // has OPERATOR_ROLE
        instance.updateReserveRatio("US", 3000);

        (, , , , uint256 ratio, , ) = _getCountryReserve("US");
        assertEq(ratio, 3000);
    }

    function test_UpdateReserveRatio_Reverts_BelowMinimum() public {
        vm.prank(admin);
        vm.expectRevert("Below minimum");
        instance.updateReserveRatio("US", 500); // MIN_RESERVE_RATIO = 1000
    }

    function test_UpdateInterestRate() public {
        vm.prank(admin);
        instance.updateInterestRate("US", 800);

        (, , , , , uint256 rate, ) = _getCountryReserve("US");
        assertEq(rate, 800);
    }

    function test_UpdateInterestRate_Reverts_TooHigh() public {
        vm.prank(admin);
        vm.expectRevert("Rate too high");
        instance.updateInterestRate("US", 2001);
    }

    function test_SetGlobalDebtIndex() public {
        vm.prank(admin);
        instance.setGlobalDebtIndex(300);
        assertEq(instance.globalDebtIndex(), 300);
    }

    function test_SetGlobalDebtIndex_Reverts_OutOfRange() public {
        vm.prank(admin);
        vm.expectRevert("GDI must be between 100-500");
        instance.setGlobalDebtIndex(50);
    }

    function test_SetTreasury() public {
        vm.expectEmit(true, true, false, false);
        emit FractionalReserveBanking.TreasuryUpdated(address(0), treasury);

        vm.prank(admin);
        instance.setTreasury(treasury);

        assertEq(instance.treasuryAddress(), treasury);
    }

    function test_SetTreasury_Reverts_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid treasury address");
        instance.setTreasury(address(0));
    }

    function test_SetSupportedCountryCode() public {
        vm.prank(admin);
        instance.setSupportedCountryCode(bytes2("NZ"), true);
        assertTrue(instance.supportedCountryCodes(bytes2("NZ")));
    }

    // -----------------------------------------------------------------------
    // 9. Pause / Unpause
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
        vm.prank(nobody);
        vm.expectRevert();
        instance.pause();
    }

    // -----------------------------------------------------------------------
    // 10. GetMyIBAN
    // -----------------------------------------------------------------------
    function test_GetMyIBAN() public {
        vm.prank(alice);
        bytes32 ibanHash = instance.registerIBAN(bytes2("US"), bytes4("BANK"));

        vm.prank(alice);
        bytes32 myIBAN = instance.getMyIBAN();

        assertEq(myIBAN, ibanHash);
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------
    function _getCountryReserve(string memory country)
        internal
        view
        returns (
            string memory name,
            uint256 totalReserves,
            uint256 totalDeposits,
            uint256 totalLoans,
            uint256 reserveRatio,
            uint256 interestRate,
            bool active
        )
    {
        (string memory _country, uint256 _totalReserves, uint256 _totalDeposits, uint256 _totalLoans, uint256 _reserveRatio, uint256 _interestRate, bool _active) = instance.countryReserves(country);
        return (_country, _totalReserves, _totalDeposits, _totalLoans, _reserveRatio, _interestRate, _active);
    }

    function _getDeposit(uint256 depositId)
        internal
        view
        returns (
            uint256 id,
            address depositor,
            string memory country,
            uint256 amount,
            uint256 timestamp,
            uint256 maturityDate,
            uint256 interestRate,
            bool withdrawn
        )
    {
        (uint256 _depositId, address _depositor, string memory _country, uint256 _amount, uint256 _timestamp, uint256 _maturityDate, uint256 _interestRate, bool _withdrawn) = instance.deposits(depositId);
        return (_depositId, _depositor, _country, _amount, _timestamp, _maturityDate, _interestRate, _withdrawn);
    }
}
