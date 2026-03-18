#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$ROOT/output"
PROGRAM_FILE="$ROOT/program.imp"
STAGE1_SOURCE="$ROOT/stage1.imp"
BACKUP_FILE="$OUTPUT_DIR/program.imp.stage1.bak"
HAD_PROGRAM_FILE=0

mkdir -p "$OUTPUT_DIR"

restore_program() {
  if [ -f "$BACKUP_FILE" ]; then
    mv "$BACKUP_FILE" "$PROGRAM_FILE"
  elif [ -f "$PROGRAM_FILE" ]; then
    rm -f "$PROGRAM_FILE"
  fi
}

trap restore_program EXIT

if [ -f "$PROGRAM_FILE" ]; then
  cp "$PROGRAM_FILE" "$BACKUP_FILE"
fi
cp "$STAGE1_SOURCE" "$PROGRAM_FILE"

echo "Compiling Stage 0 compiler..."
nasm -f elf64 "$ROOT/compiler.asm" -o "$OUTPUT_DIR/compiler.o"
ld "$OUTPUT_DIR/compiler.o" -o "$OUTPUT_DIR/compiler"

echo "Running Stage 0 on stage1.imp..."
"$OUTPUT_DIR/compiler"

mv "$OUTPUT_DIR/program.asm" "$OUTPUT_DIR/stage1.asm"

echo "Assembling Stage 1 compiler..."
nasm -f elf64 "$OUTPUT_DIR/stage1.asm" -o "$OUTPUT_DIR/stage1.o"
ld "$OUTPUT_DIR/stage1.o" -o "$OUTPUT_DIR/stage1"

echo "Stage 1 compiler built at output/stage1"
