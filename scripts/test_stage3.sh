#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage3"
STAGE3_BIN="${STAGE3_BIN:-$OUTPUT_DIR/stage3}"
BUILD_STAGE3="${BUILD_STAGE3:-1}"

VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
fi

TEST_NAMES=(
  basic_empty_main
  basic_function_only
  decl_assign
  basic_print
  basic_return
  control_if_else
  control_while
  expr_arith
  expr_compound_assign
  expr_grouped
  control_if_expr
  control_if_grouped
  control_if_compare_ext
  control_while_expr
  control_while_compare_ext
  control_while_break
  control_while_continue
  control_loop_break
  control_loop_continue
  control_match_literal
  control_match_default
  control_for_range
  control_for_expr_range
  control_for_break_continue
  func_zero_arg
  func_call_expr
  func_forward_ref
  func_expr_body
  func_params
  func_methods
  func_call_arg_expr
  func_nested_call_args
  syntax_return_type
  syntax_public_import
  syntax_aliases
  syntax_private_from
  syntax_struct_enum
  syntax_class_interface
  syntax_implement_methods
  data_class_methods
  string_print_literal
  string_variable_print
  bool_literals
  data_enum_unit
  data_enum_payload
  control_match_enum
  control_match_enum_payload
  data_struct_fields
  data_struct_field_assign
  data_struct_field_compound
  data_struct_reassign
)

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@"
  fi
}

mkdir -p "$OUTPUT_DIR"

if [ "$BUILD_STAGE3" = "1" ]; then
  echo "Building Stage 3 compiler..."
  "$SCRIPT_DIR/build_stage3.sh"
fi

echo "Running Stage 3 tests..."

for test_name in "${TEST_NAMES[@]}"; do
  log "==> $test_name"
  log "    compile"
  python3 - <<PY | "$STAGE3_BIN" > "$OUTPUT_DIR/$test_name.stage3.asm"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.ium").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY

  log "    assemble"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.stage3.asm" -o "$OUTPUT_DIR/$test_name.stage3.o"

  log "    link"
  ld "$OUTPUT_DIR/$test_name.stage3.o" -o "$OUTPUT_DIR/$test_name.stage3"

  log "    run"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name.stage3" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.stage3.actual"
  else
    "$OUTPUT_DIR/$test_name.stage3" > "$OUTPUT_DIR/$test_name.stage3.actual"
  fi

  log "    verify"
  expected_file="$TEST_DIR/$test_name.out"
  if [ ! -f "$expected_file" ]; then
    expected_file=/dev/null
  fi

  if ! diff -u "$expected_file" "$OUTPUT_DIR/$test_name.stage3.actual"; then
    echo "FAILED: $test_name"
    exit 1
  fi
done

echo "All Stage 3 tests passed."
