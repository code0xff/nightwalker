#!/bin/bash

set -euo pipefail

STATE_DIR=".claude/state"
STATE_FILE="${STATE_DIR}/autopilot-state.json"
LOG_HOOK=".claude/hooks/log-automation-event.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "autopilot-state 실패: jq가 필요합니다." >&2
  exit 2
fi

mkdir -p "$STATE_DIR"

init_state_file() {
  if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" <<'EOF'
{
  "session_id": "",
  "goal": "",
  "status": "idle",
  "current_cycle": 0,
  "last_stage": "",
  "last_gate": "",
  "last_gate_result": "",
  "updated_at": "",
  "error": "",
  "history": []
}
EOF
  fi
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

append_event() {
  local event="$1"
  local stage="$2"
  local detail="$3"
  local now
  now="$(timestamp_utc)"
  local tmp
  tmp="$(mktemp)"
  jq \
    --arg event "$event" \
    --arg stage "$stage" \
    --arg detail "$detail" \
    --arg now "$now" \
    '.history += [{"event": $event, "stage": $stage, "detail": $detail, "at": $now}] | .updated_at = $now' \
    "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"

  if [ -x "$LOG_HOOK" ]; then
    sid="$(jq -r '.session_id // ""' "$STATE_FILE" 2>/dev/null || true)"
    "$LOG_HOOK" "$event" "$stage" "$detail" "ok" "$sid" || true
  fi
}

update_state() {
  local tmp
  tmp="$(mktemp)"
  jq "$@" "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

init_state_file

ACTION="${1:-show}"
shift || true

case "$ACTION" in
  start)
    GOAL="${1:-}"
    SID="$(date +%s)-$RANDOM"
    NOW="$(timestamp_utc)"
    update_state --arg sid "$SID" --arg goal "$GOAL" --arg now "$NOW" '
      .session_id = $sid
      | .goal = $goal
      | .status = "running"
      | .current_cycle = 1
      | .last_stage = "plan"
      | .last_gate = ""
      | .last_gate_result = ""
      | .error = ""
      | .updated_at = $now
      | .history = [{"event":"start","stage":"plan","detail":"autopilot session started","at":$now}]
    '
    ;;
  cycle)
    CYCLE="${1:-0}"
    update_state --argjson cycle "$CYCLE" '.current_cycle = $cycle'
    append_event "cycle" "loop" "cycle=$CYCLE"
    ;;
  checkpoint)
    STAGE="${1:-}"
    NOTE="${2:-}"
    update_state --arg stage "$STAGE" '.last_stage = $stage'
    append_event "checkpoint" "$STAGE" "$NOTE"
    ;;
  gate)
    GATE_NAME="${1:-}"
    RESULT="${2:-}"
    DETAIL="${3:-}"
    update_state --arg gate "$GATE_NAME" --arg result "$RESULT" '
      .last_stage = "validate"
      | .last_gate = $gate
      | .last_gate_result = $result
    '
    append_event "gate" "$GATE_NAME" "$DETAIL"
    ;;
  fail)
    REASON="${1:-unknown}"
    update_state --arg reason "$REASON" '.status = "failed" | .error = $reason'
    if [ -x "$LOG_HOOK" ]; then
      sid="$(jq -r '.session_id // ""' "$STATE_FILE" 2>/dev/null || true)"
      "$LOG_HOOK" "failed" "error" "$REASON" "fail" "$sid" || true
    fi
    append_event "failed" "error" "$REASON"
    ;;
  complete)
    update_state '.status = "completed" | .error = ""'
    append_event "completed" "done" "autopilot session completed"
    ;;
  show)
    cat "$STATE_FILE"
    ;;
  *)
    echo "usage: $0 {start <goal>|cycle <n>|checkpoint <stage> [note]|gate <name> <pass|fail> [detail]|fail <reason>|complete|show}" >&2
    exit 2
    ;;
esac

exit 0
