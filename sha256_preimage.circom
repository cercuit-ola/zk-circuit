pragma circom 2.1.6;

include "../../node_modules/circomlib/circuits/sha256/sha256.circom";

/*
 * SHA256Preimage
 *
 * Proves knowledge of a preimage `preimage` such that SHA256(preimage) = hash,
 * without revealing the preimage.
 *
 * This is the canonical "hash preimage" ZK proof and a fundamental primitive
 * in many protocols (commitments, nullifiers, key derivation).
 *
 * NOTE: SHA256 inside a circuit is expensive (~27,000 constraints per block).
 * For ZK-native hashing, prefer Poseidon (~238 constraints per permutation).
 * Use SHA256 when you need compatibility with external systems (e.g., Bitcoin,
 * Ethereum event data, TLS certificates).
 *
 * Inputs:
 *   preimage[512] - private: 512-bit preimage (one SHA256 block), as individual bits
 *   hash[256]     - public: expected SHA256 output, as individual bits
 *
 * The inputs are bit arrays because SHA256 is defined over bits.
 * Use the helper below to convert integers to bit arrays.
 */
template SHA256Preimage() {
    signal input preimage[512];   // private: 512 bits = one 64-byte block
    signal input hash[256];       // public: expected hash output

    // Compute SHA256 of the preimage using circomlib's SHA256 template
    component sha256 = Sha256(512);

    for (var i = 0; i < 512; i++) {
        sha256.in[i] <== preimage[i];
    }

    // Each output bit must match the public hash
    for (var i = 0; i < 256; i++) {
        sha256.out[i] === hash[i];
    }
}

/*
 * SHA256PreimageChained
 *
 * Proves: SHA256(SHA256(preimage)) = hash
 * Useful for Bitcoin proof-of-work and similar double-hash constructions.
 */
template SHA256PreimageChained() {
    signal input preimage[512];
    signal input hash[256];

    // First hash
    component sha1 = Sha256(512);
    for (var i = 0; i < 512; i++) {
        sha1.in[i] <== preimage[i];
    }

    // Second hash (of the first hash output, padded to 512 bits)
    // In practice: SHA256 output is 256 bits, padded with 1 bit, zeros, and length
    // For simplicity we show the core idea:
    component sha2 = Sha256(256);
    for (var i = 0; i < 256; i++) {
        sha2.in[i] <== sha1.out[i];
    }

    for (var i = 0; i < 256; i++) {
        sha2.out[i] === hash[i];
    }
}

/*
 * BytesToBits (helper)
 *
 * Converts an array of bytes to a flat bit array (big-endian).
 * Use this to prepare inputs for SHA256Preimage.
 *
 * n: number of bytes (must be <= 64 for single-block SHA256)
 */
template BytesToBits(n) {
    signal input bytes[n];
    signal output bits[n * 8];

    for (var i = 0; i < n; i++) {
        for (var j = 0; j < 8; j++) {
            bits[i * 8 + j] <-- (bytes[i] >> (7 - j)) & 1;
            bits[i * 8 + j] * (1 - bits[i * 8 + j]) === 0;
        }

        // Recompose and check integrity
        var recomposed = 0;
        for (var j = 0; j < 8; j++) {
            recomposed += bits[i * 8 + j] * (1 << (7 - j));
        }
        recomposed === bytes[i];
    }
}

component main { public [hash] } = SHA256Preimage();
