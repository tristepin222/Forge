#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
TEST_DIR="$ROOT/tests/stage3"
STAGE3_BIN="${STAGE3_BIN:-$OUTPUT_DIR/stage3}"
BUILD_STAGE3="${BUILD_STAGE3:-1}"
TEST_JOBS="${TEST_JOBS:-}"
TIMING_ONLY="${TIMING_ONLY:-0}"

VERBOSE=0
TEST_ONLY="${TEST_ONLY:-}"

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
  semantic_return_bool_to_i32
  semantic_return_i32_to_bool
  semantic_return_call_i32
  semantic_return_call_bool
  semantic_return_call_bool_to_i32
  semantic_return_call_i32_to_bool
  semantic_return_import_call_i32
  semantic_return_import_call_bool
  semantic_return_import_call_bool_to_i32
  semantic_return_import_call_i32_to_bool
  semantic_return_import_method_call_i32
  semantic_return_import_method_call_bool_to_i32
  semantic_return_method_call_i32
  semantic_return_method_call_bool
  semantic_return_method_call_bool_to_i32
  semantic_return_method_call_i32_to_bool
  syntax_public_import
  syntax_import_alias
  syntax_import_group_alias
  semantic_import_len_alias
  semantic_import_group_len_alias
  semantic_import_group_builtin_aliases
  semantic_from_import_builtin_aliases
  semantic_import_group_function_alias
  semantic_from_import_function_alias
  semantic_import_group_mixed_aliases
  semantic_from_import_mixed_aliases
  semantic_import_group_method_alias
  semantic_from_import_method_alias
  syntax_aliases
  syntax_private_from
  syntax_struct_enum
  syntax_class_interface
  syntax_implement_methods
  data_class_methods
  data_array_index
  data_array_index_expr
  data_array_index_assign
  data_array_index_expr_assign
  data_array_index_compound
  data_array_index_expr_compound
  data_array_empty_assign
  data_array_len
  func_array_param
  func_array_param_expr
  func_array_param_len
  func_array_param_len_mixed
  func_array_param_assign
  func_array_param_expr_assign
  func_array_param_assign_tail
  func_array_param_expr_assign_tail
  func_array_param_compound
  func_array_param_expr_compound
  func_array_param_forward_len
  func_array_param_forward_write
  string_print_literal
  string_escape_print
  string_variable_print
  string_escape_variable
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
  local error_file
  local compile_status=0
  local had_errexit=0

  log "==> $test_name"
  log "    compile"
  error_file="$TEST_DIR/$test_name.err"
  if [[ $- == *e* ]]; then
    had_errexit=1
  fi
  set +e
  ( cat "$TEST_DIR/$test_name.imp"; printf '\0' ) | "$STAGE3_BIN" > "$OUTPUT_DIR/$test_name.stage3.asm" 2>&1
  compile_status=$?
  if [ "$had_errexit" -eq 1 ]; then
    set -e
  fi

  if [ -f "$error_file" ]; then
    if ! actual_output="$(cat "$OUTPUT_DIR/$test_name.stage3.asm")"; then
      echo "FAILED: $test_name"
      return 1
    fi
    if ! expected_output="$(cat "$error_file")"; then
      echo "FAILED: $test_name"
      return 1
    fi
    if [[ "$actual_output" != *"$expected_output"* ]]; then
      diff -u "$error_file" "$OUTPUT_DIR/$test_name.stage3.asm" || true
      echo "FAILED: $test_name"
      return 1
    fi
    return 0
  fi

  if [ "$compile_status" -ne 0 ]; then
    cat "$OUTPUT_DIR/$test_name.stage3.asm"
    echo "FAILED: $test_name"
    return 1
  fi

  log "    assemble"
  if ! nasm -f elf64 "$OUTPUT_DIR/$test_name.stage3.asm" -o "$OUTPUT_DIR/$test_name.stage3.o"; then
    echo "FAILED: $test_name"
    return 1
  fi

  log "    link"
  if ! ld "$OUTPUT_DIR/$test_name.stage3.o" -o "$OUTPUT_DIR/$test_name.stage3"; then
    echo "FAILED: $test_name"
    return 1
  fi

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

launch_test_job() {
  local test_name="$1"
  local test_log="$OUTPUT_DIR/$test_name.stage3.testlog"
  local test_status="$OUTPUT_DIR/$test_name.stage3.teststatus"

  rm -f "$test_log" "$test_status"
  (
    set +e
    run_stage3_test "$test_name"
    status=$?
    printf '%s\n' "$status" > "$test_status"
    exit "$status"
  ) > "$test_log" 2>&1 &

  active_pids+=("$!")
  active_logs+=("$test_log")
  active_statuses+=("$test_status")
}

reap_test_jobs() {
  local keep_pids=()
  local keep_logs=()
  local keep_statuses=()
  local i
  local j
  local status
  local reaped=0

  for ((i = 0; i < ${#active_pids[@]}; i += 1)); do
    if [ ! -f "${active_statuses[$i]}" ]; then
      keep_pids+=("${active_pids[$i]}")
      keep_logs+=("${active_logs[$i]}")
      keep_statuses+=("${active_statuses[$i]}")
      continue
    fi

    status="$(cat "${active_statuses[$i]}")"
    wait "${active_pids[$i]}" 2>/dev/null || true
    reaped=1

    if [ "$VERBOSE" -eq 1 ] || [ "$status" != "0" ]; then
      cat "${active_logs[$i]}"
    fi

    if [ "$status" != "0" ]; then
      for ((j = i + 1; j < ${#active_pids[@]}; j += 1)); do
        kill "${active_pids[$j]}" >/dev/null 2>&1 || true
      done
      for ((j = i + 1; j < ${#active_pids[@]}; j += 1)); do
        wait "${active_pids[$j]}" 2>/dev/null || true
      done
      active_pids=()
      active_logs=()
      active_statuses=()
      return "$status"
    fi
  done

  active_pids=("${keep_pids[@]}")
  active_logs=("${keep_logs[@]}")
  active_statuses=("${keep_statuses[@]}")

  if [ "$reaped" -eq 0 ]; then
    return 10
  fi

  return 0
}

mkdir -p "$OUTPUT_DIR"

if [ "$BUILD_STAGE3" = "1" ]; then
  if [ "$TIMING_ONLY" != "1" ]; then
    echo "Building Stage 3 compiler..."
  fi
  if [ "$TIMING_ONLY" = "1" ] && [ "$VERBOSE" -eq 0 ]; then
    TIMING_ONLY=1 "$SCRIPT_DIR/build_stage3.sh" --timing
  else
    "$SCRIPT_DIR/build_stage3.sh"
  fi
fi

if [ "$TIMING_ONLY" != "1" ]; then
  echo "Running Stage 3 tests..."
fi
suite_start_ns="$(now_ns)"

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
  if [ "$VERBOSE" -eq 1 ]; then
    echo "Using $TEST_JOBS parallel test jobs."
  fi
  active_pids=()
  active_logs=()
  active_statuses=()

  for test_name in "${SELECTED_TEST_NAMES[@]}"; do
    while [ "${#active_pids[@]}" -ge "$TEST_JOBS" ]; do
      status=0
      reap_test_jobs || status=$?
      if [ "$status" -ne 0 ]; then
        if [ "$status" -ne 10 ]; then
          exit "$status"
        fi
        sleep 0.02
      fi
    done

    launch_test_job "$test_name"
  done

  while [ "${#active_pids[@]}" -gt 0 ]; do
    status=0
    reap_test_jobs || status=$?
    if [ "$status" -ne 0 ]; then
      if [ "$status" -ne 10 ]; then
        exit "$status"
      fi
      sleep 0.02
    fi
  done
fi

suite_end_ns="$(now_ns)"
if show_timing; then
  echo "    suite elapsed: $(format_elapsed "$suite_start_ns" "$suite_end_ns")"
fi

if [ "$TIMING_ONLY" != "1" ]; then
  echo "All Stage 3 tests passed."
fi
