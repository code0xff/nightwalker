#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"

if [ ! -f "$AUTOMATION_FILE" ]; then
  echo "project-automation 검증 실패: $AUTOMATION_FILE 파일이 없습니다." >&2
  echo "프로젝트 시작 시 자동화 프로파일을 먼저 정의하세요." >&2
  exit 2
fi

required_keys=(
  "automation_mode"
  "allow_midway_user_prompt"
  "final_report_only"
  "max_fix_attempts_per_gate"
  "max_autopilot_cycles"
  "lint_cmd"
  "build_cmd"
  "test_cmd"
  "security_cmd"
  "run_gates_on_commit"
  "run_gates_on_push"
  "auto_apply_risk_tier"
  "require_user_for_risk_tier"
)

for key in "${required_keys[@]}"; do
  if ! grep -Eq "^- ${key}:[[:space:]]*.+" "$AUTOMATION_FILE"; then
    echo "project-automation 검증 실패: '${key}' 값이 없습니다." >&2
    exit 2
  fi
done

get_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

automation_mode=$(get_value "automation_mode")
if [ "$automation_mode" != "full-auto" ] && [ "$automation_mode" != "assisted-auto" ]; then
  echo "project-automation 검증 실패: automation_mode는 full-auto 또는 assisted-auto여야 합니다." >&2
  exit 2
fi

for bool_key in allow_midway_user_prompt final_report_only run_gates_on_commit run_gates_on_push; do
  val=$(get_value "$bool_key")
  if [ "$val" != "true" ] && [ "$val" != "false" ]; then
    echo "project-automation 검증 실패: ${bool_key}는 true 또는 false여야 합니다." >&2
    exit 2
  fi
done

for int_key in max_fix_attempts_per_gate max_autopilot_cycles; do
  val=$(get_value "$int_key")
  if ! echo "$val" | grep -Eq '^[0-9]+$'; then
    echo "project-automation 검증 실패: ${int_key}는 정수여야 합니다." >&2
    exit 2
  fi
done

exit 0
