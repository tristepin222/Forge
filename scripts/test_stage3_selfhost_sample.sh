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

show_timing() {
  if [ "$VERBOSE" -eq 1 ] || [ "$TIMING_ONLY" = "1" ]; then
    return 0
  fi
  return 1
}

now_ns() {
  date +%s%N
}

format_elapsed() {
  local start_ns="$1"
  local end_ns="$2"
  local total_ms
  local whole
  local frac
  total_ms=$(((end_ns - start_ns) / 1000000))
  whole=$((total_ms / 1000))
  frac=$((total_ms % 1000))
  printf "%d.%03ds" "$whole" "$frac"
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
  elif [ "$TIMING_ONLY" = "1" ]; then
    TIMING_ONLY=1 "$SCRIPT_DIR/build_stage3.sh" --timing
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
compile_start_ns="$(now_ns)"
if command -v timeout >/dev/null 2>&1; then
  timeout "$SELFHOST_SAMPLE_TIMEOUT" "$STAGE3_BIN" < "$OUTPUT_DIR/stage3_selfhost_sample.source" > "$OUTPUT_DIR/stage3_selfhost_sample.asm"
  status=$?
else
  "$STAGE3_BIN" < "$OUTPUT_DIR/stage3_selfhost_sample.source" > "$OUTPUT_DIR/stage3_selfhost_sample.asm"
  status=$?
fi
compile_end_ns="$(now_ns)"
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

if show_timing; then
  echo "    sample compile elapsed: $(format_elapsed "$compile_start_ns" "$compile_end_ns")"
fi

echo "Stage 3 self-host sample smoke test passed."
