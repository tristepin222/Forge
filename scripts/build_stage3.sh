#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
STAGE3_SOURCE="$ROOT/stages/stage3/compiler.ium"
FORCE_REBUILD_STAGE3="${FORCE_REBUILD_STAGE3:-0}"

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
if [ "$VERBOSE" -eq 1 ]; then
  "$SCRIPT_DIR/build_stage2.sh" --verbose
else
  "$SCRIPT_DIR/build_stage2.sh"
fi

if [ "$FORCE_REBUILD_STAGE3" != "1" ] && [ -f "$OUTPUT_DIR/stage3" ]; then
  if [ "$OUTPUT_DIR/stage3" -nt "$STAGE3_SOURCE" ] && [ "$OUTPUT_DIR/stage3" -nt "$OUTPUT_DIR/stage1" ]; then
    echo "Stage 3 compiler already up to date at output/stage3"
    exit 0
  fi
fi

log "Compiling stages/stage3/compiler.ium with Stage 2..."
STAGE3_SOURCE_BIN="$OUTPUT_DIR/stage3.source"
python3 - <<PY > "$STAGE3_SOURCE_BIN"
from pathlib import Path
import sys
data = Path(r"$STAGE3_SOURCE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

if [ "$VERBOSE" -eq 1 ]; then
  "$OUTPUT_DIR/stage1" < "$STAGE3_SOURCE_BIN" > "$OUTPUT_DIR/stage3.asm" &
  COMPILE_PID=$!
  START_TS=$(date +%s)
  LAST_SIZE=-1

  while kill -0 "$COMPILE_PID" 2>/dev/null; do
    sleep 10
    if kill -0 "$COMPILE_PID" 2>/dev/null; then
      NOW_TS=$(date +%s)
      ELAPSED=$((NOW_TS - START_TS))
      if [ -f "$OUTPUT_DIR/stage3.asm" ]; then
        ASM_SIZE=$(wc -c < "$OUTPUT_DIR/stage3.asm")
      else
        ASM_SIZE=0
      fi

      if [ "$ASM_SIZE" -eq "$LAST_SIZE" ]; then
        echo "    still compiling: ${ELAPSED}s elapsed, asm=${ASM_SIZE} bytes (no change)"
      else
        echo "    still compiling: ${ELAPSED}s elapsed, asm=${ASM_SIZE} bytes"
        LAST_SIZE=$ASM_SIZE
      fi
    fi
  done

  wait "$COMPILE_PID"
else
  "$OUTPUT_DIR/stage1" < "$STAGE3_SOURCE_BIN" > "$OUTPUT_DIR/stage3.asm"
fi

log "Assembling Stage 3 compiler..."
nasm -f elf64 "$OUTPUT_DIR/stage3.asm" -o "$OUTPUT_DIR/stage3.o"
ld "$OUTPUT_DIR/stage3.o" -o "$OUTPUT_DIR/stage3"

echo "Stage 3 compiler built at output/stage3"
