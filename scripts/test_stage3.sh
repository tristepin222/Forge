#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage3"
STAGE3_BIN="${STAGE3_BIN:-$OUTPUT_DIR/stage3}"
BUILD_STAGE3="${BUILD_STAGE3:-1}"

VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

TEST_NAMES=(
  smoke_main
)

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@"
  fi
}

mkdir -p "$OUTPUT_DIR"

if [ "$BUILD_STAGE3" = "1" ]; then
  echo "Building Stage 3 compiler..."
  "$SCRIPT_DIR/build_stage3.sh"
fi

echo "Running Stage 3 tests..."

for test_name in "${TEST_NAMES[@]}"; do
  log "==> $test_name"
  log "    compile"
  python3 - <<PY | "$STAGE3_BIN" > "$OUTPUT_DIR/$test_name.stage3.asm"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.ium").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  log "    assemble"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.stage3.asm" -o "$OUTPUT_DIR/$test_name.stage3.o"

  log "    link"
  ld "$OUTPUT_DIR/$test_name.stage3.o" -o "$OUTPUT_DIR/$test_name.stage3"

  log "    run"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name.stage3" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.stage3.actual"
  else
    "$OUTPUT_DIR/$test_name.stage3" > "$OUTPUT_DIR/$test_name.stage3.actual"
  fi

  log "    verify"
  if ! diff -u "$TEST_DIR/$test_name.out" "$OUTPUT_DIR/$test_name.stage3.actual"; then
    echo "FAILED: $test_name"
    exit 1
  fi
done

echo "All Stage 3 tests passed."
