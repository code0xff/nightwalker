#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1" >&2; exit 1; }

run_expect_ok() {
  local name="$1"
  shift
  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

run_expect_fail() {
  local name="$1"
  shift
  if "$@"; then
    fail "$name"
  else
    pass "$name"
  fi
}

run_expect_fail_pipe() {
  local name="$1"
  local payload="$2"
  local hook="$3"
  if printf '%s' "$payload" | "$hook" >/dev/null 2>&1; then
    fail "$name"
  else
    pass "$name"
  fi
}

cleanup() {
  cp "$AUTOMATION_BAK" .claude/project-automation.md
  cp "$APPROVALS_BAK" .claude/project-approvals.md
  cp "$SESSION_BAK" .devharness/session.yaml
  rm -f .claude/state/autopilot-state.json
  rm -f .claude/state/qa-report.md
  rm -f ONBOARDING_READY.md
  rm -f docs/project-goal.md docs/scope.md docs/architecture.md docs/stack-decision.md docs/roadmap.md docs/execution-plan.md
  rm -rf docs/workstreams
  rmdir docs 2>/dev/null || true
  rm -f "$AUTOMATION_BAK" "$APPROVALS_BAK"
}

AUTOMATION_BAK="$(mktemp)"
APPROVALS_BAK="$(mktemp)"
SESSION_BAK="$(mktemp)"
cp .claude/project-automation.md "$AUTOMATION_BAK"
cp .claude/project-approvals.md "$APPROVALS_BAK"
cp .devharness/session.yaml "$SESSION_BAK"
trap cleanup EXIT

run_expect_ok "hook syntax" sh -c 'find .claude/hooks -type f -name "*.sh" -print0 | xargs -0 -I{} bash -n "{}"'

run_expect_ok "project profile validation" .claude/hooks/validate-project-profile.sh
run_expect_ok "project approvals validation" .claude/hooks/validate-project-approvals.sh
run_expect_ok "project automation validation" .claude/hooks/validate-project-automation.sh
run_expect_ok "completion contract validation" .claude/hooks/validate-completion-contract.sh
run_expect_ok "init bootstrap" .claude/hooks/bootstrap-init-harness.sh
run_expect_ok "project approvals validation after bootstrap" .claude/hooks/validate-project-approvals.sh
run_expect_ok "project automation validation after bootstrap" .claude/hooks/validate-project-automation.sh
run_expect_ok "completion contract validation after bootstrap" .claude/hooks/validate-completion-contract.sh

run_expect_ok "pre-approval allowlisted command" sh -c \
  "cat <<'JSON' | .claude/hooks/validate-pre-approval.sh >/dev/null
{\"tool_input\":{\"command\":\"git commit -m \\\"feat: ok\\\"\"}}
JSON"

run_expect_ok "pre-approval report-only for non-allowlisted command" sh -c \
  "printf '{\"tool_input\":{\"command\":\"mkdir blocked-dir\"}}' | .claude/hooks/validate-pre-approval.sh >/dev/null"

run_expect_ok "risk policy report-only for high-tier command" sh -c \
  "printf '{\"tool_input\":{\"command\":\"npm install left-pad\"}}' | .claude/hooks/enforce-risk-policy.sh >/dev/null"

run_expect_ok "risk classifier output valid tier" sh -c \
  'tier=$(.claude/hooks/classify-risk.sh "git commit -m \"feat: a\""); echo "$tier" | grep -Eq "^(low|medium|high|critical)$"'

run_expect_ok "pre-approval report-only for chained command bypass" sh -c \
  "printf '{\"tool_input\":{\"command\":\"echo hi; mkdir bypass-dir\"}}' | .claude/hooks/validate-pre-approval.sh >/dev/null"

run_expect_ok "automation gates push" .claude/hooks/run-automation-gates.sh push
run_expect_ok "quality gates push" .claude/hooks/run-quality-gates.sh push
run_expect_ok "engine readiness check" .claude/hooks/check-engine-readiness.sh
run_expect_ok "engine intent fallback plan" sh -c \
  'DEV_HARNESS_TEST_MODE=true .claude/hooks/run-engine-intent.sh plan "ci-intent"'
run_expect_ok "qa check test mode" sh -c \
  'DEV_HARNESS_TEST_MODE=true .claude/hooks/run-qa-check.sh "ci-qa" >/dev/null'
run_expect_ok "done check report-only" .claude/hooks/run-done-check.sh

run_expect_ok "autopilot start" sh -c \
  'DEV_HARNESS_TEST_MODE=true AUTOPILOT_SKIP_VCS_WRITE=true .claude/hooks/run-autopilot.sh start "ci-regression"'
run_expect_ok "autopilot resume completed" sh -c \
  'DEV_HARNESS_TEST_MODE=true AUTOPILOT_SKIP_VCS_WRITE=true .claude/hooks/run-autopilot.sh resume'

run_expect_ok "autopilot state completed" sh -c \
  'test "$(jq -r ".status" .claude/state/autopilot-state.json)" = "completed"'
run_expect_ok "autopilot followups recorded" sh -c \
  'test "$(jq ".manual_followups | length" .claude/state/autopilot-state.json)" -ge 1'
run_expect_ok "unset config report generated" .claude/hooks/report-unset-config.sh
run_expect_ok "render onboarding docs" .claude/hooks/render-onboarding-docs.sh
run_expect_ok "qa workstream registration" sh -c '
cat > .claude/state/qa-report.md <<'"'"'EOF'"'"'
# QA Report
- status: fail
- summary: coverage gap found
## Requirement Coverage
- some requirement is missing
## Findings
- [severity:medium] missing requirement coverage
## Follow Up Workstreams
- QA workstream: resolve missing requirement coverage
EOF
.claude/hooks/register-qa-workstream.sh "ci-qa" >/dev/null &&
test -d docs/workstreams &&
test "$(find docs/workstreams -type f | wc -l | tr -d " ")" -ge 1'
run_expect_ok "project onboarding flow" .claude/hooks/run-project-onboarding.sh
run_expect_ok "onboarding auto-starts autopilot when ready" sh -c '
cat > .devharness/session.yaml <<'"'"'EOF'"'"'
schema_version: 1
status: proposed
project_goal: ci regression goal
target_users: internal developers
core_features: unset
constraints: unset
stack_candidate_1: unset
stack_candidate_2: unset
stack_candidate_3: unset
selected_stack: bash
open_questions: unset
decisions: unset
EOF
DEV_HARNESS_TEST_MODE=true AUTOPILOT_SKIP_VCS_WRITE=true .claude/hooks/run-project-onboarding.sh >/dev/null &&
test "$(jq -r ".status" .claude/state/autopilot-state.json)" = "completed"'
run_expect_ok "bootstrap project helper" scripts/bootstrap-project.sh --skip-onboarding
run_expect_ok "bootstrap project standalone install" sh -c \
  'tmpdir=$(mktemp -d) && DEV_HARNESS_SOURCE="$PWD" scripts/bootstrap-project.sh "$tmpdir" --skip-onboarding && test -d "$tmpdir/.claude" && test -d "$tmpdir/.devharness" && rm -rf "$tmpdir"'
run_expect_ok "onboarding ready report exists" test -f ONBOARDING_READY.md
run_expect_ok "onboarding docs generated" test -f docs/project-goal.md

pass "all harness regression checks"
