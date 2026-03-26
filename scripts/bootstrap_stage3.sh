#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
STAGE3_SELFHOST_SOURCE="${STAGE3_SELFHOST_SOURCE:-$ROOT/stages/stage3/compiler.ium}"

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

if [ ! -f "$STAGE3_SELFHOST_SOURCE" ]; then
  echo "Stage 3 bootstrap is not available yet."
  echo "The current output/stage3 compiler is built from the Stage 2 source at stages/stage3/compiler.imp."
  echo "To bootstrap Stage 3, provide a self-hosted Stage 3 source file at:"
  echo "  $STAGE3_SELFHOST_SOURCE"
  echo "or set STAGE3_SELFHOST_SOURCE to another .ium compiler source."
  exit 1
fi

log "Building first-generation Stage 3 compiler with Stage 2..."
"$SCRIPT_DIR/build_stage3.sh"

log "Compiling self-hosted Stage 3 source with first-generation Stage 3..."
python3 - <<PY | "$OUTPUT_DIR/stage3" > "$OUTPUT_DIR/stage3_gen2.asm"
from pathlib import Path
import sys
data = Path(r"$STAGE3_SELFHOST_SOURCE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

log "Assembling second-generation Stage 3 compiler..."
nasm -f elf64 "$OUTPUT_DIR/stage3_gen2.asm" -o "$OUTPUT_DIR/stage3_gen2.o"
ld "$OUTPUT_DIR/stage3_gen2.o" -o "$OUTPUT_DIR/stage3_gen2"

log "Running Stage 3 regression suite with second-generation compiler..."
if [ "$VERBOSE" -eq 1 ]; then
  BUILD_STAGE3=0 STAGE3_BIN="$OUTPUT_DIR/stage3_gen2" "$SCRIPT_DIR/test_stage3.sh" --verbose
else
  BUILD_STAGE3=0 STAGE3_BIN="$OUTPUT_DIR/stage3_gen2" "$SCRIPT_DIR/test_stage3.sh"
fi

echo "Stage 3 bootstrap succeeded."
echo "First generation:  output/stage3"
echo "Second generation: output/stage3_gen2"
