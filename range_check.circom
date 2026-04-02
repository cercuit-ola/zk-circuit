pragma circom 2.1.6;

/*
 * RangeCheck
 *
 * Proves that a private value `v` lies in the range [0, 2^n)
 * without revealing the value itself.
 *
 * How it works:
 *   - Decompose v into n bits: v = b_0 + 2*b_1 + 4*b_2 + ... + 2^(n-1)*b_(n-1)
 *   - Constrain each bit to be 0 or 1: b_i * (1 - b_i) = 0
 *   - Recompose and check the sum equals v
 *
 * If the prover can produce a valid bit decomposition, v must be in [0, 2^n).
 *
 * Inputs:
 *   v - the private value to range-check
 *
 * Parameters:
 *   n - number of bits (range is [0, 2^n))
 */
template RangeCheck(n) {
    signal input v;             // private: value to check
    signal output bits[n];      // intermediate: bit decomposition

    var lc = 0;
    var twoPow = 1;

    for (var i = 0; i < n; i++) {
        // Extract the i-th bit from v
        bits[i] <-- (v >> i) & 1;

        // Constraint 1: each bit must be boolean (0 or 1)
        bits[i] * (1 - bits[i]) === 0;

        // Accumulate the linear combination: sum of 2^i * bits[i]
        lc += twoPow * bits[i];
        twoPow *= 2;
    }

    // Constraint 2: bit decomposition must recompose to v
    lc === v;
}

/*
 * BoundedRangeCheck
 *
 * Proves that `low <= v < high` where low and high are public constants.
 *
 * Approach:
 *   - Prove v - low >= 0 (i.e. v - low is in [0, 2^n))
 *   - Prove high - 1 - v >= 0 (i.e. high - 1 - v is in [0, 2^n))
 *
 * Inputs:
 *   v   - private value
 *   low - public lower bound (inclusive)
 *   high - public upper bound (exclusive)
 */
template BoundedRangeCheck(n) {
    signal input v;
    signal input low;
    signal input high;

    // Check v - low is in [0, 2^n)
    component lowerCheck = RangeCheck(n);
    lowerCheck.v <== v - low;

    // Check high - 1 - v is in [0, 2^n)
    component upperCheck = RangeCheck(n);
    upperCheck.v <== high - 1 - v;
}

// Main: prove a 32-bit value is in range [0, 2^32)
component main { public [] } = RangeCheck(32);
