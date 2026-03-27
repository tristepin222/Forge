#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
STAGE2_SOURCE="$ROOT/stages/stage2/compiler.ium"

VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@"
  fi
}

mkdir -p "$OUTPUT_DIR"

log "Building first-generation Stage 2 compiler with Stage 0..."
"$SCRIPT_DIR/build_stage2.sh"

log "Compiling stages/stage2/compiler.ium with first-generation Stage 2..."
python3 - <<PY | "$OUTPUT_DIR/stage1" > "$OUTPUT_DIR/stage1_gen2.asm"
from pathlib import Path
import sys
data = Path(r"$STAGE2_SOURCE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

log "Assembling second-generation Stage 2 compiler..."
nasm -f elf64 "$OUTPUT_DIR/stage1_gen2.asm" -o "$OUTPUT_DIR/stage1_gen2.o"
ld "$OUTPUT_DIR/stage1_gen2.o" -o "$OUTPUT_DIR/stage1_gen2"

log "Running Stage 2 regression suite with second-generation compiler..."

if [ "$VERBOSE" -eq 1 ]; then
  BUILD_STAGE2=0 STAGE2_BIN="$OUTPUT_DIR/stage1_gen2" "$SCRIPT_DIR/test_stage2.sh" --verbose
else
  BUILD_STAGE2=0 STAGE2_BIN="$OUTPUT_DIR/stage1_gen2" "$SCRIPT_DIR/test_stage2.sh"
fi

echo "Stage 2 bootstrap succeeded."
echo "First generation:  output/stage1"
echo "Second generation: output/stage1_gen2"
