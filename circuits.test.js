const chai = require("chai");
const path = require("path");
const { wasm: wasm_tester } = require("circom_tester");
const { buildPoseidon } = require("circomlibjs");

const assert = chai.assert;

// ─────────────────────────────────────────
// Range Check Tests
// ─────────────────────────────────────────
describe("RangeCheck", function () {
    this.timeout(60000);

    let circuit;

    before(async function () {
        circuit = await wasm_tester(
            path.join(__dirname, "../circuits/range_check/range_check.circom")
        );
    });

    it("should accept a valid 32-bit value", async function () {
        const witness = await circuit.calculateWitness({ v: 1000 });
        await circuit.checkConstraints(witness);
    });

    it("should accept 0", async function () {
        const witness = await circuit.calculateWitness({ v: 0 });
        await circuit.checkConstraints(witness);
    });

    it("should accept max 32-bit value (2^32 - 1)", async function () {
        const witness = await circuit.calculateWitness({ v: (1n << 32n) - 1n });
        await circuit.checkConstraints(witness);
    });

    it("should reject 2^32 (out of range)", async function () {
        try {
            await circuit.calculateWitness({ v: 1n << 32n });
            assert.fail("Should have thrown");
        } catch (e) {
            assert.include(e.message, "Constraint doesn't match");
        }
    });
});

// ─────────────────────────────────────────
// Merkle Proof Tests
// ─────────────────────────────────────────
describe("MerkleProof", function () {
    this.timeout(120000);

    let circuit;
    let poseidon;
    let F;

    before(async function () {
        circuit = await wasm_tester(
            path.join(__dirname, "../circuits/merkle_proof/merkle_proof.circom")
        );
        poseidon = await buildPoseidon();
        F = poseidon.F;
    });

    // Build a depth-2 Merkle tree with 4 leaves
    function buildMerkleTree(leaves) {
        const level0 = leaves.map(l => F.toObject(poseidon([l])));
        const level1 = [
            F.toObject(poseidon([level0[0], level0[1]])),
            F.toObject(poseidon([level0[2], level0[3]])),
        ];
        const root = F.toObject(poseidon([level1[0], level1[1]]));
        return { level0, level1, root };
    }

    it("should verify a valid Merkle proof for leaf at index 0", async function () {
        const leaves = [100n, 200n, 300n, 400n];
        const tree = buildMerkleTree(leaves);

        const input = {
            leaf: 100n,
            pathElements: [tree.level0[1], tree.level1[1]],
            pathIndices: [0, 0],   // left child at both levels
            root: tree.root,
        };

        const witness = await circuit.calculateWitness(input);
        await circuit.checkConstraints(witness);
    });

    it("should verify a valid Merkle proof for leaf at index 2", async function () {
        const leaves = [100n, 200n, 300n, 400n];
        const tree = buildMerkleTree(leaves);

        const input = {
            leaf: 300n,
            pathElements: [tree.level0[3], tree.level1[0]],
            pathIndices: [0, 1],   // left at level 0, right at level 1
            root: tree.root,
        };

        const witness = await circuit.calculateWitness(input);
        await circuit.checkConstraints(witness);
    });

    it("should reject a wrong root", async function () {
        const leaves = [100n, 200n, 300n, 400n];
        const tree = buildMerkleTree(leaves);

        const input = {
            leaf: 100n,
            pathElements: [tree.level0[1], tree.level1[1]],
            pathIndices: [0, 0],
            root: 9999n,   // wrong root
        };

        try {
            await circuit.calculateWitness(input);
            assert.fail("Should have thrown");
        } catch (e) {
            assert.include(e.message, "Constraint doesn't match");
        }
    });

    it("should reject a wrong leaf", async function () {
        const leaves = [100n, 200n, 300n, 400n];
        const tree = buildMerkleTree(leaves);

        const input = {
            leaf: 999n,   // not in tree
            pathElements: [tree.level0[1], tree.level1[1]],
            pathIndices: [0, 0],
            root: tree.root,
        };

        try {
            await circuit.calculateWitness(input);
            assert.fail("Should have thrown");
        } catch (e) {
            assert.include(e.message, "Constraint doesn't match");
        }
    });
});

// ─────────────────────────────────────────
// Set Membership Tests
// ─────────────────────────────────────────
describe("SetMembership", function () {
    this.timeout(60000);

    let circuit;

    before(async function () {
        circuit = await wasm_tester(
            path.join(__dirname, "../circuits/set_membership/set_membership.circom")
        );
    });

    const publicSet = [10n, 20n, 30n, 40n, 50n, 60n, 70n, 80n, 90n, 100n];

    it("should accept a value in the set (first element)", async function () {
        const witness = await circuit.calculateWitness({ v: 10n, set: publicSet });
        await circuit.checkConstraints(witness);
    });

    it("should accept a value in the set (last element)", async function () {
        const witness = await circuit.calculateWitness({ v: 100n, set: publicSet });
        await circuit.checkConstraints(witness);
    });

    it("should accept a value in the set (middle element)", async function () {
        const witness = await circuit.calculateWitness({ v: 50n, set: publicSet });
        await circuit.checkConstraints(witness);
    });

    it("should reject a value not in the set", async function () {
        try {
            await circuit.calculateWitness({ v: 99n, set: publicSet });
            assert.fail("Should have thrown");
        } catch (e) {
            assert.include(e.message, "Constraint doesn't match");
        }
    });
});
