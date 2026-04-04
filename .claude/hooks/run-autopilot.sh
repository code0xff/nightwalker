#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"
STATE_FILE=".claude/state/autopilot-state.json"
STATE_HOOK=".claude/hooks/autopilot-state.sh"
GATE_HOOK=".claude/hooks/run-automation-gates.sh"

if [ ! -f "$AUTOMATION_FILE" ]; then
  echo "run-autopilot 실패: $AUTOMATION_FILE 파일이 없습니다." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "run-autopilot 실패: jq가 필요합니다." >&2
  exit 2
fi

if [ ! -x "$STATE_HOOK" ]; then
  echo "run-autopilot 실패: $STATE_HOOK 실행 권한이 필요합니다." >&2
  exit 2
fi

if [ ! -x "$GATE_HOOK" ]; then
  echo "run-autopilot 실패: $GATE_HOOK 실행 권한이 필요합니다." >&2
  exit 2
fi

get_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

run_optional_stage() {
  local stage="$1"
  local cmd="$2"
  if [ "$cmd" = "unset" ]; then
    "$STATE_HOOK" checkpoint "$stage" "skip (unset)"
    return 0
  fi

  "$STATE_HOOK" checkpoint "$stage" "run: $cmd"
  if eval "$cmd"; then
    "$STATE_HOOK" checkpoint "$stage" "ok"
    return 0
  fi
  "$STATE_HOOK" fail "stage=${stage}"
  return 2
}

run_validate_stage() {
  "$STATE_HOOK" checkpoint "validate" "run gates"
  if "$GATE_HOOK" push; then
    return 0
  fi
  "$STATE_HOOK" fail "stage=validate"
  return 2
}

run_sequence_from() {
  local start_stage="$1"
  local plan_cmd="$2"
  local implement_cmd="$3"
  local review_cmd="$4"

  local stages=()
  case "$start_stage" in
    plan)
      stages=(plan implement validate review)
      ;;
    implement)
      stages=(implement validate review)
      ;;
    validate)
      stages=(validate review)
      ;;
    review)
      stages=(review)
      ;;
    *)
      echo "run-autopilot 실패: 알 수 없는 stage='$start_stage'" >&2
      return 2
      ;;
  esac

  local stage
  for stage in "${stages[@]}"; do
    case "$stage" in
      plan)
        run_optional_stage "plan" "$plan_cmd" || return 2
        ;;
      implement)
        run_optional_stage "implement" "$implement_cmd" || return 2
        ;;
      validate)
        run_validate_stage || return 2
        ;;
      review)
        run_optional_stage "review" "$review_cmd" || return 2
        ;;
    esac
  done
}

ACTION="${1:-start}"
shift || true
GOAL="${*:-autopilot-goal}"

max_cycles=$(get_value "max_autopilot_cycles")
plan_cmd=$(get_value "plan_cmd")
implement_cmd=$(get_value "implement_cmd")
review_cmd=$(get_value "review_cmd")

cycle=1
start_stage="plan"

case "$ACTION" in
  start)
    "$STATE_HOOK" start "$GOAL"
    cycle=1
    start_stage="plan"
    ;;
  resume)
    if [ ! -f "$STATE_FILE" ]; then
      echo "run-autopilot 실패: resume 대상 상태 파일이 없습니다." >&2
      exit 2
    fi
    status=$(jq -r '.status // "idle"' "$STATE_FILE")
    if [ "$status" = "completed" ]; then
      echo "run-autopilot: 이미 completed 상태입니다."
      exit 0
    fi
    cycle=$(jq -r '.current_cycle // 1' "$STATE_FILE")
    last_stage=$(jq -r '.last_stage // "plan"' "$STATE_FILE")
    if [ -z "$last_stage" ] || [ "$last_stage" = "null" ]; then
      last_stage="plan"
    fi
    start_stage="$last_stage"
    ;;
  *)
    echo "usage: $0 {start <goal>|resume}" >&2
    exit 2
    ;;
esac

while [ "$cycle" -le "$max_cycles" ]; do
  "$STATE_HOOK" cycle "$cycle"
  if run_sequence_from "$start_stage" "$plan_cmd" "$implement_cmd" "$review_cmd"; then
    "$STATE_HOOK" complete
    echo "run-autopilot: completed (cycle=$cycle)"
    exit 0
  fi

  cycle=$((cycle + 1))
  start_stage="$(jq -r '.last_stage // "implement"' "$STATE_FILE")"
  case "$start_stage" in
    plan|implement|validate|review) ;;
    *) start_stage="implement" ;;
  esac
done

"$STATE_HOOK" fail "max_autopilot_cycles_exceeded"
echo "run-autopilot 실패: max_autopilot_cycles 초과" >&2
exit 2
