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
  "allow_auto_push"
  "engine_runtime_mode"
  "allow_engine_stub"
  "execute_engine_commands"
  "max_fix_attempts_per_gate"
  "max_autopilot_cycles"
  "plan_cmd"
  "implement_cmd"
  "review_cmd"
  "engine_cmd_codex"
  "engine_cmd_claude"
  "engine_cmd_openai"
  "engine_cmd_cursor"
  "engine_cmd_gemini"
  "engine_cmd_copilot"
  "lint_fix_cmd"
  "build_fix_cmd"
  "test_fix_cmd"
  "security_fix_cmd"
  "lint_cmd"
  "build_cmd"
  "test_cmd"
  "security_cmd"
  "run_gates_on_commit"
  "run_gates_on_push"
  "run_quality_on_commit"
  "run_quality_on_push"
  "enable_quality_gates"
  "quality_cmd"
  "quality_coverage_cmd"
  "quality_perf_cmd"
  "quality_architecture_cmd"
  "release_mode"
  "allow_auto_release"
  "require_clean_worktree_before_release"
  "deploy_cmd"
  "verify_release_cmd"
  "rollback_cmd"
  "release_smoke_cmd"
  "release_verify_retries"
  "release_verify_interval_sec"
  "enable_metrics_logging"
  "metrics_report_on_complete"
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

for bool_key in allow_midway_user_prompt final_report_only run_gates_on_commit run_gates_on_push run_quality_on_commit run_quality_on_push enable_quality_gates allow_engine_stub execute_engine_commands allow_auto_release require_clean_worktree_before_release enable_metrics_logging metrics_report_on_complete; do
  val=$(get_value "$bool_key")
  if [ "$val" != "true" ] && [ "$val" != "false" ]; then
    echo "project-automation 검증 실패: ${bool_key}는 true 또는 false여야 합니다." >&2
    exit 2
  fi
done

allow_auto_push=$(get_value "allow_auto_push")
if [ "$allow_auto_push" != "true" ] && [ "$allow_auto_push" != "false" ]; then
  echo "project-automation 검증 실패: allow_auto_push는 true 또는 false여야 합니다." >&2
  exit 2
fi
if [ "$automation_mode" = "full-auto" ] && [ "$allow_auto_push" != "true" ]; then
  echo "project-automation 검증 실패: full-auto 모드에서는 allow_auto_push=true가 필요합니다." >&2
  exit 2
fi

engine_runtime_mode=$(get_value "engine_runtime_mode")
if [ "$engine_runtime_mode" != "stub-fallback" ] && [ "$engine_runtime_mode" != "strict" ]; then
  echo "project-automation 검증 실패: engine_runtime_mode는 stub-fallback 또는 strict여야 합니다." >&2
  exit 2
fi
allow_engine_stub=$(get_value "allow_engine_stub")
if [ "$engine_runtime_mode" = "strict" ] && [ "$allow_engine_stub" != "false" ]; then
  echo "project-automation 검증 실패: strict 모드에서는 allow_engine_stub=false여야 합니다." >&2
  exit 2
fi

enable_quality_gates=$(get_value "enable_quality_gates")
quality_cmd=$(get_value "quality_cmd")
if [ "$enable_quality_gates" = "true" ] && [ "$quality_cmd" = "unset" ]; then
  echo "project-automation 검증 실패: enable_quality_gates=true 일 때 quality_cmd=unset은 허용되지 않습니다." >&2
  exit 2
fi

release_mode=$(get_value "release_mode")
if [ "$release_mode" != "disabled" ] && [ "$release_mode" != "manual" ] && [ "$release_mode" != "auto" ]; then
  echo "project-automation 검증 실패: release_mode는 disabled/manual/auto 중 하나여야 합니다." >&2
  exit 2
fi
allow_auto_release=$(get_value "allow_auto_release")
deploy_cmd=$(get_value "deploy_cmd")
verify_release_cmd=$(get_value "verify_release_cmd")
if [ "$release_mode" = "auto" ]; then
  if [ "$allow_auto_release" != "true" ]; then
    echo "project-automation 검증 실패: release_mode=auto 일 때 allow_auto_release=true가 필요합니다." >&2
    exit 2
  fi
  if [ "$deploy_cmd" = "unset" ] || [ "$verify_release_cmd" = "unset" ]; then
    echo "project-automation 검증 실패: release_mode=auto 일 때 deploy/verify_release_cmd를 확정해야 합니다." >&2
    exit 2
  fi
fi

for int_key in max_fix_attempts_per_gate max_autopilot_cycles; do
  val=$(get_value "$int_key")
  if ! echo "$val" | grep -Eq '^[0-9]+$'; then
    echo "project-automation 검증 실패: ${int_key}는 정수여야 합니다." >&2
    exit 2
  fi
done

for int_key in release_verify_retries release_verify_interval_sec; do
  val=$(get_value "$int_key")
  if ! echo "$val" | grep -Eq '^[0-9]+$'; then
    echo "project-automation 검증 실패: ${int_key}는 정수여야 합니다." >&2
    exit 2
  fi
done
if [ "$(get_value release_verify_retries)" -lt 1 ]; then
  echo "project-automation 검증 실패: release_verify_retries는 1 이상이어야 합니다." >&2
  exit 2
fi

run_on_push=$(get_value "run_gates_on_push")
if [ "$run_on_push" = "true" ]; then
  for gate_key in lint_cmd build_cmd test_cmd security_cmd; do
    gate_val=$(get_value "$gate_key")
    if [ "$gate_val" = "unset" ]; then
      echo "project-automation 검증 실패: run_gates_on_push=true 일 때 ${gate_key}=unset은 허용되지 않습니다." >&2
      echo ".claude/hooks/suggest-automation-gates.sh로 후보를 채우고 확정하세요." >&2
      exit 2
    fi
  done
fi

exit 0
