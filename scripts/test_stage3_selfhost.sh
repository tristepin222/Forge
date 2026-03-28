#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
DEFAULT_STAGE3_SELFHOST_SOURCE="$ROOT/stages/stage3/compiler.imp"
STAGE3_SELFHOST_SOURCE="${STAGE3_SELFHOST_SOURCE:-$DEFAULT_STAGE3_SELFHOST_SOURCE}"
STAGE3_BUNDLE_SCRIPT="${STAGE3_BUNDLE_SCRIPT:-$ROOT/scripts/bundle_stage3_selfhost.sh}"
STAGE3_BIN="${STAGE3_BIN:-$OUTPUT_DIR/stage3}"
BUILD_STAGE3="${BUILD_STAGE3:-1}"
SELFHOST_COMPILE_TIMEOUT="${SELFHOST_COMPILE_TIMEOUT:-300}"
SELFHOST_BUNDLE_MODE="${SELFHOST_BUNDLE_MODE:-stub}"
FORCE_SELFHOST_SMOKE="${FORCE_SELFHOST_SMOKE:-0}"
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

if [ "$STAGE3_SELFHOST_SOURCE" = "$DEFAULT_STAGE3_SELFHOST_SOURCE" ] && [ -f "$STAGE3_BUNDLE_SCRIPT" ]; then
  STAGE3_SELFHOST_SOURCE="$OUTPUT_DIR/stage3_selfhost_bundle.imp"
  log "Bundling Stage 3 self-host scaffold ($SELFHOST_BUNDLE_MODE)..."
  STAGE3_SELFHOST_SAMPLE_MODE="$SELFHOST_BUNDLE_MODE" \
  STAGE3_SELFHOST_OUT_FILE="$STAGE3_SELFHOST_SOURCE" \
  bash "$STAGE3_BUNDLE_SCRIPT"
fi

if [ ! -f "$STAGE3_SELFHOST_SOURCE" ]; then
  echo "Stage 3 self-host smoke test source not found:"
  echo "  $STAGE3_SELFHOST_SOURCE"
  echo "Set STAGE3_SELFHOST_SOURCE to another .imp source if needed."
  exit 1
fi

if [ "$BUILD_STAGE3" = "1" ]; then
  if [ "$TIMING_ONLY" != "1" ]; then
    echo "Building Stage 3 compiler..."
  fi
  if [ "$VERBOSE" -eq 1 ]; then
    "$SCRIPT_DIR/build_stage3.sh" --verbose
  elif [ "$TIMING_ONLY" = "1" ]; then
    TIMING_ONLY=1 "$SCRIPT_DIR/build_stage3.sh" --timing
  else
    "$SCRIPT_DIR/build_stage3.sh"
  fi
fi

if [ "$TIMING_ONLY" != "1" ]; then
  echo "Running Stage 3 self-host smoke test..."
fi

log "    compile self-host source"
python3 - <<PY > "$OUTPUT_DIR/stage3_selfhost_smoke.source"
from pathlib import Path
import sys
data = Path(r"$STAGE3_SELFHOST_SOURCE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

if [ "$FORCE_SELFHOST_SMOKE" != "1" ] && [ -f "$OUTPUT_DIR/stage3_selfhost_smoke" ]; then
  if [ "$OUTPUT_DIR/stage3_selfhost_smoke" -nt "$STAGE3_SELFHOST_SOURCE" ] && [ "$OUTPUT_DIR/stage3_selfhost_smoke" -nt "$STAGE3_BIN" ]; then
    if [ "$TIMING_ONLY" != "1" ]; then
      echo "Stage 3 self-host smoke test already up to date."
    fi
    exit 0
  fi
fi

set +e
asm_out="$OUTPUT_DIR/stage3_selfhost_smoke.asm"
rm -f "$asm_out"

if [ "$VERBOSE" -eq 1 ]; then
  bundle_size=$(python3 - <<PY
from pathlib import Path
print(Path(r"$STAGE3_SELFHOST_SOURCE").stat().st_size)
PY
)
  echo "    bundle size: ${bundle_size} bytes"
fi

if command -v timeout >/dev/null 2>&1; then
  compile_start_ns="$(now_ns)"
  timeout "$SELFHOST_COMPILE_TIMEOUT" "$STAGE3_BIN" < "$OUTPUT_DIR/stage3_selfhost_smoke.source" > "$asm_out" &
else
  compile_start_ns="$(now_ns)"
  "$STAGE3_BIN" < "$OUTPUT_DIR/stage3_selfhost_smoke.source" > "$asm_out" &
fi
compile_pid=$!

monitor_pid=""
if [ "$VERBOSE" -eq 1 ]; then
  (
    start_ts=$(date +%s)
    last_size=-1
    while kill -0 "$compile_pid" >/dev/null 2>&1; do
      sleep 10
      if [ -f "$asm_out" ]; then
        size=$(python3 - <<PY
from pathlib import Path
print(Path(r"$asm_out").stat().st_size)
PY
)
      else
        size=0
      fi
      now_ts=$(date +%s)
      elapsed=$((now_ts - start_ts))
      if [ "$size" = "$last_size" ]; then
        echo "    still compiling: ${elapsed}s elapsed, asm=${size} bytes (no change)"
      else
        echo "    still compiling: ${elapsed}s elapsed, asm=${size} bytes"
      fi
      last_size=$size
    done
  ) &
  monitor_pid=$!
fi

wait "$compile_pid"
status=$?
compile_end_ns="$(now_ns)"

if [ -n "$monitor_pid" ]; then
  kill "$monitor_pid" >/dev/null 2>&1 || true
  wait "$monitor_pid" 2>/dev/null || true
fi
set -e

if [ "$status" -eq 124 ]; then
  echo "FAILED: stage3_selfhost_smoke"
  echo "Compile step timed out after ${SELFHOST_COMPILE_TIMEOUT}s."
  echo "Current bundle mode: $SELFHOST_BUNDLE_MODE"
  echo "Run ./test_stage3_selfhost_sample.sh first to verify the smaller self-host syntax slice."
  exit 1
fi

if [ "$status" -ne 0 ]; then
  echo "FAILED: stage3_selfhost_smoke"
  echo "Stage 3 compiler exited with status $status while compiling:"
  echo "  $STAGE3_SELFHOST_SOURCE"
  exit 1
fi

if show_timing; then
  echo "    compile elapsed: $(format_elapsed "$compile_start_ns" "$compile_end_ns")"
fi

log "    assemble"
assemble_start_ns="$(now_ns)"
nasm -f elf64 "$OUTPUT_DIR/stage3_selfhost_smoke.asm" -o "$OUTPUT_DIR/stage3_selfhost_smoke.o"
assemble_end_ns="$(now_ns)"
if show_timing; then
  echo "    assemble elapsed: $(format_elapsed "$assemble_start_ns" "$assemble_end_ns")"
fi

log "    link"
link_start_ns="$(now_ns)"
ld "$OUTPUT_DIR/stage3_selfhost_smoke.o" -o "$OUTPUT_DIR/stage3_selfhost_smoke"
link_end_ns="$(now_ns)"
if show_timing; then
  echo "    link elapsed: $(format_elapsed "$link_start_ns" "$link_end_ns")"
fi

if [ "$TIMING_ONLY" != "1" ]; then
  echo "Stage 3 self-host smoke test passed."
fi
