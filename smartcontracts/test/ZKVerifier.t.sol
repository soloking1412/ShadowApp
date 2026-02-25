// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ZKVerifier.sol";

contract ZKVerifierTest is Test {
    ZKVerifier verifier;

    address admin   = address(1);
    address user    = address(2);
    address other   = address(3);

    // Dummy proof values (any uint256 < PRIME_Q works in devMode)
    uint256 constant PQ = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    uint256[2]      dummyA   = [uint256(1), uint256(2)];
    uint256[2][2]   dummyB   = [[uint256(1), uint256(2)], [uint256(3), uint256(4)]];
    uint256[2]      dummyC   = [uint256(5), uint256(6)];

    function setUp() public {
        vm.prank(admin);
        verifier = new ZKVerifier();
    }

    // ─── Initialization ───────────────────────────────────────────────────────

    function test_admin_set() public view {
        assertEq(verifier.admin(), admin);
    }

    function test_devMode_enabled_by_default() public view {
        assertTrue(verifier.devMode());
    }

    function test_IC_initialized() public view {
        // IC is uint256[2][] — getter takes (outerIndex, innerIndex) and returns uint256
        uint256 ic0_x = verifier.IC(0, 0);
        assertGt(ic0_x, 0);
    }

    // ─── Dev Mode ────────────────────────────────────────────────────────────

    function test_setDevMode_off() public {
        vm.prank(admin);
        verifier.setDevMode(false);
        assertFalse(verifier.devMode());
    }

    function test_setDevMode_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ZKVerifier.DevModeChanged(false);
        verifier.setDevMode(false);
    }

    function test_setDevMode_onlyAdmin() public {
        vm.prank(other);
        vm.expectRevert("Only admin");
        verifier.setDevMode(false);
    }

    // ─── verifyProof in devMode ───────────────────────────────────────────────

    function test_verifyProof_devMode_succeeds() public {
        uint256[] memory inputs = new uint256[](2);
        inputs[0] = uint256(keccak256("commitment1")) % PQ;
        inputs[1] = uint256(keccak256("nullifier1"))  % PQ;

        vm.prank(user);
        bool ok = verifier.verifyProof(dummyA, dummyB, dummyC, inputs);
        assertTrue(ok);
    }

    function test_verifyProof_devMode_setsNullifier() public {
        uint256[] memory inputs = new uint256[](2);
        inputs[0] = uint256(keccak256("commitment2")) % PQ;
        inputs[1] = uint256(keccak256("nullifier2"))  % PQ;

        verifier.verifyProof(dummyA, dummyB, dummyC, inputs);

        bytes32 nullifier = bytes32(inputs[1]);
        assertTrue(verifier.usedNullifiers(nullifier));
    }

    function test_verifyProof_devMode_setsCommitment() public {
        uint256[] memory inputs = new uint256[](2);
        inputs[0] = uint256(keccak256("commitment3")) % PQ;
        inputs[1] = uint256(keccak256("nullifier3"))  % PQ;

        verifier.verifyProof(dummyA, dummyB, dummyC, inputs);

        bytes32 commitment = bytes32(inputs[0]);
        assertTrue(verifier.verifiedCommitments(commitment));
    }

    function test_verifyProof_reusedNullifier_reverts() public {
        uint256[] memory inputs = new uint256[](2);
        inputs[0] = uint256(keccak256("commitment4")) % PQ;
        inputs[1] = uint256(keccak256("nullifier4"))  % PQ;

        verifier.verifyProof(dummyA, dummyB, dummyC, inputs);

        // Second attempt with same nullifier should revert
        vm.expectRevert("Nullifier already used");
        verifier.verifyProof(dummyA, dummyB, dummyC, inputs);
    }

    function test_verifyProof_wrongPublicInputsLength_reverts() public {
        uint256[] memory inputs = new uint256[](1); // needs exactly 2
        inputs[0] = 1234;

        vm.expectRevert("Invalid public inputs length");
        verifier.verifyProof(dummyA, dummyB, dummyC, inputs);
    }

    // ─── adminVerifyCommitment ────────────────────────────────────────────────

    function test_adminVerify_success() public {
        bytes32 commitment = keccak256("admin-commitment");
        bytes32 nullifier  = keccak256("admin-nullifier");

        vm.prank(admin);
        verifier.adminVerifyCommitment(commitment, nullifier);

        assertTrue(verifier.verifiedCommitments(commitment));
        assertTrue(verifier.usedNullifiers(nullifier));
    }

    function test_adminVerify_emitsEvents() public {
        bytes32 commitment = keccak256("ev-commitment");
        bytes32 nullifier  = keccak256("ev-nullifier");

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit ZKVerifier.CommitmentAdminVerified(commitment, nullifier);
        verifier.adminVerifyCommitment(commitment, nullifier);
    }

    function test_adminVerify_duplicateNullifier_reverts() public {
        bytes32 commitment = keccak256("dup-commitment");
        bytes32 nullifier  = keccak256("dup-nullifier");

        vm.startPrank(admin);
        verifier.adminVerifyCommitment(commitment, nullifier);
        vm.expectRevert("Nullifier already used");
        verifier.adminVerifyCommitment(commitment, nullifier);
        vm.stopPrank();
    }

    function test_adminVerify_onlyAdmin() public {
        vm.prank(other);
        vm.expectRevert("Only admin");
        verifier.adminVerifyCommitment(keccak256("c"), keccak256("n"));
    }

    // ─── View helpers ─────────────────────────────────────────────────────────

    function test_isCommitmentVerified_false_initially() public view {
        assertFalse(verifier.isCommitmentVerified(keccak256("none")));
    }

    function test_isNullifierUsed_false_initially() public view {
        assertFalse(verifier.isNullifierUsed(keccak256("none")));
    }

    function test_isCommitmentVerified_true_after_verify() public {
        bytes32 commitment = keccak256("chk-c");
        bytes32 nullifier  = keccak256("chk-n");
        vm.prank(admin);
        verifier.adminVerifyCommitment(commitment, nullifier);
        assertTrue(verifier.isCommitmentVerified(commitment));
    }

    // ─── Admin transfer ───────────────────────────────────────────────────────

    function test_transferAdmin() public {
        vm.prank(admin);
        verifier.transferAdmin(other);
        assertEq(verifier.admin(), other);
    }

    function test_transferAdmin_zeroAddress_reverts() public {
        vm.prank(admin);
        vm.expectRevert("Invalid address");
        verifier.transferAdmin(address(0));
    }

    function test_transferAdmin_onlyAdmin() public {
        vm.prank(other);
        vm.expectRevert("Only admin");
        verifier.transferAdmin(user);
    }

    // ─── updateVerifyingKey ───────────────────────────────────────────────────

    function test_updateVerifyingKey_onlyAdmin() public {
        uint256[2] memory a = [uint256(1), uint256(2)];
        uint256[2][2] memory b = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2][] memory ic = new uint256[2][](1);
        ic[0] = [uint256(7), uint256(8)];

        vm.prank(other);
        vm.expectRevert("Only admin");
        verifier.updateVerifyingKey(a, b, b, b, ic);
    }

    function test_updateVerifyingKey_updatesAlfa1() public {
        uint256[2] memory newAlfa = [uint256(999), uint256(888)];
        uint256[2][2] memory b = [[uint256(1), uint256(2)], [uint256(3), uint256(4)]];
        uint256[2][] memory ic = new uint256[2][](1);
        ic[0] = [uint256(1), uint256(2)];

        vm.prank(admin);
        verifier.updateVerifyingKey(newAlfa, b, b, b, ic);

        // alfa1 is a public uint256[2] — getter takes an index and returns uint256
        uint256 ax = verifier.alfa1(0);
        assertEq(ax, 999);
    }

    function test_updateVerifyingKey_emitsEvent() public {
        uint256[2] memory a = [uint256(1), uint256(2)];
        uint256[2][2] memory b = [[uint256(1), uint256(2)], [uint256(3), uint256(4)]];
        uint256[2][] memory ic = new uint256[2][](1);
        ic[0] = [uint256(1), uint256(2)];

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ZKVerifier.VerificationKeyUpdated(admin);
        verifier.updateVerifyingKey(a, b, b, b, ic);
    }
}
