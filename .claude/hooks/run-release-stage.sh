#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"
STATE_HOOK=".claude/hooks/autopilot-state.sh"

if [ ! -f "$AUTOMATION_FILE" ]; then
  echo "release stage 실패: $AUTOMATION_FILE 파일이 없습니다." >&2
  exit 2
fi

get_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

release_mode=$(get_value "release_mode")
allow_auto_release=$(get_value "allow_auto_release")
require_clean=$(get_value "require_clean_worktree_before_release")
deploy_cmd=$(get_value "deploy_cmd")
verify_cmd=$(get_value "verify_release_cmd")
rollback_cmd=$(get_value "rollback_cmd")

if [ "$release_mode" = "disabled" ] || [ "$release_mode" = "manual" ]; then
  [ -x "$STATE_HOOK" ] && "$STATE_HOOK" checkpoint "release" "skip (${release_mode})"
  exit 0
fi

if [ "$allow_auto_release" != "true" ]; then
  echo "release stage 실패: allow_auto_release=true가 필요합니다." >&2
  exit 2
fi

if [ "$deploy_cmd" = "unset" ] || [ "$verify_cmd" = "unset" ]; then
  echo "release stage 실패: deploy_cmd/verify_release_cmd가 필요합니다." >&2
  exit 2
fi

if [ "$require_clean" = "true" ] && command -v git >/dev/null 2>&1; then
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "release stage 실패: clean worktree가 필요합니다." >&2
    exit 2
  fi
fi

[ -x "$STATE_HOOK" ] && "$STATE_HOOK" checkpoint "release" "deploy: $deploy_cmd"
if ! eval "$deploy_cmd"; then
  [ -x "$STATE_HOOK" ] && "$STATE_HOOK" fail "stage=release_deploy"
  if [ "$rollback_cmd" != "unset" ]; then
    echo "[release] rollback: $rollback_cmd" >&2
    eval "$rollback_cmd" || true
  fi
  exit 2
fi

[ -x "$STATE_HOOK" ] && "$STATE_HOOK" checkpoint "release" "verify: $verify_cmd"
if ! eval "$verify_cmd"; then
  [ -x "$STATE_HOOK" ] && "$STATE_HOOK" fail "stage=release_verify"
  if [ "$rollback_cmd" != "unset" ]; then
    echo "[release] rollback: $rollback_cmd" >&2
    eval "$rollback_cmd" || true
  fi
  exit 2
fi

[ -x "$STATE_HOOK" ] && "$STATE_HOOK" checkpoint "release" "ok"
exit 0
