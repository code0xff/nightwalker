#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"
STATE_FILE=".claude/state/autopilot-state.json"
STATE_HOOK=".claude/hooks/autopilot-state.sh"
GATE_HOOK=".claude/hooks/run-automation-gates.sh"
QUALITY_HOOK=".claude/hooks/run-quality-gates.sh"
ENGINE_HOOK=".claude/hooks/run-engine-intent.sh"
ENGINE_READY_HOOK=".claude/hooks/check-engine-readiness.sh"
UNSET_REPORT_HOOK=".claude/hooks/report-unset-config.sh"
DONE_CHECK_HOOK=".claude/hooks/run-done-check.sh"

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
if [ ! -x "$QUALITY_HOOK" ]; then
  echo "run-autopilot 실패: $QUALITY_HOOK 실행 권한이 필요합니다." >&2
  exit 2
fi
if [ ! -x "$ENGINE_HOOK" ]; then
  echo "run-autopilot 실패: $ENGINE_HOOK 실행 권한이 필요합니다." >&2
  exit 2
fi
if [ ! -x "$ENGINE_READY_HOOK" ]; then
  echo "run-autopilot 실패: $ENGINE_READY_HOOK 실행 권한이 필요합니다." >&2
  exit 2
fi
if [ ! -x "$UNSET_REPORT_HOOK" ]; then
  echo "run-autopilot 실패: $UNSET_REPORT_HOOK 실행 권한이 필요합니다." >&2
  exit 2
fi
if [ ! -x "$DONE_CHECK_HOOK" ]; then
  echo "run-autopilot 실패: $DONE_CHECK_HOOK 실행 권한이 필요합니다." >&2
  exit 2
fi

get_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//" || true
}

infer_stage_cmd() {
  local stage="$1"
  case "$stage" in
    implement)
      local build_cmd test_cmd
      build_cmd="$(get_value build_cmd)"
      test_cmd="$(get_value test_cmd)"
      if [ -n "$build_cmd" ] && [ "$build_cmd" != "unset" ]; then
        echo "$build_cmd"
        return 0
      fi
      if [ -n "$test_cmd" ] && [ "$test_cmd" != "unset" ]; then
        echo "$test_cmd"
        return 0
      fi
      ;;
    review)
      local quality_cmd test_cmd
      quality_cmd="$(get_value quality_cmd)"
      test_cmd="$(get_value test_cmd)"
      if [ -n "$quality_cmd" ] && [ "$quality_cmd" != "unset" ]; then
        echo "$quality_cmd"
        return 0
      fi
      if [ -n "$test_cmd" ] && [ "$test_cmd" != "unset" ]; then
        echo "$test_cmd"
        return 0
      fi
      ;;
  esac
  echo "unset"
}

run_stage_cmd() {
  local stage="$1"
  local cmd="$2"
  local source="$3"
  "$STATE_HOOK" checkpoint "$stage" "${source}: ${cmd}"
  if eval "$cmd"; then
    "$STATE_HOOK" checkpoint "$stage" "ok (${source})"
    return 0
  fi
  return 1
}

run_stage_with_fallback() {
  local stage="$1"
  local cmd="$2"
  local intent="$3"
  local goal="$4"
  local inferred_cmd
  inferred_cmd="$(infer_stage_cmd "$stage")"

  export AUTOPILOT_GOAL="$goal"

  if [ "$stage" = "plan" ]; then
    if [ "$cmd" != "unset" ] && run_stage_cmd "$stage" "$cmd" "stage-cmd"; then
      return 0
    fi
    "$STATE_HOOK" checkpoint "$stage" "engine-intent: ${intent}"
    if "$ENGINE_HOOK" "$intent" "$goal"; then
      "$STATE_HOOK" checkpoint "$stage" "ok (engine-intent)"
      return 0
    fi
    if [ "$inferred_cmd" != "unset" ] && [ "$inferred_cmd" != "$cmd" ] && run_stage_cmd "$stage" "$inferred_cmd" "inferred-cmd"; then
      return 0
    fi
    "$STATE_HOOK" fail "stage=${stage}"
    return 2
  fi

  if [ "$cmd" != "unset" ] && run_stage_cmd "$stage" "$cmd" "stage-cmd"; then
    return 0
  fi
  if [ "$inferred_cmd" != "unset" ] && [ "$inferred_cmd" != "$cmd" ] && run_stage_cmd "$stage" "$inferred_cmd" "inferred-cmd"; then
    return 0
  fi
  "$STATE_HOOK" checkpoint "$stage" "engine-intent: ${intent}"
  if "$ENGINE_HOOK" "$intent" "$goal"; then
    "$STATE_HOOK" checkpoint "$stage" "ok (engine-intent)"
    return 0
  fi
  "$STATE_HOOK" fail "stage=${stage}"
  return 2
}

resolve_fix_cmd() {
  local failed_gate="$1"
  local implement_cmd="$2"
  local fix_key fix_cmd gate_cmd

  fix_key="${failed_gate}_fix_cmd"
  fix_cmd="$(get_value "$fix_key")"
  if [ -n "$fix_cmd" ] && [ "$fix_cmd" != "unset" ]; then
    echo "$fix_cmd"
    return 0
  fi

  gate_cmd="unset"
  case "$failed_gate" in
    lint) gate_cmd="$(get_value lint_cmd)" ;;
    build) gate_cmd="$(get_value build_cmd)" ;;
    test) gate_cmd="$(get_value test_cmd)" ;;
    security) gate_cmd="$(get_value security_cmd)" ;;
  esac

  if [ -n "$gate_cmd" ] && [ "$gate_cmd" != "unset" ]; then
    echo "$gate_cmd"
    return 0
  fi

  if [ -n "$implement_cmd" ] && [ "$implement_cmd" != "unset" ]; then
    echo "$implement_cmd"
    return 0
  fi

  echo ".claude/hooks/suggest-automation-gates.sh"
}

run_validate_stage() {
  local max_fix_attempts="$1"
  local implement_cmd="$2"
  "$STATE_HOOK" checkpoint "validate" "run gates"
  local attempt=1
  while [ "$attempt" -le "$max_fix_attempts" ]; do
    if "$GATE_HOOK" push; then
      return 0
    fi

    failed_gate=$(jq -r '.last_gate // ""' "$STATE_FILE")
    [ -z "$failed_gate" ] && failed_gate="unknown"
    fix_cmd="$(resolve_fix_cmd "$failed_gate" "$implement_cmd")"

    "$STATE_HOOK" checkpoint "fix" "gate=${failed_gate} attempt=${attempt} cmd=${fix_cmd}"
    if ! eval "$fix_cmd"; then
      "$STATE_HOOK" fail "stage=fix gate=${failed_gate} attempt=${attempt}"
      return 2
    fi

    attempt=$((attempt + 1))
  done

  "$STATE_HOOK" fail "stage=validate retries_exceeded"
  return 2
}

run_quality_stage() {
  "$STATE_HOOK" checkpoint "quality" "run quality gates"
  if "$QUALITY_HOOK" push; then
    "$STATE_HOOK" checkpoint "quality" "ok"
    return 0
  fi
  "$STATE_HOOK" fail "stage=quality"
  return 2
}

run_sequence_from() {
  local start_stage="$1"
  local plan_cmd="$2"
  local implement_cmd="$3"
  local review_cmd="$4"
  local goal="$5"
  local max_fix_attempts="$6"

  local stages=()
  case "$start_stage" in
    plan)
      stages=(plan implement validate review quality)
      ;;
    implement)
      stages=(implement validate review quality)
      ;;
    validate)
      stages=(validate review quality)
      ;;
    review)
      stages=(review quality)
      ;;
    quality)
      stages=(quality)
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
        run_stage_with_fallback "plan" "$plan_cmd" "plan" "$goal" || return 2
        ;;
      implement)
        run_stage_with_fallback "implement" "$implement_cmd" "build" "$goal" || return 2
        ;;
      validate)
        run_validate_stage "$max_fix_attempts" "$implement_cmd" || return 2
        ;;
      review)
        run_stage_with_fallback "review" "$review_cmd" "review" "$goal" || return 2
        ;;
      quality)
        run_quality_stage || return 2
        ;;
    esac
  done
}

ACTION="${1:-start}"
shift || true
GOAL="${*:-autopilot-goal}"
export AUTOPILOT_ACTIVE="true"

max_cycles=$(get_value "max_autopilot_cycles")
max_fix_attempts=$(get_value "max_fix_attempts_per_gate")
unset_enforcement=$(get_value "unresolved_config_enforcement")
unset_enforcement=${unset_enforcement:-report}
plan_cmd=$(get_value "plan_cmd")
implement_cmd=$(get_value "implement_cmd")
review_cmd=$(get_value "review_cmd")

cycle=1
start_stage="plan"

case "$ACTION" in
  start)
    "$ENGINE_READY_HOOK"
    "$STATE_HOOK" start "$GOAL"
    cycle=1
    start_stage="plan"
    ;;
  resume)
    "$ENGINE_READY_HOOK"
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
  if run_sequence_from "$start_stage" "$plan_cmd" "$implement_cmd" "$review_cmd" "$GOAL" "$max_fix_attempts"; then
    "$STATE_HOOK" checkpoint "done-check" "run completion contract checks"
    done_report="$("$DONE_CHECK_HOOK")"
    if [ -n "$done_report" ]; then
      echo "$done_report" >&2
    fi

    unset_report="$("$UNSET_REPORT_HOOK" || true)"
    if [ "$unset_enforcement" = "block" ] && echo "$unset_report" | grep -q '^unset_count=[1-9]'; then
      "$STATE_HOOK" fail "unset_config_blocked"
      echo "run-autopilot 실패: unresolved_config_enforcement=block 이며 unset key가 남아 있습니다." >&2
      echo "$unset_report" >&2
      exit 2
    fi
    if [ "$unset_enforcement" = "report" ] && echo "$unset_report" | grep -q '^unset_count=[1-9]'; then
      echo "run-autopilot 보고: 미확정 설정이 남아 있습니다." >&2
      echo "$unset_report" >&2
    fi
    "$STATE_HOOK" complete
    echo "run-autopilot: completed (cycle=$cycle)"
    exit 0
  fi

  cycle=$((cycle + 1))
  start_stage="$(jq -r '.last_stage // "implement"' "$STATE_FILE")"
  case "$start_stage" in
    plan|implement|validate|review|quality) ;;
    *) start_stage="implement" ;;
  esac
done

"$STATE_HOOK" fail "max_autopilot_cycles_exceeded"
echo "run-autopilot 실패: max_autopilot_cycles 초과" >&2
exit 2
