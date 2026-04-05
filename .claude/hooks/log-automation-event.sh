#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"
METRICS_DIR=".claude/state/metrics"
METRICS_FILE="${METRICS_DIR}/events.jsonl"

if [ ! -f "$AUTOMATION_FILE" ]; then
  exit 0
fi

get_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//" || true
}

enabled="$(get_value enable_metrics_logging)"
if [ "$enabled" != "true" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

mkdir -p "$METRICS_DIR"

event="${1:-unknown}"
stage="${2:-unknown}"
detail="${3:-}"
status="${4:-ok}"
session_id="${5:-}"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

jq -cn \
  --arg ts "$ts" \
  --arg event "$event" \
  --arg stage "$stage" \
  --arg detail "$detail" \
  --arg status "$status" \
  --arg session_id "$session_id" \
  '{ts:$ts,event:$event,stage:$stage,detail:$detail,status:$status,session_id:$session_id}' \
  >> "$METRICS_FILE"

exit 0
