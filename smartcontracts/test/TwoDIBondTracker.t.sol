// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/TwoDIBondTracker.sol";

contract TwoDIBondTrackerTest is Test {
    TwoDIBondTracker public tracker;

    address public admin   = address(1);
    address public issuer  = address(2);
    address public alice   = address(3);
    address public bob     = address(4);
    address public charlie = address(5);

    uint256 constant MIN_BOND_AMOUNT = 1000 * 1e18;

    // ─────────────────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────────────────

    function setUp() public {
        TwoDIBondTracker impl = new TwoDIBondTracker();
        bytes memory initData = abi.encodeCall(
            TwoDIBondTracker.initialize,
            (admin, "https://bonds.oicd.io/{id}")
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        tracker = TwoDIBondTracker(address(proxy));

        // Grant issuer role from admin
        bytes32 issuerRole = tracker.ISSUER_ROLE();
        vm.prank(admin);
        tracker.grantRole(issuerRole, issuer);

        // Fund accounts with ETH for coupon payments and redemptions
        vm.deal(alice,   100_000 ether);
        vm.deal(bob,     100_000 ether);
        vm.deal(charlie, 100_000 ether);
        vm.deal(issuer,  100_000 ether);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Issue a standard bond via the issuer account.
    function _issueBond(
        uint256 totalSupply_,
        uint256 faceValue_,
        uint256 couponRate_,
        uint256 maturityOffset_    // seconds from now
    ) internal returns (uint256 bondId) {
        TwoDIBondTracker.BondParams memory p = TwoDIBondTracker.BondParams({
            bondType:       TwoDIBondTracker.BondType.StandardBond,
            projectName:    "OZF Infrastructure Bond",
            country:        "OZF",
            totalSupply:    totalSupply_,
            faceValue:      faceValue_,
            couponRate:     couponRate_,
            maturityDate:   block.timestamp + maturityOffset_,
            couponFrequency: 30 days
        });

        vm.prank(issuer);
        bondId = tracker.issueBond(p);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Initialization
    // ─────────────────────────────────────────────────────────────────────────

    function test_initialize_rolesGranted() public view {
        assertTrue(tracker.hasRole(tracker.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(tracker.hasRole(tracker.ADMIN_ROLE(),         admin));
        assertTrue(tracker.hasRole(tracker.ISSUER_ROLE(),        admin));
        assertTrue(tracker.hasRole(tracker.UPGRADER_ROLE(),      admin));
    }

    function test_initialize_bondCounterZero() public view {
        assertEq(tracker.bondCounter(), 0);
    }

    function test_initialize_constants() public view {
        assertEq(tracker.BASIS_POINTS(),    10000);
        assertEq(tracker.MIN_BOND_AMOUNT(), MIN_BOND_AMOUNT);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Bond Issuance
    // ─────────────────────────────────────────────────────────────────────────

    function test_issueBond_success() public {
        uint256 supply   = MIN_BOND_AMOUNT * 10;
        uint256 face     = 1 ether;
        uint256 coupon   = 500; // 5%
        uint256 maturity = 365 days;

        uint256 bondId = _issueBond(supply, face, coupon, maturity);

        assertEq(bondId, 1);
        assertEq(tracker.bondCounter(), 1);

        (
            uint256 id,
            TwoDIBondTracker.BondType bondType,
            address iss,
            string memory projectName,
            string memory country,
            uint256 totalSupply_,
            uint256 faceValue,
            uint256 couponRate,
            ,
            ,
            ,
            TwoDIBondTracker.BondStatus status,
        ) = tracker.bonds(1);

        assertEq(id,          1);
        assertEq(uint8(bondType), uint8(TwoDIBondTracker.BondType.StandardBond));
        assertEq(iss,         issuer);
        assertEq(projectName, "OZF Infrastructure Bond");
        assertEq(country,     "OZF");
        assertEq(totalSupply_, supply);
        assertEq(faceValue,   face);
        assertEq(couponRate,  coupon);
        assertEq(uint8(status), uint8(TwoDIBondTracker.BondStatus.Active));
    }

    function test_issueBond_mintsERC1155() public {
        uint256 supply = MIN_BOND_AMOUNT * 5;
        uint256 bondId = _issueBond(supply, 1 ether, 300, 365 days);

        assertEq(tracker.balanceOf(issuer, bondId), supply);
    }

    function test_issueBond_emitsEvent() public {
        uint256 supply = MIN_BOND_AMOUNT * 2;

        TwoDIBondTracker.BondParams memory p = TwoDIBondTracker.BondParams({
            bondType:       TwoDIBondTracker.BondType.GreenBond,
            projectName:    "Green Bond",
            country:        "OZF",
            totalSupply:    supply,
            faceValue:      1 ether,
            couponRate:     400,
            maturityDate:   block.timestamp + 365 days,
            couponFrequency: 30 days
        });

        vm.prank(issuer);
        vm.expectEmit(true, true, false, true);
        emit TwoDIBondTracker.BondIssued(1, issuer, TwoDIBondTracker.BondType.GreenBond, supply);
        tracker.issueBond(p);
    }

    function test_issueBond_revertsSupplyTooLow() public {
        TwoDIBondTracker.BondParams memory p = TwoDIBondTracker.BondParams({
            bondType:        TwoDIBondTracker.BondType.StandardBond,
            projectName:     "Low Supply",
            country:         "OZF",
            totalSupply:     MIN_BOND_AMOUNT - 1, // one below minimum
            faceValue:       1 ether,
            couponRate:      100,
            maturityDate:    block.timestamp + 365 days,
            couponFrequency: 30 days
        });

        vm.prank(issuer);
        vm.expectRevert("Supply too low");
        tracker.issueBond(p);
    }

    function test_issueBond_revertsInvalidMaturity() public {
        TwoDIBondTracker.BondParams memory p = TwoDIBondTracker.BondParams({
            bondType:        TwoDIBondTracker.BondType.StandardBond,
            projectName:     "Past Maturity",
            country:         "OZF",
            totalSupply:     MIN_BOND_AMOUNT,
            faceValue:       1 ether,
            couponRate:      100,
            maturityDate:    block.timestamp - 1, // in the past
            couponFrequency: 30 days
        });

        vm.prank(issuer);
        vm.expectRevert("Invalid maturity");
        tracker.issueBond(p);
    }

    function test_issueBond_revertsCouponRateTooHigh() public {
        TwoDIBondTracker.BondParams memory p = TwoDIBondTracker.BondParams({
            bondType:        TwoDIBondTracker.BondType.StandardBond,
            projectName:     "High Coupon",
            country:         "OZF",
            totalSupply:     MIN_BOND_AMOUNT,
            faceValue:       1 ether,
            couponRate:      2001, // above 2000 max (20%)
            maturityDate:    block.timestamp + 365 days,
            couponFrequency: 30 days
        });

        vm.prank(issuer);
        vm.expectRevert("Coupon rate too high");
        tracker.issueBond(p);
    }

    function test_issueBond_revertsNonIssuer() public {
        TwoDIBondTracker.BondParams memory p = TwoDIBondTracker.BondParams({
            bondType:        TwoDIBondTracker.BondType.StandardBond,
            projectName:     "Unauthorized",
            country:         "OZF",
            totalSupply:     MIN_BOND_AMOUNT,
            faceValue:       1 ether,
            couponRate:      100,
            maturityDate:    block.timestamp + 365 days,
            couponFrequency: 30 days
        });

        vm.prank(alice);
        vm.expectRevert();
        tracker.issueBond(p);
    }

    function test_issueBond_multipleBondTypes() public {
        TwoDIBondTracker.BondType[5] memory types = [
            TwoDIBondTracker.BondType.StandardBond,
            TwoDIBondTracker.BondType.GreenBond,
            TwoDIBondTracker.BondType.SocialBond,
            TwoDIBondTracker.BondType.SustainabilityBond,
            TwoDIBondTracker.BondType.HybridBond
        ];

        for (uint256 i = 0; i < types.length; i++) {
            TwoDIBondTracker.BondParams memory p = TwoDIBondTracker.BondParams({
                bondType:        types[i],
                projectName:     "Bond",
                country:         "OZF",
                totalSupply:     MIN_BOND_AMOUNT,
                faceValue:       1 ether,
                couponRate:      200,
                maturityDate:    block.timestamp + 365 days,
                couponFrequency: 30 days
            });

            vm.prank(issuer);
            uint256 id = tracker.issueBond(p);
            assertEq(id, i + 1);
        }

        assertEq(tracker.bondCounter(), 5);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Coupon Payments
    // ─────────────────────────────────────────────────────────────────────────

    function test_payCoupon_revertsBeforeInterval() public {
        uint256 bondId = _issueBond(MIN_BOND_AMOUNT * 10, 1 ether, 500, 365 days);

        // Transfer some bonds to alice so there is a holder
        vm.prank(issuer);
        tracker.safeTransferFrom(issuer, alice, bondId, MIN_BOND_AMOUNT, "");

        // Advance only 15 days — too early (needs 30)
        vm.warp(block.timestamp + 15 days);

        uint256 couponNeeded = (MIN_BOND_AMOUNT * 10 * 500) / 10000;
        vm.prank(alice);
        vm.expectRevert("Too early");
        tracker.payCoupon{value: couponNeeded}(bondId);
    }

    function test_payCoupon_revertsInsufficientPayment() public {
        uint256 supply   = MIN_BOND_AMOUNT * 10;
        uint256 coupon   = 500; // 5%
        uint256 bondId   = _issueBond(supply, 1 ether, coupon, 365 days);

        vm.warp(block.timestamp + 31 days);

        uint256 couponNeeded = (supply * coupon) / 10000;

        vm.prank(alice);
        vm.expectRevert("Insufficient payment");
        tracker.payCoupon{value: couponNeeded - 1}(bondId);
    }

    function test_payCoupon_revertsNonExistentBond() public {
        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        vm.expectRevert("Bond does not exist");
        tracker.payCoupon{value: 1 ether}(999);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Bond Redemption at Maturity
    // ─────────────────────────────────────────────────────────────────────────

    function test_redeemAtMaturity_success() public {
        uint256 supply    = MIN_BOND_AMOUNT;
        uint256 faceValue = 10 ether;
        uint256 maturity  = 30 days;

        uint256 bondId = _issueBond(supply, faceValue, 200, maturity);

        // Fund the contract so it can pay out on redemption
        vm.deal(address(tracker), faceValue + 1 ether);

        // Transfer the entire supply to issuer (already the issuer)
        // Advance past maturity
        vm.warp(block.timestamp + maturity + 1);

        uint256 balBefore = issuer.balance;
        vm.prank(issuer);
        tracker.redeemAtMaturity(bondId);

        // Issuer receives faceValue (they held all bonds)
        assertGt(issuer.balance, balBefore);
        // Bond status should be Matured
        (, , , , , , , , , , , TwoDIBondTracker.BondStatus status, ) = tracker.bonds(bondId);
        assertEq(uint8(status), uint8(TwoDIBondTracker.BondStatus.Matured));
    }

    function test_redeemAtMaturity_revertsBeforeMaturity() public {
        uint256 bondId = _issueBond(MIN_BOND_AMOUNT, 5 ether, 300, 365 days);

        vm.prank(issuer);
        vm.expectRevert("Not matured");
        tracker.redeemAtMaturity(bondId);
    }

    function test_redeemAtMaturity_revertsNoHoldings() public {
        uint256 bondId = _issueBond(MIN_BOND_AMOUNT, 5 ether, 300, 30 days);
        vm.warp(block.timestamp + 31 days);

        // alice has no holdings
        vm.prank(alice);
        vm.expectRevert("No holdings");
        tracker.redeemAtMaturity(bondId);
    }

    function test_redeemAtMaturity_revertsNonExistentBond() public {
        vm.warp(block.timestamp + 365 days + 1);
        vm.prank(alice);
        vm.expectRevert("Bond does not exist");
        tracker.redeemAtMaturity(999);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. ERC1155 Transfers
    // ─────────────────────────────────────────────────────────────────────────

    function test_transferBond_updatesBalance() public {
        uint256 supply = MIN_BOND_AMOUNT * 4;
        uint256 bondId = _issueBond(supply, 1 ether, 200, 365 days);

        uint256 transferAmount = MIN_BOND_AMOUNT;

        vm.prank(issuer);
        tracker.safeTransferFrom(issuer, alice, bondId, transferAmount, "");

        assertEq(tracker.balanceOf(issuer, bondId), supply - transferAmount);
        assertEq(tracker.balanceOf(alice,  bondId), transferAmount);
    }

    function test_batchTransferBond() public {
        uint256 supply1 = MIN_BOND_AMOUNT * 2;
        uint256 supply2 = MIN_BOND_AMOUNT * 3;

        uint256 bondId1 = _issueBond(supply1, 1 ether, 100, 365 days);
        uint256 bondId2 = _issueBond(supply2, 2 ether, 200, 365 days);

        uint256[] memory ids     = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = bondId1; ids[1] = bondId2;
        amounts[0] = MIN_BOND_AMOUNT; amounts[1] = MIN_BOND_AMOUNT;

        vm.prank(issuer);
        tracker.safeBatchTransferFrom(issuer, alice, ids, amounts, "");

        assertEq(tracker.balanceOf(alice, bondId1), MIN_BOND_AMOUNT);
        assertEq(tracker.balanceOf(alice, bondId2), MIN_BOND_AMOUNT);
    }

    function test_transferBond_revertsInsufficientBalance() public {
        uint256 supply = MIN_BOND_AMOUNT;
        uint256 bondId = _issueBond(supply, 1 ether, 200, 365 days);

        vm.prank(alice);
        vm.expectRevert();
        tracker.safeTransferFrom(alice, bob, bondId, MIN_BOND_AMOUNT, "");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Bond Holdings Mapping
    // ─────────────────────────────────────────────────────────────────────────

    function test_bondHoldings_setOnIssuance() public {
        uint256 supply = MIN_BOND_AMOUNT * 5;
        uint256 bondId = _issueBond(supply, 1 ether, 200, 365 days);

        assertEq(tracker.bondHoldings(bondId, issuer), supply);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Pause / Unpause
    // ─────────────────────────────────────────────────────────────────────────

    function test_pause_onlyAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        tracker.pause();
    }

    function test_pauseAndUnpause() public {
        vm.prank(admin);
        tracker.pause();
        assertTrue(tracker.paused());

        vm.prank(admin);
        tracker.unpause();
        assertFalse(tracker.paused());
    }

    function test_issueBond_revertsWhenPaused() public {
        vm.prank(admin);
        tracker.pause();

        TwoDIBondTracker.BondParams memory p = TwoDIBondTracker.BondParams({
            bondType:        TwoDIBondTracker.BondType.StandardBond,
            projectName:     "Paused Bond",
            country:         "OZF",
            totalSupply:     MIN_BOND_AMOUNT,
            faceValue:       1 ether,
            couponRate:      200,
            maturityDate:    block.timestamp + 365 days,
            couponFrequency: 30 days
        });

        vm.prank(issuer);
        vm.expectRevert();
        tracker.issueBond(p);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. supportsInterface
    // ─────────────────────────────────────────────────────────────────────────

    function test_supportsInterface_ERC1155() public view {
        // ERC1155 interface ID
        assertTrue(tracker.supportsInterface(0xd9b67a26));
    }

    function test_supportsInterface_AccessControl() public view {
        // AccessControl interface ID
        assertTrue(tracker.supportsInterface(0x7965db0b));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. UUPS Upgrade Authorization
    // ─────────────────────────────────────────────────────────────────────────

    function test_upgradeReverts_nonUpgrader() public {
        TwoDIBondTracker impl2 = new TwoDIBondTracker();
        vm.prank(alice);
        vm.expectRevert();
        tracker.upgradeToAndCall(address(impl2), "");
    }

    function test_upgrade_upgraderCanUpgrade() public {
        TwoDIBondTracker impl2 = new TwoDIBondTracker();
        vm.prank(admin);
        tracker.upgradeToAndCall(address(impl2), "");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Bond Counter Increments
    // ─────────────────────────────────────────────────────────────────────────

    function test_bondCounter_incrementsPerIssuance() public {
        assertEq(tracker.bondCounter(), 0);
        _issueBond(MIN_BOND_AMOUNT, 1 ether, 100, 365 days);
        assertEq(tracker.bondCounter(), 1);
        _issueBond(MIN_BOND_AMOUNT, 2 ether, 200, 365 days);
        assertEq(tracker.bondCounter(), 2);
        _issueBond(MIN_BOND_AMOUNT, 3 ether, 300, 365 days);
        assertEq(tracker.bondCounter(), 3);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Edge: coupon at exact 30-day boundary
    // ─────────────────────────────────────────────────────────────────────────

    function test_payCoupon_atExact30DayBoundary() public {
        uint256 supply  = MIN_BOND_AMOUNT;
        uint256 coupon  = 500; // 5%
        uint256 bondId  = _issueBond(supply, 1 ether, coupon, 365 days);

        // issuer holds all bonds — need at least one holder tracked
        vm.warp(block.timestamp + 30 days);

        uint256 couponAmount = (supply * coupon) / 10000;

        vm.prank(issuer);
        vm.expectEmit(true, false, false, true);
        emit TwoDIBondTracker.CouponPaid(bondId, couponAmount);
        tracker.payCoupon{value: couponAmount}(bondId);
    }
}
