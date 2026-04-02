pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/switcher.circom";

/*
 * MerkleProof
 *
 * Proves membership of a leaf in a Merkle tree with a known root,
 * without revealing the leaf value or its position.
 *
 * A Merkle proof consists of:
 *   - The leaf value (private)
 *   - The sibling hashes along the path from leaf to root (private)
 *   - Direction bits indicating left/right at each level (private)
 *   - The root (public)
 *
 * We use Poseidon hash — a ZK-friendly hash function with ~8x fewer
 * constraints than SHA256/Keccak inside a circuit.
 *
 * Inputs:
 *   leaf              - private: the leaf value
 *   pathElements[k]   - private: sibling nodes along the path
 *   pathIndices[k]    - private: 0 if current node is left child, 1 if right
 *   root              - public: the expected Merkle root
 *
 * Parameters:
 *   k - depth of the tree (tree has 2^k leaves)
 */
template MerkleProof(k) {
    signal input leaf;
    signal input pathElements[k];
    signal input pathIndices[k];   // 0 = current is left, 1 = current is right
    signal input root;

    // Compute the leaf hash: H(leaf)
    component leafHasher = Poseidon(1);
    leafHasher.inputs[0] <== leaf;

    signal levelHashes[k + 1];
    levelHashes[0] <== leafHasher.out;

    component hashers[k];
    component switchers[k];

    for (var i = 0; i < k; i++) {
        // pathIndices[i] must be boolean
        pathIndices[i] * (1 - pathIndices[i]) === 0;

        // Switcher: if pathIndices[i] == 0, (left=current, right=sibling)
        //           if pathIndices[i] == 1, (left=sibling, right=current)
        switchers[i] = Switcher();
        switchers[i].sel <== pathIndices[i];
        switchers[i].L <== levelHashes[i];
        switchers[i].R <== pathElements[i];

        // Hash the two children to get the parent
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== switchers[i].outL;
        hashers[i].inputs[1] <== switchers[i].outR;

        levelHashes[i + 1] <== hashers[i].out;
    }

    // The final computed hash must equal the public root
    root === levelHashes[k];
}

/*
 * MerkleProofWithNullifier
 *
 * Extended version that also outputs a nullifier — a unique value
 * derived from the leaf and a secret key. Used to prevent double-spending
 * without linking the spend to the leaf.
 *
 * Nullifier = Poseidon(leaf, secret)
 *
 * This is the core circuit pattern used in Tornado Cash and Zcash.
 */
template MerkleProofWithNullifier(k) {
    // Public
    signal input root;
    signal output nullifier;

    // Private
    signal input leaf;
    signal input secret;
    signal input pathElements[k];
    signal input pathIndices[k];

    // Verify Merkle membership
    component merkle = MerkleProof(k);
    merkle.leaf <== leaf;
    merkle.root <== root;
    for (var i = 0; i < k; i++) {
        merkle.pathElements[i] <== pathElements[i];
        merkle.pathIndices[i] <== pathIndices[i];
    }

    // Compute the nullifier (public output, but doesn't reveal leaf or path)
    component nullifierHasher = Poseidon(2);
    nullifierHasher.inputs[0] <== leaf;
    nullifierHasher.inputs[1] <== secret;
    nullifier <== nullifierHasher.out;
}

// Main: prove membership in a tree of depth 20 (~1M leaves)
component main { public [root] } = MerkleProof(20);
