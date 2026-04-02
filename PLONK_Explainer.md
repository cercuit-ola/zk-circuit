# PLONK Explained: A Deep Dive into the Universal ZK Proof System

> **Paper:** *PLONK: Permutations over Lagrange-bases for Oecumenical Noninteractive arguments of Knowledge*
> **Authors:** Ariel Gabizon, Zachary J. Williamson, Oana Ciobotaru (2019)
> **Why it matters:** PLONK is the foundation of most modern ZK systems — Aztec, zkSync, Polygon, and many more are built on top of it or its descendants.

---

## Table of Contents

1. [What Problem Does PLONK Solve?](#1-what-problem-does-plonk-solve)
2. [Background: What You Need to Know First](#2-background-what-you-need-to-know-first)
3. [The Core Idea: Arithmetic Circuits to Polynomials](#3-the-core-idea-arithmetic-circuits-to-polynomials)
4. [Gate Constraints](#4-gate-constraints)
5. [The Copy Constraint Problem (and How Permutations Solve It)](#5-the-copy-constraint-problem-and-how-permutations-solve-it)
6. [The Polynomial IOP](#6-the-polynomial-iop)
7. [KZG Polynomial Commitments](#7-kzg-polynomial-commitments)
8. [Putting It All Together: The Full PLONK Protocol](#8-putting-it-all-together-the-full-plonk-protocol)
9. [Why "Universal"? The Trusted Setup](#9-why-universal-the-trusted-setup)
10. [PLONK vs Groth16: Key Differences](#10-plonk-vs-groth16-key-differences)
11. [PLONK Descendants: UltraPLONK, TurboPlonk, Halo2](#11-plonk-descendants-ultraplonk-turboplonk-halo2)
12. [Summary and Research Directions](#12-summary-and-research-directions)

---

## 1. What Problem Does PLONK Solve?

Before PLONK, the dominant ZK-SNARK system was **Groth16**. Groth16 produces tiny proofs and is very fast to verify — but it has a critical limitation: **the trusted setup is circuit-specific**. This means every time you want to prove a different computation, you need to run a new trusted setup ceremony. This is expensive, slow, and operationally painful.

PLONK solves this with a **universal and updatable trusted setup**:
- **Universal:** One setup works for *all* circuits up to a maximum size `n`.
- **Updatable:** Anyone can contribute to the setup after the fact, without restarting from scratch.

This makes PLONK far more practical for real-world deployment.

---

## 2. Background: What You Need to Know First

Before understanding PLONK, you need comfort with a few concepts:

### Finite Fields
PLONK works over a prime field `𝔽_p`. All arithmetic (addition, multiplication) is done modulo a large prime `p`. Every element has a multiplicative inverse (except 0).

### Elliptic Curves and Pairings
PLONK uses an elliptic curve group `𝔾` and a bilinear pairing `e: 𝔾 × 𝔾 → 𝔾_T`. Pairings let you check multiplicative relationships between group elements — critical for the KZG commitment scheme used in PLONK.

### Polynomials over Finite Fields
A polynomial `f(X)` of degree `d` over `𝔽_p` has at most `d` roots. This is the **Schwartz-Zippel lemma** at work, and it's the engine behind polynomial-based ZK proofs: if two polynomials agree on a random point, they almost certainly are the same polynomial.

### Lagrange Interpolation
Given `n` points `{(x_i, y_i)}`, there exists a unique polynomial of degree `n-1` that passes through all of them. PLONK uses this to encode computation into polynomials.

---

## 3. The Core Idea: Arithmetic Circuits to Polynomials

Like all SNARKs, PLONK starts by expressing your computation as an **arithmetic circuit** — a directed acyclic graph of addition and multiplication gates over `𝔽_p`.

For example, computing `x³ + x + 5 = 35` (proving you know `x=3`):

```
Gate 1: x * x = x²          (multiplication)
Gate 2: x² * x = x³         (multiplication)
Gate 3: x³ + x = x³+x       (addition)
Gate 4: (x³+x) + 5 = 35     (addition with constant)
```

### Flattening to a Table

PLONK represents the circuit as a table with `n` rows (one per gate) and columns for:
- `a_i` — left input wire
- `b_i` — right input wire  
- `c_i` — output wire

For our example:
```
i  | a_i | b_i | c_i
---|-----|-----|-----
1  |  3  |  3  |  9     (3 * 3 = 9)
2  |  9  |  3  |  27    (9 * 3 = 27)
3  |  27 |  3  |  30    (27 + 3 = 30)
4  |  30 |  5  |  35    (30 + 5 = 35)
```

The **witness** is the full assignment to all wires. The **statement** is the public output (35). The **secret** is `x = 3`.

---

## 4. Gate Constraints

Each gate must satisfy a constraint. PLONK uses a general **gate equation**:

```
q_L · a  +  q_R · b  +  q_O · c  +  q_M · (a · b)  +  q_C  =  0
```

Where `q_L, q_R, q_O, q_M, q_C` are **selector polynomials** that "turn on" different parts of the gate. This single equation encodes both addition and multiplication:

| Gate Type  | q_M | q_L | q_R | q_O | q_C |
|------------|-----|-----|-----|-----|-----|
| Multiply   |  1  |  0  |  0  | -1  |  0  |
| Add        |  0  |  1  |  1  | -1  |  0  |
| Const add  |  0  |  1  |  0  | -1  |  k  |

The selectors are **fixed at setup time** (they encode the circuit structure, not the witness).

### Encoding as Polynomials

Let `H = {ω⁰, ω¹, ..., ω^(n-1)}` be a multiplicative subgroup of `𝔽_p` of size `n`, where `ω` is a primitive `n`-th root of unity.

We define:
- `a(X)` — polynomial that evaluates to `a_i` at `ωⁱ`
- `b(X)` — polynomial that evaluates to `b_i` at `ωⁱ`
- `c(X)` — polynomial that evaluates to `c_i` at `ωⁱ`

The gate constraint for all gates simultaneously becomes:

```
q_M(X)·a(X)·b(X) + q_L(X)·a(X) + q_R(X)·b(X) + q_O(X)·c(X) + q_C(X) = 0  for all X ∈ H
```

This is equivalent to saying the left-hand side is **divisible by the vanishing polynomial** `Z_H(X) = X^n - 1`.

So the prover needs to produce a quotient polynomial `t(X)` such that:

```
q_M·ab + q_L·a + q_R·b + q_O·c + q_C = t(X) · Z_H(X)
```

---

## 5. The Copy Constraint Problem (and How Permutations Solve It)

Gate constraints alone aren't enough. In a circuit, wires are **shared** across gates. For example, the output of Gate 1 (`c_1 = 9`) is the left input of Gate 2 (`a_2 = 9`). Without enforcing this, a cheating prover could use different values.

These **copy constraints** (or wiring constraints) are the hardest part of PLONK.

### The Permutation Argument

PLONK encodes copy constraints as a permutation. Consider all `3n` wire values flattened:

```
(a_1, a_2, ..., a_n, b_1, b_2, ..., b_n, c_1, c_2, ..., c_n)
```

A copy constraint `a_2 = c_1` means positions 2 and (2n+1) in this list must have equal values. This defines a permutation `σ` that swaps constrained positions.

**The key insight:** A set of values is invariant under a permutation if and only if:

```
∏ (f(i) + β·i + γ) / ∏ (f(σ(i)) + β·i + γ) = 1
```

for random challenges `β, γ`.

PLONK proves this using an **accumulator polynomial** `Z(X)` where:
- `Z(ω⁰) = 1`
- `Z(ωⁱ) = ∏_{j<i} (f_j + β·j + γ) / (f_j + β·σ(j) + γ)`
- `Z(ωⁿ) = 1` (full product must equal 1)

The prover commits to `Z(X)` and the verifier checks transition constraints on it.

---

## 6. The Polynomial IOP

A **Polynomial IOP** is an idealized protocol where:
1. The prover sends **polynomial oracles** (black boxes that can be evaluated at any point)
2. The verifier queries them at random points
3. The verifier does a polynomial-time check

PLONK's Polynomial IOP works in **5 rounds**:

```
Round 1: Prover sends [a], [b], [c]     (wire polynomials)
Round 2: Verifier sends β, γ            (permutation challenges)
         Prover sends [Z]               (accumulator polynomial)
Round 3: Verifier sends α               (gate/permutation combination)
         Prover sends [t_lo], [t_mid], [t_hi]  (quotient polynomial, split into thirds)
Round 4: Verifier sends ζ               (evaluation point)
         Prover sends ā, b̄, c̄, s̄₁, s̄₂, z̄_ω (evaluations at ζ)
Round 5: Verifier sends v               (batching challenge)
         Prover sends [W_ζ], [W_ζω]    (opening proofs)
```

At the end, the verifier does a **single pairing check** to verify everything.

---

## 7. KZG Polynomial Commitments

PLONK uses **KZG commitments** (Kate-Zaverucha-Goldberg) to realize the polynomial oracle model.

### Setup
A trusted setup produces structured reference string (SRS):
```
([1]₁, [τ]₁, [τ²]₁, ..., [τⁿ]₁, [τ]₂)
```
where `τ` is a secret "toxic waste" that must be deleted.

### Commit
To commit to polynomial `f(X) = Σ fᵢXⁱ`:
```
[f(τ)]₁ = Σ fᵢ · [τⁱ]₁
```
This is a single group element — a constant-size commitment regardless of degree!

### Open
To prove `f(z) = v`, compute the **quotient polynomial**:
```
q(X) = (f(X) - v) / (X - z)
```
This exists iff `f(z) = v`. Send `[q(τ)]₁` as the proof.

### Verify
The verifier checks using a pairing:
```
e([f(τ)]₁ - [v]₁, [1]₂) = e([q(τ)]₁, [τ]₂ - [z]₂)
```

This is a single constant-time check — verification is O(1) regardless of circuit size.

---

## 8. Putting It All Together: The Full PLONK Protocol

```
PROVER                                    VERIFIER
  |                                           |
  |-- Commit to a(X), b(X), c(X) ----------->|
  |                                           |-- Send β, γ
  |<-- β, γ ----------------------------------|
  |                                           |
  |-- Commit to Z(X) ----------------------->|
  |                                           |-- Send α
  |<-- α --------------------------------------|
  |                                           |
  |-- Commit to t(X) split as t_lo,t_mid,t_hi->|
  |                                           |-- Send ζ
  |<-- ζ --------------------------------------|
  |                                           |
  |-- Send evaluations at ζ: ā,b̄,c̄,s̄₁,s̄₂,z̄_ω->|
  |                                           |-- Send v
  |<-- v --------------------------------------|
  |                                           |
  |-- Send opening proofs W_ζ, W_ζω -------->|
  |                                           |
  |                              VERIFY: 2 pairings
```

**Proof size:** 9 group elements + 7 field elements ≈ **~500 bytes**

**Verification:** **2 pairing checks** (near-constant time)

---

## 9. Why "Universal"? The Trusted Setup

Unlike Groth16, PLONK's SRS is:

- **Universal:** The same `([τ⁰]₁, ..., [τⁿ]₁, [τ]₂)` works for any circuit up to size `n`
- **Updatable:** Anyone can add randomness `ρ` to get `τ' = τ·ρ`, as long as one contributor is honest
- **Reusable:** Once run, no further ceremonies needed for new circuits

The circuit-specific part (selector and permutation polynomials) is done by the **circuit developer** in a preprocessing step — no ceremony required.

---

## 10. PLONK vs Groth16: Key Differences

| Property           | Groth16          | PLONK                  |
|--------------------|------------------|------------------------|
| Trusted Setup      | Per-circuit      | Universal              |
| Proof Size         | ~200 bytes       | ~500 bytes             |
| Proving Time       | Faster           | Slightly slower        |
| Verification Time  | O(1), very fast  | O(1), slightly larger  |
| Flexibility        | R1CS only        | Custom gates possible  |
| Post-quantum safe  | No               | No (both use pairings) |

**When to use PLONK:** When you need a universal setup, plan to deploy multiple circuits, or want custom gates (UltraPLONK).

**When to use Groth16:** When proof size and verification speed are critical and circuit is fixed (e.g., final production SNARK for a specific VM opcode).

---

## 11. PLONK Descendants: UltraPLONK, TurboPlonk, Halo2

PLONK's gate equation was extended significantly:

### TurboPlonk
Adds **custom gates** beyond the generic `q_M·ab + q_L·a + ...` form. Useful for efficiently proving operations like range checks or hash functions.

### UltraPLONK (Aztec)
Adds:
- **Lookup arguments** — proves a value exists in a precomputed table (replaces many gates with a single lookup)
- **Plookup** — efficient multi-column lookups

Lookup arguments dramatically reduce the cost of operations with fixed input/output behavior (e.g., SHA256 bit operations, Keccak).

### Halo2 (ZCash/ECC)
- Replaces KZG with **IPA (Inner Product Argument)** — no trusted setup, but larger proofs
- Uses the **Halo recursive trick** — proof of proof verification enables efficient recursion
- Widely used: Scroll, Taiko, Axiom are built on Halo2

### HyperPlonk (recent)
- Replaces univariate polynomials with **multilinear polynomials**
- Uses **sumcheck** instead of the vanishing polynomial
- Better asymptotic prover time

---

## 12. Summary and Research Directions

### What PLONK Achieves
- Universal trusted setup (one ceremony for all circuits)
- Succinct proofs (~500 bytes)
- Efficient verification (2 pairings)
- Flexible gate design

### Open Research Directions
If you want to build a research career in this space, consider these open questions:

1. **Better lookup arguments** — PlookUp has overhead; newer schemes like Caulk and Caulk+ improve this
2. **Recursive proof composition** — can we do Halo-style recursion with KZG efficiently?
3. **Post-quantum PLONK** — replacing pairings with lattice-based commitments
4. **Prover efficiency** — the bottleneck is multi-scalar multiplication (MSM); better algorithms directly accelerate PLONK
5. **Hardware acceleration** — FPGA/GPU implementations of the prover
6. **Folding schemes** — Nova, SuperNova, HyperNova generalize recursion beyond PLONK

---

## Further Reading

- Original PLONK paper: https://eprint.iacr.org/2019/953
- KZG commitments: Kate et al. 2010 — https://www.iacr.org/archive/asiacrypt2010/6477178/6477178.pdf
- PlonkByHand (excellent blog series): https://research.metastate.dev/plonk-by-hand-part-1/
- Halo2 book: https://zcash.github.io/halo2/
- Aztec's UltraPLONK: https://hackmd.io/@aztec-network/plonk-arithmetization

---

*Written as a research explainer. Assumes familiarity with basic cryptography and finite field arithmetic.*
