pragma circom 2.1.6;

include "node_modules/circomlib/circuits/poseidon.circom";

/**
 * @title OrderCommitment
 * @notice ZK-SNARK circuit for private dark pool order commitments
 * @dev Proves knowledge of order details without revealing them on-chain
 *
 * Private inputs (known only to prover):
 *   - salt: Random value for commitment uniqueness
 *   - amount: Order amount
 *   - price: Order price
 *   - side: 0 = Buy, 1 = Sell
 *   - tokenId: Token identifier
 *   - trader: Trader address (as field element)
 *
 * Public inputs (visible on-chain):
 *   - commitment: Poseidon hash of all private inputs
 *   - nullifier: Unique identifier to prevent double-spending
 */
template OrderCommitment() {
    // Private inputs
    signal input salt;
    signal input amount;
    signal input price;
    signal input side;
    signal input tokenId;
    signal input trader;

    // Public outputs
    signal output commitment;
    signal output nullifier;

    // Validate side is binary (0 or 1)
    signal sideSquared;
    sideSquared <== side * side;
    side * (side - 1) === 0;

    // Validate amount and price are positive (non-zero check via inverse)
    signal amountInv;
    amountInv <-- 1 / amount;
    amountInv * amount === 1;

    signal priceInv;
    priceInv <-- 1 / price;
    priceInv * price === 1;

    // Compute commitment using Poseidon hash (6 inputs)
    component hasher = Poseidon(6);
    hasher.inputs[0] <== salt;
    hasher.inputs[1] <== amount;
    hasher.inputs[2] <== price;
    hasher.inputs[3] <== side;
    hasher.inputs[4] <== tokenId;
    hasher.inputs[5] <== trader;

    commitment <== hasher.out;

    // Compute nullifier (hash of salt + trader) to prevent replay attacks
    component nullifierHasher = Poseidon(2);
    nullifierHasher.inputs[0] <== salt;
    nullifierHasher.inputs[1] <== trader;

    nullifier <== nullifierHasher.out;
}

component main {public [commitment, nullifier]} = OrderCommitment();
