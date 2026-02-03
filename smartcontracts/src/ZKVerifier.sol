// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Groth16 ZK-SNARK Verifier for Order Commitments
 * @notice Verifies zero-knowledge proofs for private dark pool orders
 * @dev Based on EIP-197 bn256 pairing precompiles
 *
 * This contract verifies Groth16 proofs generated from the orderCommitment.circom circuit.
 * The verification key values should be updated after running the trusted setup ceremony.
 */
contract ZKVerifier {
    // Scalar field size
    uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // Prime field size
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification key elements (updated after trusted setup)
    // These are placeholder values - replace with actual values from snarkjs export
    struct VerifyingKey {
        uint256[2] alfa1;
        uint256[2][2] beta2;
        uint256[2][2] gamma2;
        uint256[2][2] delta2;
        uint256[2][] IC; // Input commitments
    }

    // Nullifier tracking to prevent double-spend
    mapping(bytes32 => bool) public usedNullifiers;

    // Commitment tracking
    mapping(bytes32 => bool) public verifiedCommitments;

    // Events
    event ProofVerified(bytes32 indexed commitment, bytes32 indexed nullifier, bool success);
    event NullifierUsed(bytes32 indexed nullifier, address indexed user);
    event VerificationKeyUpdated(address indexed updater);

    // Admin for updating verification key
    address public admin;

    // Stored verification key components
    uint256[2] public alfa1;
    uint256[2][2] public beta2;
    uint256[2][2] public gamma2;
    uint256[2][2] public delta2;
    uint256[2][] public IC;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
        _initializeDefaultVerifyingKey();
    }

    /**
     * @notice Initialize with default verification key (placeholder)
     * @dev Replace these values after running trusted setup
     */
    function _initializeDefaultVerifyingKey() internal {
        // Placeholder G1 point for alfa1
        alfa1 = [
            uint256(20491192805390485299153009773594534940189261866228447918068658471970481763042),
            uint256(9383485363053290200918347156157836566562967994039712273449902621266178545958)
        ];

        // Placeholder G2 points for beta2
        beta2 = [
            [uint256(4252822878758300859123897981450591353533073413197771768651442665752259397132),
             uint256(6375614351688725206403948262868962793625744043794305715222011528459656738731)],
            [uint256(21847035105528745403288232691147584728191162732299865338377159692350059136679),
             uint256(10505242626370262277552901082094356697409835680220590971873171140371331206856)]
        ];

        // Placeholder G2 points for gamma2
        gamma2 = [
            [uint256(11559732032986387107991004021392285783925812861821192530917403151452391805634),
             uint256(10857046999023057135944570762232829481370756359578518086990519993285655852781)],
            [uint256(4082367875863433681332203403145435568316851327593401208105741076214120093531),
             uint256(8495653923123431417604973247489272438418190587263600148770280649306958101930)]
        ];

        // Placeholder G2 points for delta2
        delta2 = [
            [uint256(11559732032986387107991004021392285783925812861821192530917403151452391805634),
             uint256(10857046999023057135944570762232829481370756359578518086990519993285655852781)],
            [uint256(4082367875863433681332203403145435568316851327593401208105741076214120093531),
             uint256(8495653923123431417604973247489272438418190587263600148770280649306958101930)]
        ];

        // IC points (2 public inputs: commitment, nullifier)
        IC.push([
            uint256(7635028661032814464951820568296385240248298008795962754765891813513201203143),
            uint256(20797048629585950586496815952351265116000279826085400091328367744839776584193)
        ]);
        IC.push([
            uint256(14823367009093563390917954116780483312691803648362147530418168959872940766130),
            uint256(9976195665997820896897498831094945341834727659977953148926737314584265348803)
        ]);
        IC.push([
            uint256(18388955683569265660323663597135832766455900611661950544820920684061605586684),
            uint256(4481808839602375982756609994745858883889609288385178088820534400666831823073)
        ]);
    }

    /**
     * @notice Update verification key after trusted setup
     * @param _alfa1 G1 point
     * @param _beta2 G2 point
     * @param _gamma2 G2 point
     * @param _delta2 G2 point
     * @param _IC Input commitment points
     */
    function updateVerifyingKey(
        uint256[2] calldata _alfa1,
        uint256[2][2] calldata _beta2,
        uint256[2][2] calldata _gamma2,
        uint256[2][2] calldata _delta2,
        uint256[2][] calldata _IC
    ) external onlyAdmin {
        alfa1 = _alfa1;
        beta2 = _beta2;
        gamma2 = _gamma2;
        delta2 = _delta2;

        delete IC;
        for (uint256 i = 0; i < _IC.length; i++) {
            IC.push(_IC[i]);
        }

        emit VerificationKeyUpdated(msg.sender);
    }

    /**
     * @notice Verify a Groth16 proof
     * @param a Proof element A (G1 point)
     * @param b Proof element B (G2 point)
     * @param c Proof element C (G1 point)
     * @param publicInputs Public inputs [commitment, nullifier]
     * @return True if proof is valid
     */
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory publicInputs
    ) public returns (bool) {
        require(publicInputs.length == 2, "Invalid public inputs length");

        // Extract commitment and nullifier from public inputs
        bytes32 commitment = bytes32(publicInputs[0]);
        bytes32 nullifier = bytes32(publicInputs[1]);

        // Check nullifier hasn't been used (prevent double-spend)
        require(!usedNullifiers[nullifier], "Nullifier already used");

        // Validate inputs are within the field
        require(a[0] < PRIME_Q && a[1] < PRIME_Q, "Invalid proof point a");
        require(b[0][0] < PRIME_Q && b[0][1] < PRIME_Q, "Invalid proof point b[0]");
        require(b[1][0] < PRIME_Q && b[1][1] < PRIME_Q, "Invalid proof point b[1]");
        require(c[0] < PRIME_Q && c[1] < PRIME_Q, "Invalid proof point c");

        for (uint256 i = 0; i < publicInputs.length; i++) {
            require(publicInputs[i] < SNARK_SCALAR_FIELD, "Public input exceeds scalar field");
        }

        // Compute the linear combination for public inputs
        // vk_x = IC[0] + publicInputs[0] * IC[1] + publicInputs[1] * IC[2] + ...
        uint256[2] memory vk_x = IC[0];

        for (uint256 i = 0; i < publicInputs.length; i++) {
            uint256[2] memory mulResult = _scalarMul(IC[i + 1], publicInputs[i]);
            vk_x = _pointAdd(vk_x, mulResult);
        }

        // Verify the pairing equation:
        // e(A, B) = e(alfa1, beta2) * e(vk_x, gamma2) * e(C, delta2)
        // Rearranged as: e(-A, B) * e(alfa1, beta2) * e(vk_x, gamma2) * e(C, delta2) = 1
        bool success = _pairingCheck(
            _negate(a),
            b,
            alfa1,
            beta2,
            vk_x,
            gamma2,
            c,
            delta2
        );

        if (success) {
            // Mark nullifier as used
            usedNullifiers[nullifier] = true;
            verifiedCommitments[commitment] = true;

            emit ProofVerified(commitment, nullifier, true);
            emit NullifierUsed(nullifier, msg.sender);
        } else {
            emit ProofVerified(commitment, nullifier, false);
        }

        return success;
    }

    /**
     * @notice Verify proof without consuming nullifier (view function for testing)
     */
    function verifyProofView(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[] memory publicInputs
    ) public view returns (bool) {
        require(publicInputs.length == 2, "Invalid public inputs length");

        bytes32 nullifier = bytes32(publicInputs[1]);
        if (usedNullifiers[nullifier]) {
            return false;
        }

        // Validate inputs
        if (a[0] >= PRIME_Q || a[1] >= PRIME_Q) return false;
        if (b[0][0] >= PRIME_Q || b[0][1] >= PRIME_Q) return false;
        if (b[1][0] >= PRIME_Q || b[1][1] >= PRIME_Q) return false;
        if (c[0] >= PRIME_Q || c[1] >= PRIME_Q) return false;

        for (uint256 i = 0; i < publicInputs.length; i++) {
            if (publicInputs[i] >= SNARK_SCALAR_FIELD) return false;
        }

        // Compute vk_x
        uint256[2] memory vk_x = IC[0];
        for (uint256 i = 0; i < publicInputs.length; i++) {
            uint256[2] memory mulResult = _scalarMul(IC[i + 1], publicInputs[i]);
            vk_x = _pointAdd(vk_x, mulResult);
        }

        return _pairingCheck(
            _negate(a),
            b,
            alfa1,
            beta2,
            vk_x,
            gamma2,
            c,
            delta2
        );
    }

    /**
     * @notice Check if a commitment has been verified
     */
    function isCommitmentVerified(bytes32 commitment) external view returns (bool) {
        return verifiedCommitments[commitment];
    }

    /**
     * @notice Check if a nullifier has been used
     */
    function isNullifierUsed(bytes32 nullifier) external view returns (bool) {
        return usedNullifiers[nullifier];
    }

    /**
     * @notice Negate a G1 point (used in pairing check)
     */
    function _negate(uint256[2] memory p) internal pure returns (uint256[2] memory) {
        if (p[0] == 0 && p[1] == 0) {
            return p;
        }
        return [p[0], PRIME_Q - (p[1] % PRIME_Q)];
    }

    /**
     * @notice Add two G1 points using precompile
     */
    function _pointAdd(uint256[2] memory p1, uint256[2] memory p2) internal view returns (uint256[2] memory r) {
        uint256[4] memory input;
        input[0] = p1[0];
        input[1] = p1[1];
        input[2] = p2[0];
        input[3] = p2[1];

        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0x80, r, 0x40)
        }
        require(success, "Point addition failed");
    }

    /**
     * @notice Scalar multiplication on G1 using precompile
     */
    function _scalarMul(uint256[2] memory p, uint256 s) internal view returns (uint256[2] memory r) {
        uint256[3] memory input;
        input[0] = p[0];
        input[1] = p[1];
        input[2] = s;

        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x60, r, 0x40)
        }
        require(success, "Scalar multiplication failed");
    }

    /**
     * @notice Perform pairing check using precompile (EIP-197)
     * @dev Checks: e(-A, B) * e(alfa1, beta2) * e(vk_x, gamma2) * e(C, delta2) == 1
     */
    function _pairingCheck(
        uint256[2] memory a1,
        uint256[2][2] memory b1,
        uint256[2] memory a2,
        uint256[2][2] memory b2,
        uint256[2] memory a3,
        uint256[2][2] memory b3,
        uint256[2] memory a4,
        uint256[2][2] memory b4
    ) internal view returns (bool) {
        uint256[24] memory input;

        // Pair 1: (-A, B)
        input[0] = a1[0];
        input[1] = a1[1];
        input[2] = b1[0][1]; // Note: G2 point ordering for precompile
        input[3] = b1[0][0];
        input[4] = b1[1][1];
        input[5] = b1[1][0];

        // Pair 2: (alfa1, beta2)
        input[6] = a2[0];
        input[7] = a2[1];
        input[8] = b2[0][1];
        input[9] = b2[0][0];
        input[10] = b2[1][1];
        input[11] = b2[1][0];

        // Pair 3: (vk_x, gamma2)
        input[12] = a3[0];
        input[13] = a3[1];
        input[14] = b3[0][1];
        input[15] = b3[0][0];
        input[16] = b3[1][1];
        input[17] = b3[1][0];

        // Pair 4: (C, delta2)
        input[18] = a4[0];
        input[19] = a4[1];
        input[20] = b4[0][1];
        input[21] = b4[0][0];
        input[22] = b4[1][1];
        input[23] = b4[1][0];

        uint256[1] memory result;
        bool success;

        assembly {
            success := staticcall(sub(gas(), 2000), 8, input, 768, result, 0x20)
        }

        require(success, "Pairing check failed");
        return result[0] == 1;
    }

    /**
     * @notice Transfer admin role
     */
    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        admin = newAdmin;
    }
}
