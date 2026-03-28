#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
PROGRAM_FILE="$ROOT/program.ium"
STAGE2_SOURCE="$ROOT/stages/stage2/compiler.ium"
STAGE0_SOURCE="$ROOT/stages/stage0/compiler.asm"
BACKUP_FILE="$OUTPUT_DIR/program.ium.stage2.bak"
FORCE_REBUILD_STAGE2="${FORCE_REBUILD_STAGE2:-0}"
TIMING_ONLY="${TIMING_ONLY:-0}"

VERBOSE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=1
      shift
      ;;
    --timing)
      TIMING_ONLY=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@"
  fi
}

mkdir -p "$OUTPUT_DIR"

if [ "$FORCE_REBUILD_STAGE2" != "1" ] && [ -f "$OUTPUT_DIR/stage1" ]; then
  if [ "$OUTPUT_DIR/stage1" -nt "$STAGE2_SOURCE" ] && [ "$OUTPUT_DIR/stage1" -nt "$STAGE0_SOURCE" ]; then
    if [ "$TIMING_ONLY" != "1" ]; then
      echo "Stage 2 compiler already up to date at output/stage1"
    fi
    exit 0
  fi
fi

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
cp "$STAGE2_SOURCE" "$PROGRAM_FILE"

log "Compiling Stage 0 compiler..."
nasm -f elf64 "$STAGE0_SOURCE" -o "$OUTPUT_DIR/compiler.o"
ld "$OUTPUT_DIR/compiler.o" -o "$OUTPUT_DIR/compiler"

log "Running Stage 0 on stages/stage2/compiler.ium..."
"$OUTPUT_DIR/compiler"

mv "$OUTPUT_DIR/program.asm" "$OUTPUT_DIR/stage1.asm"

log "Assembling Stage 2 compiler..."
nasm -f elf64 "$OUTPUT_DIR/stage1.asm" -o "$OUTPUT_DIR/stage1.o"
ld "$OUTPUT_DIR/stage1.o" -o "$OUTPUT_DIR/stage1"

if [ "$TIMING_ONLY" != "1" ]; then
  echo "Stage 2 compiler built at output/stage1"
fi
