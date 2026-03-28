#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
BENCH_DIR="$OUTPUT_DIR/benchmarks"

VERBOSE=0
ONLY="all"
REPEAT=1

usage() {
  cat <<'EOF'
Usage: ./benchmark_stage3.sh [--verbose] [--only <name>] [--repeat <n>]

Benchmarks:
  stage3     Force a trusted Stage 3 rebuild with the current Stage 2 compiler.
  selfhost   Force the Stage 3 self-host smoke compile using the current stage3 binary.
  bootstrap  Run the normal warm bootstrap path with current freshness checks.
  bootstrap-forced
             Force the sample smoke, self-host smoke, and gen2/bootstrap path.
  all        Run all of the above in that order.

Examples:
  ./benchmark_stage3.sh
  ./benchmark_stage3.sh --verbose
  ./benchmark_stage3.sh --only selfhost
  ./benchmark_stage3.sh --repeat 3 --only stage3
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose)
      VERBOSE=1
      shift
      ;;
    --only)
      if [ $# -lt 2 ]; then
        echo "Missing value for --only"
        exit 1
      fi
      ONLY="$2"
      shift 2
      ;;
    --repeat)
      if [ $# -lt 2 ]; then
        echo "Missing value for --repeat"
        exit 1
      fi
      REPEAT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

case "$ONLY" in
  all|stage3|selfhost|bootstrap|bootstrap-forced)
    ;;
  *)
    echo "Unknown benchmark name: $ONLY"
    usage
    exit 1
    ;;
esac

if ! [[ "$REPEAT" =~ ^[0-9]+$ ]] || [ "$REPEAT" -lt 1 ]; then
  echo "--repeat must be a positive integer"
  exit 1
fi

mkdir -p "$BENCH_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
SUMMARY_FILE="$BENCH_DIR/stage3_benchmark_$TIMESTAMP.txt"
LATEST_FILE="$BENCH_DIR/stage3_benchmark_latest.txt"

VERBOSE_ARGS=()
if [ "$VERBOSE" -eq 1 ]; then
  VERBOSE_ARGS+=(--verbose)
fi

RESULT_LINES=()

format_ms() {
  local total_ms="$1"
  local whole
  local frac
  whole=$((total_ms / 1000))
  frac=$((total_ms % 1000))
  printf "%d.%03ds" "$whole" "$frac"
}

write_summary() {
  {
    echo "Stage 3 Benchmarks"
    echo "timestamp=$TIMESTAMP"
    echo "repeat=$REPEAT"
    echo
    printf "%-12s %-8s %-12s %s\n" "benchmark" "status" "elapsed" "log"
    for line in "${RESULT_LINES[@]}"; do
      printf "%s\n" "$line"
    done
  } > "$SUMMARY_FILE"

  cp "$SUMMARY_FILE" "$LATEST_FILE"
}

run_logged() {
  local name="$1"
  local run_index="$2"
  shift 2

  local log_file="$BENCH_DIR/${TIMESTAMP}_${name}_run${run_index}.log"
  local start_ns
  local end_ns
  local elapsed_ms
  local status

  start_ns="$(date +%s%N)"

  set +e
  if [ "$VERBOSE" -eq 1 ]; then
    "$@" 2>&1 | tee "$log_file"
    status=${PIPESTATUS[0]}
  else
    "$@" > "$log_file" 2>&1
    status=$?
  fi
  set -e

  end_ns="$(date +%s%N)"
  elapsed_ms=$(((end_ns - start_ns) / 1000000))

  local elapsed_fmt
  elapsed_fmt="$(format_ms "$elapsed_ms")"

  if [ "$status" -eq 0 ]; then
    RESULT_LINES+=("$(printf "%-12s %-8s %-12s %s" "${name}#${run_index}" "ok" "$elapsed_fmt" "$log_file")")
  else
    RESULT_LINES+=("$(printf "%-12s %-8s %-12s %s" "${name}#${run_index}" "failed" "$elapsed_fmt" "$log_file")")
  fi

  write_summary

  if [ "$status" -ne 0 ]; then
    echo "Benchmark failed: ${name}#${run_index}"
    echo "Log: $log_file"
    exit "$status"
  fi
}

bench_stage3() {
  FORCE_REBUILD_STAGE3=1 "$SCRIPT_DIR/build_stage3.sh" "${VERBOSE_ARGS[@]}"
}

bench_selfhost() {
  BUILD_STAGE3=0 FORCE_SELFHOST_SMOKE=1 "$SCRIPT_DIR/test_stage3_selfhost.sh" "${VERBOSE_ARGS[@]}"
}

bench_bootstrap() {
  "$SCRIPT_DIR/bootstrap_stage3.sh" "${VERBOSE_ARGS[@]}"
}

bench_bootstrap_forced() {
  FORCE_SELFHOST_SAMPLE=1 FORCE_SELFHOST_SMOKE=1 FORCE_BOOTSTRAP_GEN2=1 "$SCRIPT_DIR/bootstrap_stage3.sh" "${VERBOSE_ARGS[@]}"
}

echo "Stage 3 benchmark run"
echo "Summary file: $SUMMARY_FILE"

run_benchmark_group() {
  local name="$1"
  local fn="$2"
  local i

  for ((i = 1; i <= REPEAT; i += 1)); do
    echo "==> $name (run $i/$REPEAT)"
    run_logged "$name" "$i" "$fn"
  done
}

if [ "$ONLY" = "all" ] || [ "$ONLY" = "stage3" ]; then
  run_benchmark_group "stage3" bench_stage3
fi

if [ "$ONLY" = "all" ] || [ "$ONLY" = "selfhost" ]; then
  run_benchmark_group "selfhost" bench_selfhost
fi

if [ "$ONLY" = "all" ] || [ "$ONLY" = "bootstrap" ]; then
  run_benchmark_group "bootstrap" bench_bootstrap
fi

if [ "$ONLY" = "bootstrap-forced" ]; then
  run_benchmark_group "bootstrap-forced" bench_bootstrap_forced
fi

echo
echo "Benchmark summary:"
cat "$SUMMARY_FILE"
