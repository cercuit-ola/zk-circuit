#!/bin/bash
# setup.sh — Full Groth16 trusted setup pipeline for a circuit
# Usage: bash scripts/setup.sh <circuit_name>
# Example: bash scripts/setup.sh range_check

set -e

CIRCUIT=${1:-range_check}
BUILD_DIR="build/$CIRCUIT"
CIRCUIT_FILE="circuits/$CIRCUIT/$CIRCUIT.circom"

echo "========================================"
echo "  ZK Setup Pipeline: $CIRCUIT"
echo "========================================"

# Step 1: Compile the circuit
echo ""
echo "[1/5] Compiling circuit..."
mkdir -p "$BUILD_DIR"
circom "$CIRCUIT_FILE" --r1cs --wasm --sym -o "$BUILD_DIR"
echo "  ✓ Compiled → $BUILD_DIR/$CIRCUIT.r1cs"

# Step 2: Print circuit info
echo ""
echo "[2/5] Circuit info:"
snarkjs r1cs info "$BUILD_DIR/$CIRCUIT.r1cs"

# Step 3: Powers of Tau ceremony (phase 1)
# In production, use a real ceremony. For dev, generate locally.
echo ""
echo "[3/5] Powers of Tau (phase 1)..."
if [ ! -f "pot12_0000.ptau" ]; then
    snarkjs powersoftau new bn128 12 pot12_0000.ptau -v
    snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau \
        --name="First Contribution" -v -e="random entropy for dev"
    snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v
    echo "  ✓ Powers of Tau ready"
else
    echo "  ✓ Reusing existing pot12_final.ptau"
fi

# Step 4: Circuit-specific setup (phase 2)
echo ""
echo "[4/5] Circuit-specific setup (phase 2)..."
snarkjs groth16 setup "$BUILD_DIR/$CIRCUIT.r1cs" pot12_final.ptau "$BUILD_DIR/${CIRCUIT}_0000.zkey"
snarkjs zkey contribute "$BUILD_DIR/${CIRCUIT}_0000.zkey" "$BUILD_DIR/${CIRCUIT}_0001.zkey" \
    --name="Dev contribution" -v -e="more random entropy"
snarkjs zkey beacon "$BUILD_DIR/${CIRCUIT}_0001.zkey" "$BUILD_DIR/${CIRCUIT}_final.zkey" \
    0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"
echo "  ✓ zkey ready: $BUILD_DIR/${CIRCUIT}_final.zkey"

# Step 5: Export verification key
echo ""
echo "[5/5] Exporting verification key..."
snarkjs zkey export verificationkey "$BUILD_DIR/${CIRCUIT}_final.zkey" "$BUILD_DIR/verification_key.json"
echo "  ✓ Verification key: $BUILD_DIR/verification_key.json"

echo ""
echo "========================================"
echo "  Setup complete for: $CIRCUIT"
echo "  Build dir: $BUILD_DIR/"
echo "  Next: bash scripts/prove.sh $CIRCUIT"
echo "========================================"
