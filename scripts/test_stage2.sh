#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage1"
STAGE2_BIN="${STAGE2_BIN:-${STAGE1_BIN:-$OUTPUT_DIR/stage1}}"
BUILD_STAGE2="${BUILD_STAGE2:-${BUILD_STAGE1:-1}}"

VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

TEST_NAMES=(
  add
  arith_vars
  basic_print
  else_false
  else_nested
  else_true
  expr_precedence
  expr_paren_let
  expr_paren_nested
  expr_paren_print
  expr_paren_vars
  expr_vars
  heap
  if_eq
  if_expr
  if_false
  if_ge
  if_lt
  integration_condition_proc
  integration_else_expr
  integration_else_proc
  integration_heap_proc
  integration_loop_calls
  integration_while_expr_local
  integration_nested_return
  integration_proc_flow
  integration_return_output
  integration_shadow_calls
  local_args
  local_basic
  local_call_result
  local_shadow
  let_call_literal
  let_call_nested
  let_call_vars
  literal_print
  long_names
  mul
  print_call
  print_call_vars
  print_expr
  proc_args_literal
  proc_args_nested
  proc_args_vars
  proc_basic
  proc_nested
  proc_return_expr
  proc_return_literal
  proc_ret
  proc_repeat
  proc_siblings
  proc_skip_body
  read
  var_copy
  negative_let
  sub
  write_char
  write_char_expr
  write_int_call
  write_int_expr
  write_int
  write_str
  while_count
  while_expr
  while_false
  while_math
)

mkdir -p "$OUTPUT_DIR"

draw_progress() {
  local current=$1
  local total=$2
  local width=40
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))

  printf "\r["
  printf "%0.s#" $(seq 1 "$filled")
  printf "%0.s-" $(seq 1 "$empty")
  printf "] %d/%d" "$current" "$total"
}

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@"
  fi
}

if [ "$BUILD_STAGE2" = "1" ]; then
  echo "Building Stage 2 compiler..."
  "$SCRIPT_DIR/build_stage2.sh"
fi

total_tests=${#TEST_NAMES[@]}
completed=0

if [ "$VERBOSE" -eq 0 ]; then
  echo "Running Stage 1 tests..."
  draw_progress 0 "$total_tests"
fi

for test_name in "${TEST_NAMES[@]}"; do
  if [ "$VERBOSE" -eq 1 ]; then
    echo "==> $test_name"
    echo "    compile"
  fi

  python3 - <<PY | "$STAGE2_BIN" > "$OUTPUT_DIR/$test_name.asm"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.ium").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  log "    assemble"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.asm" -o "$OUTPUT_DIR/$test_name.o"

  log "    link"
  ld "$OUTPUT_DIR/$test_name.o" -o "$OUTPUT_DIR/$test_name"

  log "    run"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.actual"
  else
    "$OUTPUT_DIR/$test_name" > "$OUTPUT_DIR/$test_name.actual"
  fi

  log "    verify"
  if ! diff -u "$TEST_DIR/$test_name.out" "$OUTPUT_DIR/$test_name.actual" > /tmp/stage1_diff.$$; then
    if [ "$VERBOSE" -eq 0 ]; then echo; fi
    echo "FAILED: $test_name"
    cat /tmp/stage1_diff.$$
    rm -f /tmp/stage1_diff.$$
    exit 1
  fi

  completed=$((completed + 1))

  if [ "$VERBOSE" -eq 0 ]; then
    draw_progress "$completed" "$total_tests"
  fi
done

rm -f /tmp/stage1_diff.$$

if [ "$VERBOSE" -eq 0 ]; then
  echo
fi

echo "All Stage 2 tests passed."
