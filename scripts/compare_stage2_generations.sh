#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage1"
GEN1_BIN="$OUTPUT_DIR/stage1"
GEN2_BIN="$OUTPUT_DIR/stage1_gen2"
TEST_NAMES=(
  add
  arith_vars
  basic_print
  heap
  if_eq
  if_false
  if_ge
  if_lt
  literal_print
  long_names
  mul
  read
  var_copy
  negative_let
  sub
  write_char
  write_int
  write_str
  while_count
  while_false
  while_math
)

mkdir -p "$OUTPUT_DIR"

if [ ! -x "$GEN1_BIN" ] || [ ! -x "$GEN2_BIN" ]; then
  echo "Bootstrapping Stage 2 generations first..."
  "$SCRIPT_DIR/bootstrap_stage2.sh"
fi

for test_name in "${TEST_NAMES[@]}"; do
  echo "==> $test_name"
  echo "    gen1 compile"
  python3 - <<PY | "$GEN1_BIN" > "$OUTPUT_DIR/$test_name.gen1.asm"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.ium").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  echo "    gen2 compile"
  python3 - <<PY | "$GEN2_BIN" > "$OUTPUT_DIR/$test_name.gen2.asm"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.ium").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  echo "    compare asm"
  if ! diff -u "$OUTPUT_DIR/$test_name.gen1.asm" "$OUTPUT_DIR/$test_name.gen2.asm"; then
    echo "ASM DRIFT: $test_name"
    exit 1
  fi

  echo "    gen1 run"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.gen1.asm" -o "$OUTPUT_DIR/$test_name.gen1.o"
  ld "$OUTPUT_DIR/$test_name.gen1.o" -o "$OUTPUT_DIR/$test_name.gen1"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name.gen1" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.gen1.actual"
  else
    "$OUTPUT_DIR/$test_name.gen1" > "$OUTPUT_DIR/$test_name.gen1.actual"
  fi

  echo "    gen2 run"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.gen2.asm" -o "$OUTPUT_DIR/$test_name.gen2.o"
  ld "$OUTPUT_DIR/$test_name.gen2.o" -o "$OUTPUT_DIR/$test_name.gen2"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name.gen2" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.gen2.actual"
  else
    "$OUTPUT_DIR/$test_name.gen2" > "$OUTPUT_DIR/$test_name.gen2.actual"
  fi

  echo "    compare output"
  if ! diff -u "$OUTPUT_DIR/$test_name.gen1.actual" "$OUTPUT_DIR/$test_name.gen2.actual"; then
    echo "OUTPUT DRIFT: $test_name"
    exit 1
  fi
done

echo "Stage 2 generation comparison passed."
