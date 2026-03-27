#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage3"
DEFAULT_STAGE3_SELFHOST_SOURCE="$ROOT/stages/stage3/compiler.imp"
STAGE3_SELFHOST_SOURCE="${STAGE3_SELFHOST_SOURCE:-$DEFAULT_STAGE3_SELFHOST_SOURCE}"
STAGE3_BOOTSTRAP_READY_SENTINEL="${STAGE3_BOOTSTRAP_READY_SENTINEL:-$ROOT/stages/stage3/compiler.bootstrap-ready}"
STAGE3_BUNDLE_SCRIPT="${STAGE3_BUNDLE_SCRIPT:-$ROOT/scripts/bundle_stage3_selfhost.sh}"
STAGE3_BOOTSTRAP_PREFLIGHT="${STAGE3_BOOTSTRAP_PREFLIGHT:-1}"
FORCE_BOOTSTRAP_GEN2="${FORCE_BOOTSTRAP_GEN2:-0}"

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

if [ "$STAGE3_SELFHOST_SOURCE" = "$DEFAULT_STAGE3_SELFHOST_SOURCE" ] && [ -f "$STAGE3_BUNDLE_SCRIPT" ]; then
  log "Bundling Stage 3 self-host scaffold..."
  bash "$STAGE3_BUNDLE_SCRIPT"
fi

if [ ! -f "$STAGE3_SELFHOST_SOURCE" ]; then
  echo "Stage 3 bootstrap is not available yet."
  echo "The current output/stage3 compiler is built from the Stage 2 source at stages/stage3/compiler.ium."
  echo "To bootstrap Stage 3, provide a self-hosted Stage 3 source file at:"
  echo "  $STAGE3_SELFHOST_SOURCE"
  echo "or set STAGE3_SELFHOST_SOURCE to another .imp compiler source."
  exit 1
fi

if [ ! -f "$STAGE3_BOOTSTRAP_READY_SENTINEL" ]; then
  echo "Stage 3 self-host source exists, but bootstrap is not enabled yet."
  echo "Current scaffold source:"
  echo "  $STAGE3_SELFHOST_SOURCE"
  echo "Bootstrap should stay gated until that source passes the current self-host smoke gates."
  echo "Use these intermediate checks first:"
  echo "  ./test_stage3_selfhost_sample.sh"
  echo "  ./test_stage3_selfhost.sh"
  echo "bootstrap_stage3.sh will rerun them automatically once you create the marker."
  echo "When it is ready, create this marker file:"
  echo "  $STAGE3_BOOTSTRAP_READY_SENTINEL"
  echo "or set STAGE3_BOOTSTRAP_READY_SENTINEL to another file."
  exit 1
fi

stage3_built=0

if [ "$STAGE3_BOOTSTRAP_PREFLIGHT" = "1" ]; then
  log "Running Stage 3 self-host bootstrap preflight..."
  if [ "$VERBOSE" -eq 1 ]; then
    "$SCRIPT_DIR/build_stage3.sh" --verbose
  else
    "$SCRIPT_DIR/build_stage3.sh"
  fi

  if [ "$VERBOSE" -eq 1 ]; then
    BUILD_STAGE3=0 "$SCRIPT_DIR/test_stage3_selfhost_sample.sh" --verbose
    BUILD_STAGE3=0 "$SCRIPT_DIR/test_stage3_selfhost.sh" --verbose
  else
    BUILD_STAGE3=0 "$SCRIPT_DIR/test_stage3_selfhost_sample.sh"
    BUILD_STAGE3=0 "$SCRIPT_DIR/test_stage3_selfhost.sh"
  fi

  stage3_built=1
fi

if [ "$stage3_built" -eq 0 ]; then
  log "Building first-generation Stage 3 compiler with Stage 2..."
  if [ "$VERBOSE" -eq 1 ]; then
    "$SCRIPT_DIR/build_stage3.sh" --verbose
  else
    "$SCRIPT_DIR/build_stage3.sh"
  fi
fi

if [ "$FORCE_BOOTSTRAP_GEN2" != "1" ] && [ -f "$OUTPUT_DIR/stage3_gen2" ]; then
  if [ "$OUTPUT_DIR/stage3_gen2" -nt "$STAGE3_SELFHOST_SOURCE" ] && [ "$OUTPUT_DIR/stage3_gen2" -nt "$OUTPUT_DIR/stage3" ]; then
    log "Second-generation Stage 3 compiler already up to date at output/stage3_gen2"
  else
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
  fi
else
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
fi

log "Running second-generation compiler smoke..."
python3 - <<PY > "$OUTPUT_DIR/stage3_gen2_smoke.source"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/basic_empty_main.imp").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

set +e
"$OUTPUT_DIR/stage3_gen2" < "$OUTPUT_DIR/stage3_gen2_smoke.source" > "$OUTPUT_DIR/stage3_gen2_smoke.asm"
smoke_status=$?
set -e

if [ "$smoke_status" -ne 0 ]; then
  echo "Stage 3 bootstrap stopped: the second-generation binary was built,"
  echo "but it does not behave like a real Stage 3 compiler yet."
  echo "Current self-host source still passes only the scaffold smoke gates."
  echo "Second-generation compiler smoke failed while compiling:"
  echo "  $TEST_DIR/basic_empty_main.imp"
  echo "Keep growing stages/stage3/compiler.imp until this smoke passes cleanly."
  exit 1
fi

if ! nasm -f elf64 "$OUTPUT_DIR/stage3_gen2_smoke.asm" -o "$OUTPUT_DIR/stage3_gen2_smoke.o" >/dev/null 2>&1; then
  echo "Stage 3 bootstrap stopped: the second-generation binary ran,"
  echo "but it did not emit valid assembly for the Stage 3 smoke input."
  echo "Current self-host source is still scaffold-level, not regression-ready."
  echo "Keep growing stages/stage3/compiler.imp until this smoke emits valid asm."
  exit 1
fi

log "Running Stage 3 regression suite with second-generation compiler..."
if [ "$VERBOSE" -eq 1 ]; then
  BUILD_STAGE3=0 STAGE3_BIN="$OUTPUT_DIR/stage3_gen2" "$SCRIPT_DIR/test_stage3.sh" --verbose
else
  BUILD_STAGE3=0 STAGE3_BIN="$OUTPUT_DIR/stage3_gen2" "$SCRIPT_DIR/test_stage3.sh"
fi

echo "Stage 3 bootstrap succeeded."
echo "First generation:  output/stage3"
echo "Second generation: output/stage3_gen2"
