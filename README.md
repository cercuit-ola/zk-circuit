# zk-circuits

> A curated collection of Zero-Knowledge circuits implemented in Circom — from fundamentals to advanced patterns. Built for learning, research, and production reference.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Circom](https://img.shields.io/badge/Circom-2.1.x-blue)](https://docs.circom.io/)
[![snarkjs](https://img.shields.io/badge/snarkjs-0.7.x-green)](https://github.com/iden3/snarkjs)

---

## What's Inside

| Circuit | Description | Difficulty |
|---------|-------------|------------|
| `range_check` | Prove a value lies within [0, 2^n) | Beginner |
| `merkle_proof` | Prove membership in a Merkle tree | Intermediate |
| `multiplier_chain` | Repeated multiplication — constraint fundamentals | Beginner |
| `sha256_preimage` | Prove knowledge of a SHA256 preimage | Intermediate |
| `ecdsa_verify` | Verify an ECDSA signature inside a circuit | Advanced |
| `set_membership` | Prove element in set without revealing element | Intermediate |
| `comparison` | Greater-than / less-than comparisons | Beginner |
| `polynomial_eval` | Evaluate a committed polynomial at a point | Advanced |

---

## Prerequisites

```bash
# Install Circom (requires Rust)
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
git clone https://github.com/iden3/circom.git
cd circom && cargo build --release && cargo install --path circom

# Install snarkjs
npm install -g snarkjs

# Install Node dependencies
npm install
```

---

## Quick Start

```bash
# Compile a circuit
cd circuits/range_check
circom range_check.circom --r1cs --wasm --sym

# Generate witness
node generate_witness.js range_check.wasm input.json witness.wtns

# Setup (Groth16, uses Powers of Tau)
snarkjs groth16 setup range_check.r1cs pot12_final.ptau circuit_0000.zkey

# Generate proof
snarkjs groth16 prove circuit_0000.zkey witness.wtns proof.json public.json

# Verify proof
snarkjs groth16 verify verification_key.json public.json proof.json
```

---

## Circuits

### 1. Range Check
Prove that a private value `v` satisfies `0 ≤ v < 2^n` without revealing `v`.

### 2. Merkle Proof
Prove you know a leaf and its authentication path in a Merkle tree with a known root.

### 3. Set Membership
Prove an element belongs to a committed set — useful for allowlists and blacklists.

### 4. Comparison
Prove `a > b` or `a < b` over field elements.

### 5. SHA256 Preimage
Prove you know a string `s` such that `SHA256(s) = h` without revealing `s`.

---

## Repository Structure

```
zk-circuits/
├── circuits/
│   ├── range_check/
│   │   ├── range_check.circom
│   │   └── input.json
│   ├── merkle_proof/
│   │   ├── merkle_proof.circom
│   │   ├── hasher.circom
│   │   └── input.json
│   ├── set_membership/
│   │   ├── set_membership.circom
│   │   └── input.json
│   ├── comparison/
│   │   ├── comparison.circom
│   │   └── input.json
│   └── sha256_preimage/
│       ├── sha256_preimage.circom
│       └── input.json
├── scripts/
│   ├── setup.sh          # Full trusted setup pipeline
│   ├── prove.sh          # Witness + proof generation
│   └── verify.sh         # Proof verification
├── test/
│   ├── range_check.test.js
│   ├── merkle_proof.test.js
│   └── set_membership.test.js
├── package.json
└── README.md
```

---

## Testing

```bash
npm test
```

Tests use `circom_tester` to compile circuits, generate witnesses, and assert constraint satisfaction.

---

## Contributing

Pull requests welcome. For major changes, open an issue first. Please add tests for new circuits.

---

## License

MIT
# zk-circuit
