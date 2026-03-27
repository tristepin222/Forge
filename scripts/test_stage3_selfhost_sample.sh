#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
DEFAULT_STAGE3_SELFHOST_SAMPLE="$ROOT/stages/stage3/src/selfhost/sample.imp"
STAGE3_SELFHOST_SAMPLE="${STAGE3_SELFHOST_SAMPLE:-$DEFAULT_STAGE3_SELFHOST_SAMPLE}"
STAGE3_BIN="${STAGE3_BIN:-$OUTPUT_DIR/stage3}"
BUILD_STAGE3="${BUILD_STAGE3:-1}"
SELFHOST_SAMPLE_TIMEOUT="${SELFHOST_SAMPLE_TIMEOUT:-60}"
FORCE_SELFHOST_SAMPLE="${FORCE_SELFHOST_SAMPLE:-0}"

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

if [ ! -f "$STAGE3_SELFHOST_SAMPLE" ]; then
  echo "Stage 3 self-host sample source not found:"
  echo "  $STAGE3_SELFHOST_SAMPLE"
  echo "Set STAGE3_SELFHOST_SAMPLE to another .imp sample if needed."
  exit 1
fi

if [ "$BUILD_STAGE3" = "1" ]; then
  echo "Building Stage 3 compiler..."
  if [ "$VERBOSE" -eq 1 ]; then
    "$SCRIPT_DIR/build_stage3.sh" --verbose
  else
    "$SCRIPT_DIR/build_stage3.sh"
  fi
fi

echo "Running Stage 3 self-host sample smoke test..."

log "    compile self-host sample"
python3 - <<PY > "$OUTPUT_DIR/stage3_selfhost_sample.source"
from pathlib import Path
import sys
data = Path(r"$STAGE3_SELFHOST_SAMPLE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

if [ "$FORCE_SELFHOST_SAMPLE" != "1" ] && [ -f "$OUTPUT_DIR/stage3_selfhost_sample.asm" ]; then
  if [ "$OUTPUT_DIR/stage3_selfhost_sample.asm" -nt "$STAGE3_SELFHOST_SAMPLE" ] && [ "$OUTPUT_DIR/stage3_selfhost_sample.asm" -nt "$STAGE3_BIN" ]; then
    echo "Stage 3 self-host sample smoke test already up to date."
    exit 0
  fi
fi

set +e
if command -v timeout >/dev/null 2>&1; then
  timeout "$SELFHOST_SAMPLE_TIMEOUT" "$STAGE3_BIN" < "$OUTPUT_DIR/stage3_selfhost_sample.source" > "$OUTPUT_DIR/stage3_selfhost_sample.asm"
  status=$?
else
  "$STAGE3_BIN" < "$OUTPUT_DIR/stage3_selfhost_sample.source" > "$OUTPUT_DIR/stage3_selfhost_sample.asm"
  status=$?
fi
set -e

if [ "$status" -eq 124 ]; then
  echo "FAILED: stage3_selfhost_sample"
  echo "Compile step timed out after ${SELFHOST_SAMPLE_TIMEOUT}s."
  echo "This sample is much smaller than stages/stage3/compiler.imp,"
  echo "so a timeout here points to a real parser/codegen problem in stages/stage3/compiler.ium."
  exit 1
fi

if [ "$status" -ne 0 ]; then
  echo "FAILED: stage3_selfhost_sample"
  echo "Stage 3 compiler exited with status $status while compiling:"
  echo "  $STAGE3_SELFHOST_SAMPLE"
  exit 1
fi

echo "Stage 3 self-host sample smoke test passed."
