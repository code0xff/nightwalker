#!/bin/bash

set -euo pipefail

METRICS_FILE=".claude/state/metrics/events.jsonl"
OUT_FILE=".claude/state/metrics/summary.txt"

if ! command -v jq >/dev/null 2>&1; then
  echo "metrics report 실패: jq가 필요합니다." >&2
  exit 2
fi

if [ ! -f "$METRICS_FILE" ]; then
  echo "metrics report: events file not found"
  exit 0
fi

total=$(wc -l < "$METRICS_FILE" | awk '{print $1}')
failed=$(jq -r 'select(.status=="fail") | 1' "$METRICS_FILE" | wc -l | awk '{print $1}')
passed=$((total - failed))

stage_counts=$(jq -r '.stage' "$METRICS_FILE" | sort | uniq -c | awk '{print $2 ":" $1}')
latest_ts=$(tail -n 1 "$METRICS_FILE" | jq -r '.ts')

mkdir -p "$(dirname "$OUT_FILE")"
{
  echo "Automation Metrics Summary"
  echo "total_events=$total"
  echo "passed_events=$passed"
  echo "failed_events=$failed"
  echo "latest_ts=$latest_ts"
  echo "stage_counts="
  echo "$stage_counts"
} > "$OUT_FILE"

cat "$OUT_FILE"
exit 0
