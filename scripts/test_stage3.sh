#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage3"
STAGE3_BIN="${STAGE3_BIN:-$OUTPUT_DIR/stage3}"
BUILD_STAGE3="${BUILD_STAGE3:-1}"
TEST_JOBS="${TEST_JOBS:-}"

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
  integration_struct_enum_flow
  integration_control_calls
  integration_class_interface_flow
)

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$@"
  fi
}

detect_test_jobs() {
  if [ -n "$TEST_JOBS" ]; then
    return
  fi

  if command -v nproc >/dev/null 2>&1; then
    TEST_JOBS="$(nproc)"
  elif command -v getconf >/dev/null 2>&1; then
    TEST_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
  else
    TEST_JOBS=1
  fi

  if ! [[ "$TEST_JOBS" =~ ^[0-9]+$ ]] || [ "$TEST_JOBS" -lt 1 ]; then
    TEST_JOBS=1
  fi

  if [ "$TEST_JOBS" -gt 4 ]; then
    TEST_JOBS=4
  fi
}

run_stage3_test() {
  local test_name="$1"
  local run_status=0
  local expected_file

  log "==> $test_name"
  log "    compile"
  python3 - <<PY > "$OUTPUT_DIR/$test_name.stage3.source"
from pathlib import Path
import sys
data = Path(r"$TEST_DIR/$test_name.imp").read_bytes()
sys.stdout.buffer.write(data + b"\0")
PY
  "$STAGE3_BIN" < "$OUTPUT_DIR/$test_name.stage3.source" > "$OUTPUT_DIR/$test_name.stage3.asm"

  log "    assemble"
  nasm -f elf64 "$OUTPUT_DIR/$test_name.stage3.asm" -o "$OUTPUT_DIR/$test_name.stage3.o"

  log "    link"
  ld "$OUTPUT_DIR/$test_name.stage3.o" -o "$OUTPUT_DIR/$test_name.stage3"

  log "    run"
  if [ -f "$TEST_DIR/$test_name.in" ]; then
    "$OUTPUT_DIR/$test_name.stage3" < "$TEST_DIR/$test_name.in" > "$OUTPUT_DIR/$test_name.stage3.actual" || run_status=$?
  else
    "$OUTPUT_DIR/$test_name.stage3" > "$OUTPUT_DIR/$test_name.stage3.actual" || run_status=$?
  fi

  if [ "$run_status" -ge 128 ]; then
    echo "FAILED: $test_name"
    echo "Runtime crashed with exit status $run_status"
    return 1
  fi

  if [ "$VERBOSE" -eq 1 ] && [ "$run_status" -ne 0 ]; then
    echo "    run exit status: $run_status"
  fi

  log "    verify"
  expected_file="$TEST_DIR/$test_name.out"
  if [ ! -f "$expected_file" ]; then
    expected_file=/dev/null
  fi

  if ! diff -u "$expected_file" "$OUTPUT_DIR/$test_name.stage3.actual"; then
    echo "FAILED: $test_name"
    return 1
  fi
}

flush_test_batch() {
  local i
  local j
  local status

  for ((i = 0; i < ${#batch_pids[@]}; i += 1)); do
    status=0
    wait "${batch_pids[$i]}" || status=$?

    if [ "$VERBOSE" -eq 1 ] || [ "$status" -ne 0 ]; then
      cat "${batch_logs[$i]}"
    fi

    if [ "$status" -ne 0 ]; then
      for ((j = i + 1; j < ${#batch_pids[@]}; j += 1)); do
        kill "${batch_pids[$j]}" >/dev/null 2>&1 || true
      done
      for ((j = i + 1; j < ${#batch_pids[@]}; j += 1)); do
        wait "${batch_pids[$j]}" 2>/dev/null || true
      done
      batch_pids=()
      batch_logs=()
      return "$status"
    fi
  done

  batch_pids=()
  batch_logs=()
  return 0
}

mkdir -p "$OUTPUT_DIR"

if [ "$BUILD_STAGE3" = "1" ]; then
  echo "Building Stage 3 compiler..."
  "$SCRIPT_DIR/build_stage3.sh"
fi

echo "Running Stage 3 tests..."

SELECTED_TEST_NAMES=("${TEST_NAMES[@]}")
if [ -n "$TEST_ONLY" ]; then
  SELECTED_TEST_NAMES=()
  for test_name in "${TEST_NAMES[@]}"; do
    if [ "$test_name" = "$TEST_ONLY" ]; then
      SELECTED_TEST_NAMES+=("$test_name")
    fi
  done

  if [ "${#SELECTED_TEST_NAMES[@]}" -eq 0 ]; then
    echo "Unknown Stage 3 test: $TEST_ONLY"
    exit 1
  fi
fi
detect_test_jobs

if [ "${#SELECTED_TEST_NAMES[@]}" -le 1 ] || [ "$TEST_JOBS" -le 1 ]; then
  for test_name in "${SELECTED_TEST_NAMES[@]}"; do
    run_stage3_test "$test_name"
  done
else
  log "Using $TEST_JOBS parallel test jobs."
  batch_pids=()
  batch_logs=()

  for test_name in "${SELECTED_TEST_NAMES[@]}"; do
    test_log="$OUTPUT_DIR/$test_name.stage3.testlog"
    rm -f "$test_log"
    ( run_stage3_test "$test_name" ) > "$test_log" 2>&1 &
    batch_pids+=("$!")
    batch_logs+=("$test_log")

    if [ "${#batch_pids[@]}" -ge "$TEST_JOBS" ]; then
      flush_test_batch
    fi
  done

  if [ "${#batch_pids[@]}" -gt 0 ]; then
    flush_test_batch
  fi
fi

echo "All Stage 3 tests passed."
