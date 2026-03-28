#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_FILE="${STAGE3_PERF_BASELINE:-$ROOT/perf/stage3_warm_baseline.json}"
LATEST_JSON="$ROOT/output/benchmarks/stage3_benchmark_latest.json"

BENCHMARK="${BENCHMARK:-bootstrap}"
REPEAT="${REPEAT:-3}"
STAT="${STAT:-median}"
VERBOSE=0
WARN_PCT=""
WARN_ABS_MS=""
FAIL_PCT=""
FAIL_ABS_MS=""

usage() {
  cat <<'EOF'
Usage: ./check_stage3_perf.sh [--benchmark <name>] [--baseline <file>] [--repeat <n>]
                              [--stat <median|avg|min|max>] [--verbose]
                              [--warn-pct <n>] [--warn-ms <n>] [--fail-pct <n>] [--fail-ms <n>]

Defaults:
  benchmark: bootstrap
  baseline:  perf/stage3_warm_baseline.json
  repeat:    3
  stat:      median

Examples:
  ./check_stage3_perf.sh
  ./check_stage3_perf.sh --benchmark bootstrap-forced
  ./check_stage3_perf.sh --repeat 5 --stat avg
  ./check_stage3_perf.sh --warn-pct 10 --warn-ms 500
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --benchmark)
      if [ $# -lt 2 ]; then
        echo "Missing value for --benchmark"
        exit 1
      fi
      BENCHMARK="$2"
      shift 2
      ;;
    --baseline)
      if [ $# -lt 2 ]; then
        echo "Missing value for --baseline"
        exit 1
      fi
      BASELINE_FILE="$2"
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
    --stat)
      if [ $# -lt 2 ]; then
        echo "Missing value for --stat"
        exit 1
      fi
      STAT="$2"
      shift 2
      ;;
    --warn-pct)
      WARN_PCT="$2"
      shift 2
      ;;
    --warn-ms)
      WARN_ABS_MS="$2"
      shift 2
      ;;
    --fail-pct)
      FAIL_PCT="$2"
      shift 2
      ;;
    --fail-ms)
      FAIL_ABS_MS="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [ ! -f "$BASELINE_FILE" ]; then
  echo "Baseline file not found:"
  echo "  $BASELINE_FILE"
  exit 1
fi

case "$STAT" in
  median|avg|min|max)
    ;;
  *)
    echo "Unknown stat: $STAT"
    exit 1
    ;;
esac

if ! [[ "$REPEAT" =~ ^[0-9]+$ ]] || [ "$REPEAT" -lt 1 ]; then
  echo "--repeat must be a positive integer"
  exit 1
fi

BENCH_ARGS=(--only "$BENCHMARK" --timing --json --repeat "$REPEAT")
if [ "$VERBOSE" -eq 1 ]; then
  BENCH_ARGS=(--only "$BENCHMARK" --timing --json --repeat "$REPEAT" --verbose)
fi

"$SCRIPT_DIR/benchmark_stage3.sh" "${BENCH_ARGS[@]}"

python3 - "$BASELINE_FILE" "$LATEST_JSON" "$BENCHMARK" "$STAT" "$WARN_PCT" "$WARN_ABS_MS" "$FAIL_PCT" "$FAIL_ABS_MS" <<'PY'
import json
import sys
from pathlib import Path

baseline_path, latest_path, benchmark, stat_name, warn_pct_arg, warn_ms_arg, fail_pct_arg, fail_ms_arg = sys.argv[1:]

baseline = json.loads(Path(baseline_path).read_text(encoding="utf-8"))
latest = json.loads(Path(latest_path).read_text(encoding="utf-8"))

benchmarks = baseline.get("benchmarks", {})
if benchmark not in benchmarks:
    print(f"Baseline does not define benchmark: {benchmark}")
    sys.exit(1)

agg = latest.get("aggregates", {}).get(benchmark)
if not agg:
    print(f"Latest benchmark results do not contain: {benchmark}")
    sys.exit(1)

thresholds = baseline.get("thresholds", {})

def pick(cli_value: str, key: str, default: float) -> float:
    if cli_value:
        return float(cli_value)
    if key in thresholds:
        return float(thresholds[key])
    return float(default)

baseline_ms = int(benchmarks[benchmark]["elapsed_ms"])
stat_key = {
    "median": "median_ms",
    "avg": "avg_ms",
    "min": "min_ms",
    "max": "max_ms",
}[stat_name]
current_ms = int(round(float(agg[stat_key])))
delta_ms = current_ms - baseline_ms
delta_pct = 0.0
if baseline_ms > 0:
    delta_pct = (delta_ms / baseline_ms) * 100.0

warn_pct = pick(warn_pct_arg, "warn_pct", 15.0)
warn_abs_ms = pick(warn_ms_arg, "warn_abs_ms", 750.0)
fail_pct = pick(fail_pct_arg, "fail_pct", 30.0)
fail_abs_ms = pick(fail_ms_arg, "fail_abs_ms", 2000.0)

warn = delta_ms > 0 and delta_ms >= warn_abs_ms and delta_pct >= warn_pct
fail = delta_ms > 0 and delta_ms >= fail_abs_ms and delta_pct >= fail_pct

print(f"Perf baseline: {benchmark}")
print(f"  stat:     {stat_name}")
print(f"  baseline: {baseline_ms} ms")
print(f"  current:  {current_ms} ms")
print(f"  delta:    {delta_ms:+d} ms ({delta_pct:+.1f}%)")

if fail:
    print(
        f"FAIL: regression exceeds fail thresholds "
        f"({int(fail_abs_ms)} ms and {fail_pct:.1f}%)."
    )
    sys.exit(1)

if warn:
    print(
        f"WARN: regression exceeds warn thresholds "
        f"({int(warn_abs_ms)} ms and {warn_pct:.1f}%)."
    )
    sys.exit(0)

print("OK: within configured thresholds.")
sys.exit(0)
PY
