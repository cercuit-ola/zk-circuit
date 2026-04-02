pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

/*
 * SetMembership
 *
 * Proves that a private value `v` belongs to a public set S = {s_0, ..., s_{n-1}}
 * without revealing which element it is or the value itself.
 *
 * Naive approach: Check v == s_i for each i and OR the results.
 * Problem: n equality checks = n constraints, expensive for large sets.
 *
 * Better approach used here:
 *   - Compute the product: P = ∏(v - s_i)
 *   - P = 0 iff v equals some s_i
 *   - Prove P = 0 without revealing which factor is zero
 *
 * This is O(n) constraints but very low constant — just multiplications.
 *
 * For large sets (n > 1000), use lookup arguments (PlonkUp) instead.
 *
 * Inputs:
 *   v         - private: the value to check membership for
 *   set[n]    - public: the set elements
 *
 * Parameters:
 *   n - size of the set
 */
template SetMembership(n) {
    signal input v;
    signal input set[n];

    // Compute running product: ∏(v - set[i])
    signal products[n];

    // First factor
    products[0] <== v - set[0];

    // Multiply in each subsequent factor
    for (var i = 1; i < n; i++) {
        products[i] <== products[i-1] * (v - set[i]);
    }

    // The product must be zero — meaning v equals some element
    products[n-1] === 0;
}

/*
 * SetMembershipWithWitness
 *
 * Same as SetMembership but also requires the prover to provide
 * the index of the matching element. More explicit and slightly
 * more efficient for very small sets.
 *
 * Additionally outputs a "selector" signal confirming membership.
 *
 * Inputs:
 *   v        - private: the value to check
 *   index    - private: claimed index of v in the set
 *   set[n]   - public: the set elements
 */
template SetMembershipWithWitness(n) {
    signal input v;
    signal input index;     // claimed position of v in set
    signal input set[n];

    // index must be in [0, n)
    component rangeCheck = RangeCheck(8);   // supports up to n=256
    rangeCheck.v <== index;

    // Selector array: selector[i] = 1 if i == index, else 0
    signal selector[n];
    signal indexEq[n];

    var sum = 0;
    for (var i = 0; i < n; i++) {
        // Check if i == index using IsEqual
        component eq = IsEqual();
        eq.in[0] <== i;
        eq.in[1] <== index;
        selector[i] <== eq.out;
        sum += selector[i];
    }

    // Exactly one selector must be 1
    sum === 1;

    // The selected element must equal v
    // v = ∑ selector[i] * set[i]
    signal selected[n];
    signal accumulator[n];

    selected[0] <== selector[0] * set[0];
    accumulator[0] <== selected[0];

    for (var i = 1; i < n; i++) {
        selected[i] <== selector[i] * set[i];
        accumulator[i] <== accumulator[i-1] + selected[i];
    }

    accumulator[n-1] === v;
}

/*
 * RangeCheck (local copy for self-contained compilation)
 */
template RangeCheck(n) {
    signal input v;
    signal bits[n];

    var lc = 0;
    var twoPow = 1;

    for (var i = 0; i < n; i++) {
        bits[i] <-- (v >> i) & 1;
        bits[i] * (1 - bits[i]) === 0;
        lc += twoPow * bits[i];
        twoPow *= 2;
    }

    lc === v;
}

// Main: prove membership in a set of 10 elements
component main { public [set] } = SetMembership(10);
