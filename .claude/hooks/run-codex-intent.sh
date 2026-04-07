#!/bin/bash

# run-codex-intent.sh — codex 엔진 어댑터
#
# codex-plugin-cc가 있으면 Claude Code 세션 내에서 플러그인으로 실행 (컨텍스트 공유).
# 없으면 codex CLI로 fallback (기존 방식).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=intent-context.sh
source "${SCRIPT_DIR}/intent-context.sh"

PLUGIN_CHECK="${SCRIPT_DIR}/check-codex-plugin.sh"
INTENT="${1:-}"
GOAL="${2:-autopilot-goal}"
MODEL="${3:-unset}"

if [ -z "$INTENT" ]; then
  echo "usage: $0 <intent> [goal] [model]" >&2
  exit 2
fi

# ── 컨텍스트 빌드 (기존과 동일) ──

build_context_block() {
  local intent="$1"
  local goal="$2"
  local ctx=""

  local tree
  tree="$(collect_file_tree 3)"
  if [ -n "$tree" ]; then
    ctx="${ctx}

## Project File Tree
\`\`\`
${tree}
\`\`\`"
  fi

  local docs
  docs="$(collect_project_docs 200)"
  if [ -n "$docs" ]; then
    ctx="${ctx}

## Project Documents
${docs}"
  fi

  case "$intent" in
    build)
      local plan_artifact plan_body
      plan_artifact="$(find_latest_artifact "plan")"
      plan_body="$(read_artifact_body "$plan_artifact")"
      if [ -n "$plan_body" ]; then
        ctx="${ctx}

## Plan Output (from previous stage)
${plan_body}"
      fi
      ;;
    review)
      local plan_artifact plan_body build_artifact build_body
      plan_artifact="$(find_latest_artifact "plan")"
      plan_body="$(read_artifact_body "$plan_artifact")"
      build_artifact="$(find_latest_artifact "build")"
      build_body="$(read_artifact_body "$build_artifact")"
      if [ -n "$plan_body" ]; then
        ctx="${ctx}

## Plan Output (from plan stage)
${plan_body}"
      fi
      if [ -n "$build_body" ]; then
        ctx="${ctx}

## Build Output (from build stage)
${build_body}"
      fi

      local changes
      changes="$(collect_recent_changes)"
      if [ -n "$changes" ]; then
        ctx="${ctx}

## Recent Changes
${changes}"
      fi

      local build_log
      build_log="$(collect_build_log)"
      if [ -n "$build_log" ]; then
        ctx="${ctx}

## Build Step Log
\`\`\`
${build_log}
\`\`\`"
      fi

      local deferred
      deferred="$(collect_deferred_items)"
      if [ -n "$deferred" ]; then
        ctx="${ctx}

## Deferred Decisions And Assumptions
${deferred}"
      fi
      ;;
  esac

  echo "$ctx"
}

# ── 플러그인 모드 프롬프트 (Claude 세션에서 codex 도구 사용 지시) ──

build_plugin_prompt() {
  local intent="$1"
  local goal="$2"
  local context
  context="$(build_context_block "$intent" "$goal")"

  case "$intent" in
    plan)
      cat <<EOF
[intent=plan] goal=${goal}
${context}

You are creating an implementation plan for the goal above.
Inspect the project files, documents, and structure provided.

IMPORTANT: You have access to the Codex plugin. Use the codex tool to delegate the planning work:
- Call /codex:rescue with the goal and context to generate a high-quality plan
- If /codex:rescue is not available, create the plan yourself using all context provided

Return markdown only.
You must include these exact headings:
## Goal And Constraints
## Approach
## Implementation Plan
## Uncertainties
EOF
      ;;
    build)
      cat <<EOF
[intent=build] goal=${goal}
${context}

You are implementing the plan above.
Follow the Implementation Plan from the plan output exactly.
Make the required code/document changes before answering.
If the plan specifies specific files, modules, or interfaces, implement those.

You have access to the Codex plugin. You may use /codex:rescue to delegate complex implementation subtasks.

Return markdown only.
You must include these exact headings:
## Build Changes
## Validation Results
## Updated Files
EOF
      ;;
    review)
      cat <<EOF
[intent=review] goal=${goal}
${context}

You are reviewing the implementation against the original plan.

IMPORTANT: You have access to the Codex plugin. Use it for review:
- Call /codex:review for standard code review
- Call /codex:adversarial-review for deep analysis of design decisions and tradeoffs
- Synthesize the codex review findings with your own analysis
- If codex tools are not available, perform the review yourself

Check that every item in the Implementation Plan was addressed.
Verify code quality, test coverage, and security.
Apply fixes for clear issues directly. Flag ambiguous items for user follow-up.

Return markdown only.
You must include these exact headings:
## Findings
## Applied Fixes
## User Follow Ups
EOF
      ;;
    *)
      printf '[intent=%s] goal=%s\n%s\n' "$intent" "$goal" "$context"
      ;;
  esac
}

# ── CLI fallback 프롬프트 (codex exec 직접 호출) ──

build_cli_prompt() {
  local intent="$1"
  local goal="$2"
  local context
  context="$(build_context_block "$intent" "$goal")"

  case "$intent" in
    plan)
      cat <<EOF
[intent=plan] goal=${goal}
${context}

You are creating an implementation plan for the goal above.
Inspect the project files, documents, and structure provided.

Return markdown only.
You must include these exact headings:
## Goal And Constraints
## Approach
## Implementation Plan
## Uncertainties
EOF
      ;;
    build)
      cat <<EOF
[intent=build] goal=${goal}
${context}

You are implementing the plan above.
Follow the Implementation Plan from the plan output exactly.
Make the required code/document changes before answering.
If the plan specifies specific files, modules, or interfaces, implement those.

Return markdown only.
You must include these exact headings:
## Build Changes
## Validation Results
## Updated Files
EOF
      ;;
    review)
      cat <<EOF
[intent=review] goal=${goal}
${context}

You are reviewing the implementation against the original plan.
Check that every item in the Implementation Plan was addressed.
Verify code quality, test coverage, and security.
Apply fixes for clear issues directly. Flag ambiguous items for user follow-up.

Return markdown only.
You must include these exact headings:
## Findings
## Applied Fixes
## User Follow Ups
EOF
      ;;
    *)
      printf '[intent=%s] goal=%s\n%s\n' "$intent" "$goal" "$context"
      ;;
  esac
}

# ── 테스트 모드 ──

if [ "${DEV_HARNESS_TEST_MODE:-false}" = "true" ]; then
  case "$INTENT" in
    plan)
      cat <<EOF
## Goal And Constraints
- goal: ${GOAL}
## Approach
- test mode
## Implementation Plan
1. noop
## Uncertainties
- none
EOF
      ;;
    build)
      cat <<EOF
## Build Changes
- test mode
## Validation Results
- skipped in test mode
## Updated Files
- none
EOF
      ;;
    review)
      cat <<EOF
## Findings
- none
## Applied Fixes
- none
## User Follow Ups
- none
EOF
      ;;
  esac
  exit 0
fi

# ── 실행 모드 결정 ──

codex_mode="cli"
if [ -x "$PLUGIN_CHECK" ]; then
  codex_mode="$("$PLUGIN_CHECK" check)"
fi

case "$codex_mode" in
  plugin)
    # 플러그인 모드: Claude Code 세션 내에서 codex 도구 사용
    PROMPT="$(build_plugin_prompt "$INTENT" "$GOAL")"
    if [ "$MODEL" != "unset" ]; then
      claude --model "$MODEL" -p "$PROMPT"
    else
      claude -p "$PROMPT"
    fi
    ;;
  cli)
    # CLI fallback: codex exec 직접 호출
    PROMPT="$(build_cli_prompt "$INTENT" "$GOAL")"
    if [ "$MODEL" != "unset" ]; then
      codex exec --model "$MODEL" "$PROMPT"
    else
      codex exec "$PROMPT"
    fi
    ;;
  none)
    # codex 사용 불가 → Claude로 자체 수행
    echo "codex-intent 경고: codex 사용 불가, Claude로 fallback합니다." >&2
    PROMPT="$(build_cli_prompt "$INTENT" "$GOAL")"
    if [ "$MODEL" != "unset" ]; then
      claude --model "$MODEL" -p "$PROMPT"
    else
      claude -p "$PROMPT"
    fi
    ;;
esac
