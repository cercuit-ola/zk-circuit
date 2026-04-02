pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/comparators.circom";

/*
 * Comparison Circuits
 *
 * Proving arithmetic comparisons inside ZK circuits is non-trivial
 * because circuits only natively support equality (===).
 *
 * The standard trick: to prove a >= b over n-bit values,
 * prove that (a - b) is representable in n bits (i.e., non-negative).
 *
 * All comparisons assume values in [0, 2^n).
 */

/*
 * GreaterThan
 *
 * Proves a > b for n-bit values.
 * Output: 1 if a > b, 0 otherwise.
 *
 * Method: a > b iff a - b - 1 >= 0 iff (a - b - 1) has an n-bit representation.
 */
template GreaterThan(n) {
    assert(n <= 252);  // Field size limit

    signal input a;
    signal input b;
    signal output out;

    // Use circomlib's built-in GreaterThan
    component gt = GreaterThan(n);
    gt.in[0] <== a;
    gt.in[1] <== b;
    out <== gt.out;
}

/*
 * GreaterEqThan
 *
 * Proves a >= b.
 * Output: 1 if a >= b, 0 otherwise.
 */
template GreaterEqThan(n) {
    signal input a;
    signal input b;
    signal output out;

    component geq = GreaterEqThan(n);
    geq.in[0] <== a;
    geq.in[1] <== b;
    out <== geq.out;
}

/*
 * InRange
 *
 * Proves low <= v <= high using two comparisons.
 * All three values must be n-bit integers.
 * 
 * Output: 1 if in range, 0 otherwise.
 * IMPORTANT: For ZK proofs, we usually want to *constrain* rather than output,
 * so see InRangeConstrained below for the more common usage.
 */
template InRange(n) {
    signal input v;
    signal input low;
    signal input high;
    signal output out;

    // Check low <= v
    component geqLow = GreaterEqThan(n);
    geqLow.in[0] <== v;
    geqLow.in[1] <== low;

    // Check v <= high  (equivalent to high >= v)
    component geqHigh = GreaterEqThan(n);
    geqHigh.in[0] <== high;
    geqHigh.in[1] <== v;

    // Both must be true
    out <== geqLow.out * geqHigh.out;
}

/*
 * InRangeConstrained
 *
 * Like InRange but asserts the result is 1 (forces the constraint).
 * Use this when you want to *require* v is in [low, high], not just output a boolean.
 *
 * This is the most common pattern in ZK circuits.
 */
template InRangeConstrained(n) {
    signal input v;
    signal input low;
    signal input high;

    component check = InRange(n);
    check.v <== v;
    check.low <== low;
    check.high <== high;

    // Force the output to be 1
    check.out === 1;
}

/*
 * MaxOfTwo
 *
 * Returns max(a, b) without revealing which is larger.
 * Useful for building sorting networks in ZK.
 *
 * Output: the larger of the two values.
 */
template MaxOfTwo(n) {
    signal input a;
    signal input b;
    signal output out;

    component gt = GreaterThan(n);
    gt.in[0] <== a;
    gt.in[1] <== b;

    // out = gt.out * a + (1 - gt.out) * b
    // = a if a > b, else b
    out <== gt.out * (a - b) + b;
}

/*
 * AbsoluteDifference
 *
 * Computes |a - b| without a conditional branch.
 *
 * |a - b| = a - b if a >= b
 *           b - a if b > a
 *         = (a - b) * (a >= b ? 1 : -1)
 *         = (2 * (a>=b) - 1) * (a - b)
 */
template AbsoluteDifference(n) {
    signal input a;
    signal input b;
    signal output out;

    component geq = GreaterEqThan(n);
    geq.in[0] <== a;
    geq.in[1] <== b;

    // sign = 1 if a >= b, -1 if a < b => (2*geq.out - 1)
    signal sign <== 2 * geq.out - 1;
    out <== sign * (a - b);
}

// Main: prove a 64-bit value is in a given range
component main { public [low, high] } = InRangeConstrained(64);
