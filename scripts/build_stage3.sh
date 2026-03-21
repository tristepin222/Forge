#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
STAGE3_SOURCE="$ROOT/stages/stage3/compiler.imp"

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

log "Building Stage 2 compiler first..."
"$SCRIPT_DIR/build_stage2.sh"

log "Compiling stages/stage3/compiler.imp with Stage 2..."
python3 - <<PY | "$OUTPUT_DIR/stage1" > "$OUTPUT_DIR/stage3.asm"
from pathlib import Path
import sys
data = Path(r"$STAGE3_SOURCE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

log "Assembling Stage 3 compiler..."
nasm -f elf64 "$OUTPUT_DIR/stage3.asm" -o "$OUTPUT_DIR/stage3.o"
ld "$OUTPUT_DIR/stage3.o" -o "$OUTPUT_DIR/stage3"

echo "Stage 3 compiler built at output/stage3"
