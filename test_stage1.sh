#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage1"
STAGE1_BIN="${STAGE1_BIN:-$OUTPUT_DIR/stage1}"
BUILD_STAGE1="${BUILD_STAGE1:-1}"
TEST_NAMES=(
  add
  arith_vars
  basic_print
  expr_precedence
  expr_vars
  heap
  if_eq
  if_false
  if_ge
  if_lt
  literal_print
  long_names
  mul
  print_expr
  read
  var_copy
  negative_let
  sub
  write_char
  write_int_expr
  write_int
  write_str
  while_count
  while_false
  while_math
)

mkdir -p "$OUTPUT_DIR"

if [ "$BUILD_STAGE1" = "1" ]; then
  echo "Building Stage 1 compiler..."
  "$ROOT/build_stage1.sh"
fi

for test_name in "${TEST_NAMES[@]}"; do
  echo "==> $test_name"
  echo "    compile"

  python3 - <<PY | "$STAGE1_BIN" > "$OUTPUT_DIR/$test_name.asm"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.imp").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  echo "    assemble"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.asm" -o "$OUTPUT_DIR/$test_name.o"
  echo "    link"
  ld "$OUTPUT_DIR/$test_name.o" -o "$OUTPUT_DIR/$test_name"
  echo "    run"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.actual"
  else
    "$OUTPUT_DIR/$test_name" > "$OUTPUT_DIR/$test_name.actual"
  fi

  echo "    verify"
  if ! diff -u "$TEST_DIR/$test_name.out" "$OUTPUT_DIR/$test_name.actual"; then
    echo "FAILED: $test_name"
    exit 1
  fi
done

echo "All Stage 1 tests passed."
