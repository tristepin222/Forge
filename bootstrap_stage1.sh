#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT/output"
STAGE1_SOURCE="$ROOT/stage1.imp"

mkdir -p "$OUTPUT_DIR"

echo "Building first-generation Stage 1 compiler with Stage 0..."
"$ROOT/build_stage1.sh"

echo "Compiling stage1.imp with first-generation Stage 1..."
python3 - <<PY | "$OUTPUT_DIR/stage1" > "$OUTPUT_DIR/stage1_gen2.asm"
from pathlib import Path
import sys
data = Path(r"$STAGE1_SOURCE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

echo "Assembling second-generation Stage 1 compiler..."
nasm -f elf64 "$OUTPUT_DIR/stage1_gen2.asm" -o "$OUTPUT_DIR/stage1_gen2.o"
ld "$OUTPUT_DIR/stage1_gen2.o" -o "$OUTPUT_DIR/stage1_gen2"

echo "Running Stage 1 regression suite with second-generation compiler..."
BUILD_STAGE1=0 STAGE1_BIN="$OUTPUT_DIR/stage1_gen2" "$ROOT/test_stage1.sh"

echo "Stage 1 bootstrap succeeded."
echo "First generation:  output/stage1"
echo "Second generation: output/stage1_gen2"
