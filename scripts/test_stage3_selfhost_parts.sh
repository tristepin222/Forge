#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
STAGE3_BIN="${STAGE3_BIN:-$OUTPUT_DIR/stage3}"
BUNDLE_SCRIPT="${BUNDLE_SCRIPT:-$ROOT/scripts/bundle_stage3_selfhost.sh}"
PART_TIMEOUT="${PART_TIMEOUT:-120}"
SELFHOST_BUNDLE_MODE="${SELFHOST_BUNDLE_MODE:-stub}"
PARTS=(
  00_module.imp
  10_tokens.imp
  20_state.imp
  21_lexer_hash.imp
  21a_lexer_space.imp
  21b_lexer_digit.imp
  22_lexer_ident.imp
  23_lexer_source.imp
  24_lexer_scan.imp
  25_lexer_tokens.imp
  30_pipeline_stubs.imp
  35_parser.imp
  40_main.imp
)

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

echo "Building Stage 3 compiler..."
"$SCRIPT_DIR/build_stage3.sh"

echo "Running Stage 3 self-host part smoke..."

cumulative=()
for part in "${PARTS[@]}"; do
  cumulative+=("$part")
  part_label="${part%.imp}"
  bundle_path="$OUTPUT_DIR/stage3_selfhost_${part_label}.imp"
  source_path="$OUTPUT_DIR/stage3_selfhost_${part_label}.source"
  asm_path="$OUTPUT_DIR/stage3_selfhost_${part_label}.asm"

  echo "==> $part_label"
  log "    bundling: ${cumulative[*]}"
  STAGE3_SELFHOST_SAMPLE_MODE="$SELFHOST_BUNDLE_MODE" \
  STAGE3_SELFHOST_OUT_FILE="$bundle_path" \
  STAGE3_SELFHOST_PARTS="${cumulative[*]}" \
  bash "$BUNDLE_SCRIPT" >/dev/null

  python3 - <<PY > "$source_path"
from pathlib import Path
import sys
data = Path(r"$bundle_path").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  if [ "$VERBOSE" -eq 1 ]; then
    bundle_size=$(python3 - <<PY
from pathlib import Path
print(Path(r"$bundle_path").stat().st_size)
PY
)
    echo "    bundle size: ${bundle_size} bytes"
  fi

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "$PART_TIMEOUT" "$STAGE3_BIN" < "$source_path" > "$asm_path"
    status=$?
  else
    "$STAGE3_BIN" < "$source_path" > "$asm_path"
    status=$?
  fi
  set -e

  if [ "$status" -eq 124 ]; then
    echo "FAILED: $part_label"
    echo "Timed out after ${PART_TIMEOUT}s while compiling bundle prefix ending at:"
    echo "  $part"
    exit 1
  fi

  if [ "$status" -ne 0 ]; then
    echo "FAILED: $part_label"
    echo "Stage 3 compiler exited with status $status while compiling bundle prefix ending at:"
    echo "  $part"
    exit 1
  fi

  log "    compile ok"
done

echo "Stage 3 self-host part smoke test passed."
