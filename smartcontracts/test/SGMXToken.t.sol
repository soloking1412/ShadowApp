// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/SGMXToken.sol";

contract SGMXTokenTest is Test {
    SGMXToken public token;

    address public owner   = address(1);
    address public alice   = address(2);
    address public bob     = address(3);
    address public charlie = address(4);

    uint256 constant TOTAL_SUPPLY = 250_000_000_000_000_000 * 10**18;

    // ─────────────────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────────────────

    function setUp() public {
        SGMXToken impl = new SGMXToken();
        bytes memory initData = abi.encodeCall(SGMXToken.initialize, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        token = SGMXToken(address(proxy));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Initialization
    // ─────────────────────────────────────────────────────────────────────────

    function test_initialize_ownerSet() public view {
        assertEq(token.owner(), owner);
    }

    function test_initialize_transfersDisabled() public view {
        assertFalse(token.transfersEnabled());
    }

    function test_initialize_oicdPairRate() public view {
        assertEq(token.oicdPairRate(), 1e14); // 0.0001 OICD per SGMX
    }

    function test_initialize_capTable() public view {
        (uint256 founders, uint256 pub, uint256 reserved, uint256 circulating) = token.capTable();
        assertEq(founders,    TOTAL_SUPPLY * 40 / 100);
        assertEq(pub,         TOTAL_SUPPLY * 20 / 100);
        assertEq(reserved,    TOTAL_SUPPLY * 40 / 100);
        assertEq(circulating, TOTAL_SUPPLY * 20 / 100);
    }

    function test_initialize_totalSupplyConstant() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function test_initialize_countersZero() public view {
        assertEq(token.totalInvestors(),   0);
        assertEq(token.dividendCounter(),  0);
        assertEq(token.issuanceCounter(),  0);
        assertEq(token.actionCounter(),    0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Investor Registration
    // ─────────────────────────────────────────────────────────────────────────

    function test_registerInvestor_success() public {
        vm.prank(alice);
        token.registerInvestor("US", 0); // common shares

        assertTrue(token.registered(alice));
        assertEq(token.totalInvestors(), 1);

        SGMXToken.Investor memory inv = token.getInvestor(alice);
        assertEq(inv.jurisdiction, "US");
        assertEq(inv.shareClass,   0);
        assertFalse(inv.kycVerified);
        assertFalse(inv.accredited);
    }

    function test_registerInvestor_emitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit SGMXToken.InvestorRegistered(alice, "GB", 1);
        token.registerInvestor("GB", 1);
    }

    function test_registerInvestor_revertsIfAlreadyRegistered() public {
        vm.prank(alice);
        token.registerInvestor("US", 0);

        vm.prank(alice);
        vm.expectRevert("Already registered");
        token.registerInvestor("US", 0);
    }

    function test_registerInvestor_revertsInvalidShareClass() public {
        vm.prank(alice);
        vm.expectRevert("Invalid share class");
        token.registerInvestor("US", 3); // only 0, 1, 2 valid
    }

    function test_registerInvestor_multipleInvestors() public {
        vm.prank(alice);
        token.registerInvestor("US", 0);
        vm.prank(bob);
        token.registerInvestor("DE", 1);
        vm.prank(charlie);
        token.registerInvestor("JP", 2);

        assertEq(token.totalInvestors(), 3);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. KYC / Compliance
    // ─────────────────────────────────────────────────────────────────────────

    function test_verifyKYC_success() public {
        vm.prank(alice);
        token.registerInvestor("US", 0);

        vm.prank(owner);
        token.verifyKYC(alice);

        SGMXToken.Investor memory inv = token.getInvestor(alice);
        assertTrue(inv.kycVerified);
        assertTrue(inv.accredited);
        assertTrue(token.whitelist(alice));
    }

    function test_verifyKYC_emitsEvent() public {
        vm.prank(alice);
        token.registerInvestor("US", 0);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit SGMXToken.KYCVerified(alice);
        token.verifyKYC(alice);
    }

    function test_verifyKYC_revertsNotRegistered() public {
        vm.prank(owner);
        vm.expectRevert("Not registered");
        token.verifyKYC(alice);
    }

    function test_verifyKYC_revertsNonOwner() public {
        vm.prank(alice);
        token.registerInvestor("US", 0);

        vm.prank(bob);
        vm.expectRevert();
        token.verifyKYC(alice);
    }

    function test_updateWhitelist_toggleStatus() public {
        vm.prank(owner);
        token.updateWhitelist(alice, true);
        assertTrue(token.whitelist(alice));

        vm.prank(owner);
        token.updateWhitelist(alice, false);
        assertFalse(token.whitelist(alice));
    }

    function test_updateWhitelist_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SGMXToken.WhitelistUpdated(alice, true);
        token.updateWhitelist(alice, true);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Share Issuance
    // ─────────────────────────────────────────────────────────────────────────

    function _registerAndKYC(address investor) internal {
        vm.prank(investor);
        token.registerInvestor("US", 0);
        vm.prank(owner);
        token.verifyKYC(investor);
    }

    function test_issueShares_success() public {
        _registerAndKYC(alice);

        uint256 amount = 1_000_000 * 1e18;
        vm.prank(owner);
        token.issueShares(alice, amount, 0, "Initial grant");

        assertEq(token.getInvestor(alice).balance, amount);
        assertEq(token.issuanceCounter(), 1);

        SGMXToken.ShareIssuance memory iss = token.getIssuance(1);
        assertEq(iss.to,         alice);
        assertEq(iss.amount,     amount);
        assertEq(iss.shareClass, 0);
        assertEq(iss.memo,       "Initial grant");
    }

    function test_issueShares_emitsEvent() public {
        _registerAndKYC(alice);

        uint256 amount = 500 * 1e18;
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SGMXToken.SharesIssued(alice, amount, 1, "Preferred");
        token.issueShares(alice, amount, 1, "Preferred");
    }

    function test_issueShares_revertsExceedsSupply() public {
        _registerAndKYC(alice);

        // circulatingSupply is TOTAL_SUPPLY * 20% at init — try to issue TOTAL_SUPPLY remaining + 1
        uint256 remaining = TOTAL_SUPPLY - token.circulatingSupply();
        vm.prank(owner);
        vm.expectRevert("Exceeds supply");
        token.issueShares(alice, remaining + 1, 0, "overflow");
    }

    function test_issueShares_revertsNonOwner() public {
        _registerAndKYC(alice);

        vm.prank(alice);
        vm.expectRevert();
        token.issueShares(alice, 100 * 1e18, 0, "test");
    }

    function test_issueShares_multipleIssuances() public {
        _registerAndKYC(alice);
        _registerAndKYC(bob);

        vm.startPrank(owner);
        token.issueShares(alice, 100 * 1e18, 0, "Alice grant");
        token.issueShares(bob,   200 * 1e18, 1, "Bob grant");
        vm.stopPrank();

        assertEq(token.issuanceCounter(), 2);
        assertEq(token.getInvestor(alice).balance, 100 * 1e18);
        assertEq(token.getInvestor(bob).balance,   200 * 1e18);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Dividends
    // ─────────────────────────────────────────────────────────────────────────

    function test_declareDividend_success() public {
        uint256 perShare = 1e12; // 0.000001 OICD per SGMX
        vm.prank(owner);
        uint256 id = token.declareDividend(perShare);

        assertEq(id, 1);
        SGMXToken.Dividend memory div = token.getDividend(1);
        assertTrue(div.declared);
        assertEq(div.amountPerShare, perShare);
        assertEq(div.totalDistributed, 0);
    }

    function test_declareDividend_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SGMXToken.DividendDeclared(1, 1e12);
        token.declareDividend(1e12);
    }

    function test_declareDividend_revertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.declareDividend(1e12);
    }

    function test_claimDividend_success() public {
        _registerAndKYC(alice);

        uint256 shareAmount = 1_000 * 1e18;
        vm.prank(owner);
        token.issueShares(alice, shareAmount, 0, "Grant");

        uint256 perShare = 1e15;
        vm.prank(owner);
        token.declareDividend(perShare);

        vm.prank(alice);
        token.claimDividend(1);

        uint256 expectedPayout = (shareAmount * perShare) / 1e18;
        assertEq(token.getInvestor(alice).dividendsAccrued, expectedPayout);
        assertTrue(token.dividendClaimed(1, alice));
    }

    function test_claimDividend_revertsDoubleClaim() public {
        _registerAndKYC(alice);
        vm.prank(owner);
        token.issueShares(alice, 1_000 * 1e18, 0, "Grant");
        vm.prank(owner);
        token.declareDividend(1e15);

        vm.prank(alice);
        token.claimDividend(1);

        vm.prank(alice);
        vm.expectRevert("Already claimed");
        token.claimDividend(1);
    }

    function test_claimDividend_revertsNotRegistered() public {
        vm.prank(owner);
        token.declareDividend(1e15);

        vm.prank(alice);
        vm.expectRevert("Not registered");
        token.claimDividend(1);
    }

    function test_claimDividend_revertsZeroPayout() public {
        _registerAndKYC(alice);
        // Alice has zero shares — payout would be 0
        vm.prank(owner);
        token.declareDividend(1e15);

        vm.prank(alice);
        vm.expectRevert("No payout");
        token.claimDividend(1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Corporate Actions
    // ─────────────────────────────────────────────────────────────────────────

    function test_fileCorporateAction_success() public {
        vm.prank(owner);
        uint256 id = token.fileCorporateAction("dividend", "Q1 2026 dividend distribution");

        assertEq(id, 1);
        SGMXToken.CorporateAction memory action = token.getAction(1);
        assertEq(action.actionType,  "dividend");
        assertEq(action.description, "Q1 2026 dividend distribution");
    }

    function test_fileCorporateAction_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit SGMXToken.CorporateActionFiled(1, "stock_split");
        token.fileCorporateAction("stock_split", "2:1 split");
    }

    function test_fileCorporateAction_revertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.fileCorporateAction("merger", "test");
    }

    function test_fileCorporateAction_multipleActions() public {
        vm.startPrank(owner);
        token.fileCorporateAction("dividend",     "Q1 2026");
        token.fileCorporateAction("stock_split",  "2:1");
        token.fileCorporateAction("rights_issue", "New shares");
        vm.stopPrank();

        assertEq(token.actionCounter(), 3);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Transfer Controls
    // ─────────────────────────────────────────────────────────────────────────

    function test_enableTransfers_toggles() public {
        vm.prank(owner);
        token.enableTransfers(true);
        assertTrue(token.transfersEnabled());

        vm.prank(owner);
        token.enableTransfers(false);
        assertFalse(token.transfersEnabled());
    }

    function test_enableTransfers_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit SGMXToken.TransfersToggled(true);
        token.enableTransfers(true);
    }

    function test_enableTransfers_revertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.enableTransfers(true);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Pair Rate Update
    // ─────────────────────────────────────────────────────────────────────────

    function test_updateOICDPairRate_success() public {
        uint256 newRate = 5e14;
        vm.prank(owner);
        token.updateOICDPairRate(newRate);
        assertEq(token.oicdPairRate(), newRate);
    }

    function test_updateOICDPairRate_emitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit SGMXToken.PairRateUpdated(2e14);
        token.updateOICDPairRate(2e14);
    }

    function test_updateOICDPairRate_revertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.updateOICDPairRate(2e14);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Cap Table View
    // ─────────────────────────────────────────────────────────────────────────

    function test_capTable_afterIssuance() public {
        _registerAndKYC(alice);

        uint256 amount = 1_000_000 * 1e18;
        vm.prank(owner);
        token.issueShares(alice, amount, 0, "Grant");

        (, , , uint256 circulating) = token.capTable();
        // circulatingSupply increases by amount issued
        assertEq(circulating, TOTAL_SUPPLY * 20 / 100 + amount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. UUPS Upgrade Authorization
    // ─────────────────────────────────────────────────────────────────────────

    function test_upgradeReverts_nonOwner() public {
        SGMXToken impl2 = new SGMXToken();
        vm.prank(alice);
        vm.expectRevert();
        token.upgradeToAndCall(address(impl2), "");
    }

    function test_upgrade_ownerCanUpgrade() public {
        SGMXToken impl2 = new SGMXToken();
        vm.prank(owner);
        // Should not revert — simply upgrades in place
        token.upgradeToAndCall(address(impl2), "");
    }
}
