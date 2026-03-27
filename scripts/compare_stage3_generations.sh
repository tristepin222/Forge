#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage3"
GEN1_BIN="$OUTPUT_DIR/stage3"
GEN2_BIN="$OUTPUT_DIR/stage3_gen2"
DEFAULT_STAGE3_SELFHOST_SOURCE="$ROOT/stages/stage3/compiler.imp"
STAGE3_SELFHOST_SOURCE="${STAGE3_SELFHOST_SOURCE:-$DEFAULT_STAGE3_SELFHOST_SOURCE}"
STAGE3_BOOTSTRAP_READY_SENTINEL="${STAGE3_BOOTSTRAP_READY_SENTINEL:-$ROOT/stages/stage3/compiler.bootstrap-ready}"
STAGE3_BUNDLE_SCRIPT="${STAGE3_BUNDLE_SCRIPT:-$ROOT/scripts/bundle_stage3_selfhost.sh}"
TEST_NAMES=(
  basic_empty_main
  basic_function_only
)

mkdir -p "$OUTPUT_DIR"

if [ "$STAGE3_SELFHOST_SOURCE" = "$DEFAULT_STAGE3_SELFHOST_SOURCE" ] && [ -f "$STAGE3_BUNDLE_SCRIPT" ]; then
  bash "$STAGE3_BUNDLE_SCRIPT"
fi

if [ ! -f "$STAGE3_SELFHOST_SOURCE" ]; then
  echo "Stage 3 generation comparison is not available yet."
  echo "No self-hosted Stage 3 source was found at:"
  echo "  $STAGE3_SELFHOST_SOURCE"
  echo "Create that source, or set STAGE3_SELFHOST_SOURCE to another .imp compiler source first."
  exit 1
fi

if [ ! -f "$STAGE3_BOOTSTRAP_READY_SENTINEL" ]; then
  echo "Stage 3 self-host source exists, but generation comparison is not enabled yet."
  echo "Current scaffold source:"
  echo "  $STAGE3_SELFHOST_SOURCE"
  echo "Use the self-host smoke gates first:"
  echo "  ./test_stage3_selfhost_sample.sh"
  echo "  ./test_stage3_selfhost.sh"
  echo "Then make sure ./bootstrap_stage3.sh can pass the second-generation compiler smoke."
  echo "Create this marker file when the scaffold is bootstrap-ready:"
  echo "  $STAGE3_BOOTSTRAP_READY_SENTINEL"
  echo "or set STAGE3_BOOTSTRAP_READY_SENTINEL to another file."
  exit 1
fi

if [ ! -x "$GEN1_BIN" ] || [ ! -x "$GEN2_BIN" ]; then
  echo "Bootstrapping Stage 3 generations first..."
  "$SCRIPT_DIR/bootstrap_stage3.sh"
fi

for test_name in "${TEST_NAMES[@]}"; do
  echo "==> $test_name"
  echo "    gen1 compile"
  python3 - <<PY | "$GEN1_BIN" > "$OUTPUT_DIR/$test_name.stage3.gen1.asm"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.imp").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  echo "    gen2 compile"
  python3 - <<PY | "$GEN2_BIN" > "$OUTPUT_DIR/$test_name.stage3.gen2.asm"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.imp").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  echo "    compare asm"
  if ! diff -u "$OUTPUT_DIR/$test_name.stage3.gen1.asm" "$OUTPUT_DIR/$test_name.stage3.gen2.asm"; then
    echo "ASM DRIFT: $test_name"
    exit 1
  fi

  echo "    gen1 run"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.stage3.gen1.asm" -o "$OUTPUT_DIR/$test_name.stage3.gen1.o"
  ld "$OUTPUT_DIR/$test_name.stage3.gen1.o" -o "$OUTPUT_DIR/$test_name.stage3.gen1"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name.stage3.gen1" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.stage3.gen1.actual"
  else
    "$OUTPUT_DIR/$test_name.stage3.gen1" > "$OUTPUT_DIR/$test_name.stage3.gen1.actual"
  fi

  echo "    gen2 run"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.stage3.gen2.asm" -o "$OUTPUT_DIR/$test_name.stage3.gen2.o"
  ld "$OUTPUT_DIR/$test_name.stage3.gen2.o" -o "$OUTPUT_DIR/$test_name.stage3.gen2"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name.stage3.gen2" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.stage3.gen2.actual"
  else
    "$OUTPUT_DIR/$test_name.stage3.gen2" > "$OUTPUT_DIR/$test_name.stage3.gen2.actual"
  fi

  echo "    compare output"
  if ! diff -u "$OUTPUT_DIR/$test_name.stage3.gen1.actual" "$OUTPUT_DIR/$test_name.stage3.gen2.actual"; then
    echo "OUTPUT DRIFT: $test_name"
    exit 1
  fi
done

echo "Stage 3 generation comparison passed."
