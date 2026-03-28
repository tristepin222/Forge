#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT/stages/stage3/src/selfhost"
OUT_FILE="${STAGE3_SELFHOST_OUT_FILE:-$ROOT/stages/stage3/compiler.imp}"
SAMPLE_FILE="$SRC_DIR/sample.imp"
SAMPLE_MODE="${STAGE3_SELFHOST_SAMPLE_MODE:-stub}"
TIMING_ONLY="${TIMING_ONLY:-0}"
DEFAULT_PARTS=(
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

if [ -n "${STAGE3_SELFHOST_PARTS:-}" ]; then
  read -r -a PARTS <<< "$STAGE3_SELFHOST_PARTS"
else
  PARTS=("${DEFAULT_PARTS[@]}")
fi

mkdir -p "$(dirname "$OUT_FILE")"

tmp_file="$(mktemp)"
cleanup() {
  rm -f "$tmp_file"
  rm -f "${generated_lexer:-}"
}
trap cleanup EXIT

if [ "$SAMPLE_MODE" = "generated" ] && [ ! -f "$SAMPLE_FILE" ]; then
  echo "Missing Stage 3 self-host sample source: $SAMPLE_FILE" >&2
  exit 1
fi

if [ "$SAMPLE_MODE" = "generated" ]; then
generated_lexer="$(mktemp)"
python3 - "$SRC_DIR/23_lexer_source.imp" "$SAMPLE_FILE" "$generated_lexer" <<'PY'
from pathlib import Path
import sys

lexer_path = Path(sys.argv[1])
sample_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])

lexer = lexer_path.read_text(encoding="ascii")
sample = sample_path.read_text(encoding="ascii")
sample_bytes = sample.encode("ascii")

block_lines = [f"function source_length(self: Lexer) -> i32 => {len(sample_bytes)}", "", "function source_char_at(self: Lexer, index: i32) -> i32 {"]
for i, b in enumerate(sample_bytes):
    block_lines.append(f"    if index == {i} {{ return {b} }}")
block_lines.extend(["    return 0", "}", ""])
replacement = "\n".join(block_lines)

start_marker = "function source_length(self: Lexer) -> i32 => "
end_marker = "function peek_char(self: Lexer) -> i32 {"

start = lexer.find(start_marker)
end = lexer.find(end_marker)
if start < 0 or end < 0 or end <= start:
    raise SystemExit("Could not find lexer source block markers")

out = lexer[:start] + replacement + lexer[end:]
out_path.write_text(out, encoding="ascii")
PY
fi

for part in "${PARTS[@]}"; do
  if [ ! -f "$SRC_DIR/$part" ]; then
    echo "Missing Stage 3 self-host source part: $SRC_DIR/$part" >&2
    exit 1
  fi

  if [ "$part" = "23_lexer_source.imp" ] && [ "$SAMPLE_MODE" = "generated" ]; then
    cat "$generated_lexer" >> "$tmp_file"
  else
    cat "$SRC_DIR/$part" >> "$tmp_file"
  fi
  printf '\n\n' >> "$tmp_file"
done

if [ -f "$OUT_FILE" ] && cmp -s "$tmp_file" "$OUT_FILE"; then
  if [ "$TIMING_ONLY" != "1" ]; then
    echo "Stage 3 self-host scaffold ($SAMPLE_MODE) already up to date at ${OUT_FILE#$ROOT/}"
  fi
  exit 0
fi

mv "$tmp_file" "$OUT_FILE"
if [ "$TIMING_ONLY" != "1" ]; then
  echo "Bundled Stage 3 self-host scaffold ($SAMPLE_MODE) to ${OUT_FILE#$ROOT/}"
fi
