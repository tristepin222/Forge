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
DEFAULT_STAGE3_SELFHOST_SAMPLE="$ROOT/stages/stage3/src/selfhost/sample.imp"
FORCE_SELFHOST_SAMPLE="${FORCE_SELFHOST_SAMPLE:-0}"
FORCE_SELFHOST_SMOKE="${FORCE_SELFHOST_SMOKE:-0}"
SELFHOST_BUNDLE_MODE="${SELFHOST_BUNDLE_MODE:-stub}"

VERBOSE=0
TEST_ONLY="${TEST_ONLY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=1
      shift
      ;;
    --only)
      if [[ $# -lt 2 ]]; then
        echo "Missing test name after --only"
        exit 1
      fi
      TEST_ONLY="$2"
      shift 2
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

SELFHOST_SMOKE_ASM="$OUTPUT_DIR/stage3_selfhost_smoke.asm"
SELFHOST_SMOKE_OBJ="$OUTPUT_DIR/stage3_selfhost_smoke.o"
SELFHOST_SMOKE_BIN="$OUTPUT_DIR/stage3_selfhost_smoke"
SELFHOST_SAMPLE_ASM="$OUTPUT_DIR/stage3_selfhost_sample.asm"
SELFHOST_RESOLVED_SMOKE_SOURCE="$STAGE3_SELFHOST_SOURCE"

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

resolve_selfhost_smoke_source() {
  SELFHOST_RESOLVED_SMOKE_SOURCE="$STAGE3_SELFHOST_SOURCE"

  if [ "$STAGE3_SELFHOST_SOURCE" = "$DEFAULT_STAGE3_SELFHOST_SOURCE" ] && [ -f "$STAGE3_BUNDLE_SCRIPT" ]; then
    SELFHOST_RESOLVED_SMOKE_SOURCE="$OUTPUT_DIR/stage3_selfhost_bundle.imp"
    log "Bundling Stage 3 self-host scaffold ($SELFHOST_BUNDLE_MODE)..."
    STAGE3_SELFHOST_SAMPLE_MODE="$SELFHOST_BUNDLE_MODE" \
    STAGE3_SELFHOST_OUT_FILE="$SELFHOST_RESOLVED_SMOKE_SOURCE" \
    bash "$STAGE3_BUNDLE_SCRIPT"
  fi
}

selfhost_sample_fresh() {
  if [ "$FORCE_SELFHOST_SAMPLE" = "1" ]; then
    return 1
  fi

  if [ ! -f "$SELFHOST_SAMPLE_ASM" ]; then
    return 1
  fi

  if [ "$SELFHOST_SAMPLE_ASM" -nt "$DEFAULT_STAGE3_SELFHOST_SAMPLE" ] && [ "$SELFHOST_SAMPLE_ASM" -nt "$OUTPUT_DIR/stage3" ]; then
    return 0
  fi

  return 1
}

selfhost_smoke_fresh() {
  if [ "$FORCE_SELFHOST_SMOKE" = "1" ]; then
    return 1
  fi

  if [ ! -f "$SELFHOST_SMOKE_ASM" ] || [ ! -f "$SELFHOST_SMOKE_OBJ" ] || [ ! -f "$SELFHOST_SMOKE_BIN" ]; then
    return 1
  fi

  if [ "$SELFHOST_SMOKE_BIN" -nt "$SELFHOST_RESOLVED_SMOKE_SOURCE" ] && [ "$SELFHOST_SMOKE_BIN" -nt "$OUTPUT_DIR/stage3" ]; then
    return 0
  fi

  return 1
}

stage3_built=0

if [ "$STAGE3_BOOTSTRAP_PREFLIGHT" = "1" ]; then
  log "Running Stage 3 self-host bootstrap preflight..."
  preflight_build_start_ns="$(now_ns)"
  if [ "$VERBOSE" -eq 1 ]; then
    "$SCRIPT_DIR/build_stage3.sh" --verbose
  else
    "$SCRIPT_DIR/build_stage3.sh"
  fi
  preflight_build_end_ns="$(now_ns)"
  if [ "$VERBOSE" -eq 1 ]; then
    echo "    preflight build elapsed: $(format_elapsed "$preflight_build_start_ns" "$preflight_build_end_ns")"
  fi

  preflight_sample_start_ns="$(now_ns)"
  if selfhost_sample_fresh; then
    echo "Stage 3 self-host sample smoke test already up to date."
  else
    if [ "$VERBOSE" -eq 1 ]; then
      BUILD_STAGE3=0 "$SCRIPT_DIR/test_stage3_selfhost_sample.sh" --verbose
    else
      BUILD_STAGE3=0 "$SCRIPT_DIR/test_stage3_selfhost_sample.sh"
    fi
  fi
  preflight_sample_end_ns="$(now_ns)"
  if [ "$VERBOSE" -eq 1 ]; then
    echo "    preflight sample elapsed: $(format_elapsed "$preflight_sample_start_ns" "$preflight_sample_end_ns")"
  fi

  resolve_selfhost_smoke_source
  preflight_smoke_start_ns="$(now_ns)"
  if selfhost_smoke_fresh; then
    echo "Stage 3 self-host smoke test already up to date."
  else
    if [ "$VERBOSE" -eq 1 ]; then
      BUILD_STAGE3=0 "$SCRIPT_DIR/test_stage3_selfhost.sh" --verbose
    else
      BUILD_STAGE3=0 "$SCRIPT_DIR/test_stage3_selfhost.sh"
    fi
  fi
  preflight_smoke_end_ns="$(now_ns)"
  if [ "$VERBOSE" -eq 1 ]; then
    echo "    preflight smoke elapsed: $(format_elapsed "$preflight_smoke_start_ns" "$preflight_smoke_end_ns")"
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

resolve_selfhost_smoke_source

reuse_smoke_gen2=0
if [ -f "$SELFHOST_SMOKE_ASM" ] && [ -f "$SELFHOST_SMOKE_OBJ" ] && [ -f "$SELFHOST_SMOKE_BIN" ]; then
  if [ "$SELFHOST_SMOKE_BIN" -nt "$SELFHOST_RESOLVED_SMOKE_SOURCE" ] && [ "$SELFHOST_SMOKE_BIN" -nt "$OUTPUT_DIR/stage3" ]; then
    reuse_smoke_gen2=1
  fi
fi

if [ "$FORCE_BOOTSTRAP_GEN2" != "1" ] && [ -f "$OUTPUT_DIR/stage3_gen2" ]; then
  if [ "$OUTPUT_DIR/stage3_gen2" -nt "$STAGE3_SELFHOST_SOURCE" ] && [ "$OUTPUT_DIR/stage3_gen2" -nt "$OUTPUT_DIR/stage3" ]; then
    log "Second-generation Stage 3 compiler already up to date at output/stage3_gen2"
  elif [ "$reuse_smoke_gen2" -eq 1 ]; then
    log "Reusing self-host smoke artifacts for second-generation Stage 3 compiler..."
    cp "$SELFHOST_SMOKE_ASM" "$OUTPUT_DIR/stage3_gen2.asm"
    cp "$SELFHOST_SMOKE_OBJ" "$OUTPUT_DIR/stage3_gen2.o"
    cp "$SELFHOST_SMOKE_BIN" "$OUTPUT_DIR/stage3_gen2"
  else
    log "Compiling self-hosted Stage 3 source with first-generation Stage 3..."
    gen2_compile_start_ns="$(now_ns)"
    python3 - <<PY | "$OUTPUT_DIR/stage3" > "$OUTPUT_DIR/stage3_gen2.asm"
from pathlib import Path
import sys
data = Path(r"$STAGE3_SELFHOST_SOURCE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY
    gen2_compile_end_ns="$(now_ns)"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "    gen2 compile elapsed: $(format_elapsed "$gen2_compile_start_ns" "$gen2_compile_end_ns")"
    fi

    log "Assembling second-generation Stage 3 compiler..."
    gen2_assemble_start_ns="$(now_ns)"
    nasm -f elf64 "$OUTPUT_DIR/stage3_gen2.asm" -o "$OUTPUT_DIR/stage3_gen2.o"
    ld "$OUTPUT_DIR/stage3_gen2.o" -o "$OUTPUT_DIR/stage3_gen2"
    gen2_assemble_end_ns="$(now_ns)"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "    gen2 assemble/link elapsed: $(format_elapsed "$gen2_assemble_start_ns" "$gen2_assemble_end_ns")"
    fi
  fi
else
  if [ "$reuse_smoke_gen2" -eq 1 ]; then
    log "Reusing self-host smoke artifacts for second-generation Stage 3 compiler..."
    cp "$SELFHOST_SMOKE_ASM" "$OUTPUT_DIR/stage3_gen2.asm"
    cp "$SELFHOST_SMOKE_OBJ" "$OUTPUT_DIR/stage3_gen2.o"
    cp "$SELFHOST_SMOKE_BIN" "$OUTPUT_DIR/stage3_gen2"
  else
    log "Compiling self-hosted Stage 3 source with first-generation Stage 3..."
    gen2_compile_start_ns="$(now_ns)"
    python3 - <<PY | "$OUTPUT_DIR/stage3" > "$OUTPUT_DIR/stage3_gen2.asm"
from pathlib import Path
import sys
data = Path(r"$STAGE3_SELFHOST_SOURCE").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY
    gen2_compile_end_ns="$(now_ns)"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "    gen2 compile elapsed: $(format_elapsed "$gen2_compile_start_ns" "$gen2_compile_end_ns")"
    fi

    log "Assembling second-generation Stage 3 compiler..."
    gen2_assemble_start_ns="$(now_ns)"
    nasm -f elf64 "$OUTPUT_DIR/stage3_gen2.asm" -o "$OUTPUT_DIR/stage3_gen2.o"
    ld "$OUTPUT_DIR/stage3_gen2.o" -o "$OUTPUT_DIR/stage3_gen2"
    gen2_assemble_end_ns="$(now_ns)"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "    gen2 assemble/link elapsed: $(format_elapsed "$gen2_assemble_start_ns" "$gen2_assemble_end_ns")"
    fi
  fi
fi

log "Running second-generation compiler smoke..."
smoke_start_ns="$(now_ns)"
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
smoke_end_ns="$(now_ns)"
if [ "$VERBOSE" -eq 1 ]; then
  echo "    gen2 smoke elapsed: $(format_elapsed "$smoke_start_ns" "$smoke_end_ns")"
fi

log "Running Stage 3 regression suite with second-generation compiler..."
regression_start_ns="$(now_ns)"
if [ "$VERBOSE" -eq 1 ]; then
  if [ -n "$TEST_ONLY" ]; then
    BUILD_STAGE3=0 STAGE3_BIN="$OUTPUT_DIR/stage3_gen2" TEST_ONLY="$TEST_ONLY" "$SCRIPT_DIR/test_stage3.sh" --verbose --only "$TEST_ONLY"
  else
    BUILD_STAGE3=0 STAGE3_BIN="$OUTPUT_DIR/stage3_gen2" "$SCRIPT_DIR/test_stage3.sh" --verbose
  fi
else
  if [ -n "$TEST_ONLY" ]; then
    BUILD_STAGE3=0 STAGE3_BIN="$OUTPUT_DIR/stage3_gen2" TEST_ONLY="$TEST_ONLY" "$SCRIPT_DIR/test_stage3.sh" --only "$TEST_ONLY"
  else
    BUILD_STAGE3=0 STAGE3_BIN="$OUTPUT_DIR/stage3_gen2" "$SCRIPT_DIR/test_stage3.sh"
  fi
fi
regression_end_ns="$(now_ns)"
if [ "$VERBOSE" -eq 1 ]; then
  echo "    regression elapsed: $(format_elapsed "$regression_start_ns" "$regression_end_ns")"
fi

echo "Stage 3 bootstrap succeeded."
echo "First generation:  output/stage3"
echo "Second generation: output/stage3_gen2"
