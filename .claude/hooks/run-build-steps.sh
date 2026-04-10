#!/bin/bash

# run-build-steps.sh — plan의 Implementation Plan을 step 단위로 분할 실행
#
# 단일 build 호출 대신:
# 1. plan artifact에서 Implementation Plan 단계를 파싱
# 2. 각 step을 개별 build intent로 실행
# 3. step 완료 후 gate 검증 (build/test)
# 4. 실패 시 에러 컨텍스트를 포함하여 fix 호출
# 5. 모든 step 완료 후 통합 build artifact 생성

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=intent-context.sh
source "${SCRIPT_DIR}/intent-context.sh"
# shellcheck source=nightwalker-session.sh
source "${SCRIPT_DIR}/nightwalker-session.sh"

PROFILE_FILE=".claude/project-profile.md"
AUTOMATION_FILE=".claude/project-automation.md"
STATE_HOOK=".claude/hooks/autopilot-state.sh"
ENGINE_HOOK=".claude/hooks/run-engine-intent.sh"
STATE_DIR=".claude/state/intents"
BUILD_LOG=".claude/state/build-steps.log"

GOAL="${1:-autopilot-goal}"
STEP_PROGRESS_FILE=".claude/state/build-steps-progress.json"

get_profile_value() {
  local key="$1"
  grep -E "^- ${key}:" "$PROFILE_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

get_automation_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

log_step() {
  local msg="$1"
  printf '%s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$msg" >> "$BUILD_LOG"
}

# 이전 실행에서 완료된 step 번호 목록을 반환한다 (goal이 동일할 때만)
get_completed_steps() {
  if [ -f "$STEP_PROGRESS_FILE" ] && command -v jq >/dev/null 2>&1; then
    local stored_goal
    stored_goal="$(jq -r '.goal // ""' "$STEP_PROGRESS_FILE" 2>/dev/null || true)"
    if [ "$stored_goal" = "$GOAL" ]; then
      jq -r '.completed_steps // [] | .[]' "$STEP_PROGRESS_FILE" 2>/dev/null || true
      return
    fi
  fi
  echo ""
}

# 완료된 step 번호를 progress 파일에 기록한다
record_completed_step() {
  local step_num="$1"
  command -v jq >/dev/null 2>&1 || return 0
  local existing="[]"
  if [ -f "$STEP_PROGRESS_FILE" ]; then
    existing="$(jq '.completed_steps // []' "$STEP_PROGRESS_FILE" 2>/dev/null || echo "[]")"
  fi
  jq -n --arg goal "$GOAL" --argjson steps "$existing" --argjson step "$step_num" \
    '{goal: $goal, completed_steps: ($steps + [$step])}' > "$STEP_PROGRESS_FILE"
}

# step progress 파일을 삭제한다
clear_step_progress() {
  rm -f "$STEP_PROGRESS_FILE"
}

# plan artifact에서 Implementation Plan 섹션의 번호매긴 단계들을 추출
parse_plan_steps() {
  local plan_artifact="$1"
  if [ -z "$plan_artifact" ] || [ ! -f "$plan_artifact" ]; then
    echo ""
    return 0
  fi

  awk '
    /^## Implementation Plan/ { in_section=1; next }
    /^## / && in_section==1 { exit }
    in_section==1 && /^[0-9]+\. / { print }
  ' "$plan_artifact"
}

# 빠른 gate 검증 (build + test만 실행)
run_quick_gate() {
  local build_cmd test_cmd
  build_cmd="$(get_automation_value build_cmd)"
  test_cmd="$(get_automation_value test_cmd)"

  if [ -n "$build_cmd" ] && [ "$build_cmd" != "unset" ]; then
    if ! eval "$build_cmd" >/dev/null 2>&1; then
      echo "build_cmd failed"
      return 1
    fi
  fi

  if [ -n "$test_cmd" ] && [ "$test_cmd" != "unset" ]; then
    if ! eval "$test_cmd" >/dev/null 2>&1; then
      echo "test_cmd failed"
      return 1
    fi
  fi

  return 0
}

# step 실행용 엔진 어댑터 호출
run_step_build() {
  local step_number="$1"
  local step_description="$2"
  local prev_error="${3:-}"
  local engine model adapter_cmd

  engine="$(get_profile_value build_engine)"
  model="$(get_profile_value build_model)"
  [ -z "$model" ] && model="unset"

  # step에 특화된 goal 구성
  local step_goal="[step ${step_number}] ${step_description}"

  # 에러 컨텍스트가 있으면 fix 지시를 추가
  local error_context=""
  if [ -n "$prev_error" ]; then
    error_context="

## Previous Attempt Failed
The previous attempt to implement this step failed with:
\`\`\`
${prev_error}
\`\`\`
Fix the issue and complete the step."
  fi

  # 전용 어댑터 사용
  local adapter_script=""
  case "$engine" in
    claude) adapter_script=".claude/hooks/run-claude-intent.sh" ;;
    codex) adapter_script=".claude/hooks/run-codex-intent.sh" ;;
  esac

  if [ -n "$adapter_script" ] && [ -x "$adapter_script" ]; then
    # 어댑터는 내부적으로 plan context를 이미 주입하므로
    # step 목표만 전달하면 됨
    local full_goal="${GOAL} -- ${step_goal}${error_context}"

    if nightwalker_is_test_mode; then
      mkdir -p "$STATE_DIR"
      local step_artifact="${STATE_DIR}/build-step-${step_number}-$(date +%s)-$RANDOM.md"
      cat > "$step_artifact" <<EOF
## Build Changes
- step ${step_number}: ${step_description} (test mode)
## Validation Results
- skipped in test mode
## Updated Files
- none
EOF
      cat "$step_artifact"
      return 0
    fi

    "$adapter_script" build "$full_goal" "$model"
    return $?
  fi

  # 전용 어댑터가 없으면 engine-intent에 위임
  "$ENGINE_HOOK" build "${step_goal}${error_context}"
}

# ── 메인 ──

if [ ! -f "$PROFILE_FILE" ] || [ ! -f "$AUTOMATION_FILE" ]; then
  echo "run-build-steps 실패: profile/automation 파일이 필요합니다." >&2
  exit 2
fi

mkdir -p "$(dirname "$BUILD_LOG")"
mkdir -p "$STATE_DIR"
: > "$BUILD_LOG"

# 오래된 intent artifact 정리 (intent 유형별 최신 20개 유지)
cleanup_old_artifacts 20

max_fix="$(get_automation_value max_fix_attempts_per_gate)"
[ -z "$max_fix" ] && max_fix="3"

# 1. 최신 plan artifact에서 step 추출
plan_artifact="$(find_latest_artifact "plan")"
steps="$(parse_plan_steps "$plan_artifact")"

if [ -z "$steps" ]; then
  # step 파싱 불가 → 단일 build로 fallback
  log_step "no parseable steps found, falling back to single build"
  if [ -x "$STATE_HOOK" ] && [ "${AUTOPILOT_ACTIVE:-false}" = "true" ]; then
    "$STATE_HOOK" checkpoint "build-steps" "fallback to single build (no steps parsed)" >/dev/null 2>&1 || true
  fi
  "$ENGINE_HOOK" build "$GOAL"
  exit $?
fi

# 2. step별 실행 루프
step_count="$(echo "$steps" | wc -l | tr -d ' ')"
log_step "parsed ${step_count} steps from plan"

if [ -x "$STATE_HOOK" ] && [ "${AUTOPILOT_ACTIVE:-false}" = "true" ]; then
  "$STATE_HOOK" checkpoint "build-steps" "parsed ${step_count} steps" >/dev/null 2>&1 || true
fi

current_step=0
all_outputs=""
failed_steps=""

# 이전 실행에서 완료된 step 목록 (resume 지원)
completed_steps_list="$(get_completed_steps)"

while IFS= read -r step_line; do
  current_step=$((current_step + 1))

  # "1. description" → "description"
  step_desc="$(echo "$step_line" | sed -E 's/^[0-9]+\.[[:space:]]*//')"

  # 이미 완료된 step은 건너뜀 (resume)
  if echo "$completed_steps_list" | grep -qx "$current_step" 2>/dev/null; then
    log_step "step ${current_step}/${step_count}: skipped (already completed in previous run)"
    all_outputs="${all_outputs}

### Step ${current_step}: ${step_desc}
- skipped (resumed from previous run)"
    continue
  fi

  log_step "step ${current_step}/${step_count}: ${step_desc}"

  if [ -x "$STATE_HOOK" ] && [ "${AUTOPILOT_ACTIVE:-false}" = "true" ]; then
    "$STATE_HOOK" checkpoint "build-steps" "step ${current_step}/${step_count}: ${step_desc}" >/dev/null 2>&1 || true
  fi

  # step 실행 + 검증 + 재시도 루프
  attempt=1
  step_ok=false
  prev_error=""

  while [ "$attempt" -le "$max_fix" ]; do
    step_output=""
    step_output="$(run_step_build "$current_step" "$step_desc" "$prev_error" 2>&1)" && step_exit=0 || step_exit=$?

    if [ "$step_exit" -eq 0 ]; then
      # gate 검증
      gate_error=""
      gate_error="$(run_quick_gate 2>&1)" && gate_exit=0 || gate_exit=$?

      if [ "$gate_exit" -eq 0 ]; then
        step_ok=true
        all_outputs="${all_outputs}

### Step ${current_step}: ${step_desc}
${step_output}"
        record_completed_step "$current_step"
        log_step "step ${current_step} ok (attempt ${attempt})"
        break
      else
        prev_error="Step build succeeded but gate verification failed: ${gate_error}"
        log_step "step ${current_step} gate failed (attempt ${attempt}): ${gate_error}"
      fi
    else
      prev_error="Step build failed (exit ${step_exit}): ${step_output}"
      log_step "step ${current_step} build failed (attempt ${attempt})"
    fi

    attempt=$((attempt + 1))
  done

  if [ "$step_ok" = "false" ]; then
    log_step "step ${current_step} FAILED after ${max_fix} attempts"
    failed_steps="${failed_steps}
- step ${current_step}: ${step_desc} (failed after ${max_fix} attempts)"
    # 실패해도 나머지 step은 계속 시도 (best-effort)
    if [ -x "$STATE_HOOK" ] && [ "${AUTOPILOT_ACTIVE:-false}" = "true" ]; then
      "$STATE_HOOK" defer deferred_decisions "build step ${current_step} failed: ${step_desc}" >/dev/null 2>&1 || true
    fi
  fi

done <<< "$steps"

# 3. 통합 build artifact 생성
combined_artifact="${STATE_DIR}/build-$(date +%s)-$RANDOM.md"
{
  echo "# Engine Intent Artifact"
  echo
  echo "- intent: build"
  echo "- engine: $(get_profile_value build_engine)"
  echo "- mode: step-by-step"
  echo "- total_steps: ${step_count}"
  echo "- goal: ${GOAL}"
  echo
  echo "## Build Changes"
  echo "${all_outputs}"
  echo
  echo "## Validation Results"
  if [ -z "$failed_steps" ]; then
    echo "- all ${step_count} steps passed"
  else
    echo "- ${step_count} steps attempted"
    echo "- failed steps:${failed_steps}"
  fi
  echo
  echo "## Updated Files"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --name-only HEAD 2>/dev/null | sed 's/^/- /' || echo "- none detected"
  else
    echo "- not a git repo"
  fi
} > "$combined_artifact"

log_step "combined build artifact: ${combined_artifact}"

if [ -x "$STATE_HOOK" ] && [ "${AUTOPILOT_ACTIVE:-false}" = "true" ]; then
  "$STATE_HOOK" checkpoint "build" "artifact=${combined_artifact}" >/dev/null 2>&1 || true
fi

cat "$combined_artifact"

if [ -n "$failed_steps" ]; then
  echo "run-build-steps 경고: 일부 step이 실패했습니다.${failed_steps}" >&2
  exit 1
fi

# 모든 step 성공 시 progress 파일 정리
clear_step_progress

exit 0
