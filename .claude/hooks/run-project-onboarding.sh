#!/bin/bash

set -euo pipefail

SESSION_FILE=".devharness/session.yaml"
SUGGEST_HOOK=".claude/hooks/suggest-automation-gates.sh"
BOOTSTRAP_HOOK=".claude/hooks/bootstrap-init-harness.sh"
RENDER_HOOK=".claude/hooks/render-onboarding-docs.sh"
PROFILE_HOOK=".claude/hooks/validate-project-profile.sh"
APPROVALS_HOOK=".claude/hooks/validate-project-approvals.sh"
AUTOMATION_HOOK=".claude/hooks/validate-project-automation.sh"
CONTRACT_HOOK=".claude/hooks/validate-completion-contract.sh"

require_hook() {
  local hook="$1"
  if [ ! -x "$hook" ]; then
    echo "run-project-onboarding 실패: 실행 권한이 없는 hook: $hook" >&2
    exit 2
  fi
}

ensure_session_file() {
  mkdir -p .devharness
  if [ -f "$SESSION_FILE" ]; then
    return 0
  fi

  cat > "$SESSION_FILE" <<'YAML'
schema_version: 1
status: draft
project_goal: unset
target_users: unset
core_features: unset
constraints: unset
stack_candidate_1: unset
stack_candidate_2: unset
stack_candidate_3: unset
selected_stack: unset
open_questions: unset
decisions: unset
YAML
}

get_value() {
  local key="$1"
  grep -E "^${key}:" "$SESSION_FILE" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//" || true
}

set_status() {
  local next_status="$1"
  awk -v value="$next_status" '
    BEGIN { updated = 0 }
    $0 ~ /^status:/ {
      print "status: " value
      updated = 1
      next
    }
    { print }
    END {
      if (updated == 0) {
        print "status: " value
      }
    }
  ' "$SESSION_FILE" > "${SESSION_FILE}.tmp"
  mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
}

render_ready_report() {
  local goal users stack status
  goal="$(get_value project_goal)"
  users="$(get_value target_users)"
  stack="$(get_value selected_stack)"
  status="ready"

  if [ -z "$goal" ] || [ "$goal" = "unset" ] || \
     [ -z "$users" ] || [ "$users" = "unset" ] || \
     [ -z "$stack" ] || [ "$stack" = "unset" ]; then
    status="pending-input"
  fi

  if [ "$status" = "ready" ]; then
    set_status "ready"
  else
    set_status "proposed"
  fi

  cat > ONBOARDING_READY.md <<EOF2
# Onboarding Ready Report

- status: ${status}
- project_goal: ${goal:-unset}
- target_users: ${users:-unset}
- selected_stack: ${stack:-unset}

## First Workstreams

1. Finalize API and data contracts from docs/architecture.md
2. Implement MVP core flow from docs/execution-plan.md
3. Add build/test/security gates from .claude/project-automation.md

## Next Action

- Run /plan with the approved goal and selected stack.
EOF2

  if [ "$status" = "pending-input" ]; then
    echo "run-project-onboarding 경고: session.yaml에 미확정 값이 있습니다 (project_goal/target_users/selected_stack)."
  fi
}

require_hook "$SUGGEST_HOOK"
require_hook "$BOOTSTRAP_HOOK"
require_hook "$RENDER_HOOK"
require_hook "$PROFILE_HOOK"
require_hook "$APPROVALS_HOOK"
require_hook "$AUTOMATION_HOOK"
require_hook "$CONTRACT_HOOK"

ensure_session_file

"$SUGGEST_HOOK" >/dev/null
"$BOOTSTRAP_HOOK" >/dev/null
"$PROFILE_HOOK"
"$APPROVALS_HOOK"
"$AUTOMATION_HOOK"
"$CONTRACT_HOOK"
"$RENDER_HOOK" >/dev/null
render_ready_report

echo "run-project-onboarding 완료: 문서/정책/검증이 최신화되었습니다."
exit 0
