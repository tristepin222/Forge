#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage0"
PROGRAM_FILE="$ROOT/program.imp"
BACKUP_FILE="$OUTPUT_DIR/program.imp.bak"
TEST_NAMES=(
  arithmetic
  control
  heap
  nested_if
  nested_while
  sibling_ifs
  negative_literals
  raw_output
  read_byte
  write_int_raw
)

mkdir -p "$OUTPUT_DIR"

restore_program() {
  if [ -f "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "$PROGRAM_FILE"
  fi
}

trap restore_program EXIT

cp "$PROGRAM_FILE" "$BACKUP_FILE"

echo "Compiling compiler..."
nasm -f elf64 "$ROOT/compiler.asm" -o "$OUTPUT_DIR/compiler.o"
ld "$OUTPUT_DIR/compiler.o" -o "$OUTPUT_DIR/compiler"

for test_name in "${TEST_NAMES[@]}"; do
  echo "==> $test_name"
  cp "$TEST_DIR/$test_name.imp" "$PROGRAM_FILE"

  "$OUTPUT_DIR/compiler"
  nasm -f elf64 "$OUTPUT_DIR/program.asm" -o "$OUTPUT_DIR/$test_name.o"
  ld "$OUTPUT_DIR/$test_name.o" -o "$OUTPUT_DIR/$test_name"

  actual_file="$OUTPUT_DIR/$test_name.actual"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name" < "$TEST_DIR/$test_name.in" > "$actual_file"
  else
    "$OUTPUT_DIR/$test_name" > "$actual_file"
  fi

  if ! diff -u "$TEST_DIR/$test_name.out" "$actual_file"; then
    echo "FAILED: $test_name"
    exit 1
  fi
done

echo "All Stage 0 tests passed."
