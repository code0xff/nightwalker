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
  rm -f .claude/state/autopilot-state.json
}
trap cleanup EXIT

run_expect_ok "hook syntax" sh -c 'find .claude/hooks -type f -name "*.sh" -print0 | xargs -0 -I{} bash -n "{}"'

run_expect_ok "project profile validation" .claude/hooks/validate-project-profile.sh
run_expect_ok "project approvals validation" .claude/hooks/validate-project-approvals.sh
run_expect_ok "project automation validation" .claude/hooks/validate-project-automation.sh

run_expect_ok "pre-approval allowlisted command" sh -c \
  "cat <<'JSON' | .claude/hooks/validate-pre-approval.sh >/dev/null
{\"tool_input\":{\"command\":\"git commit -m \\\"feat: ok\\\"\"}}
JSON"

run_expect_fail_pipe \
  "pre-approval blocks non-allowlisted mutating command" \
  '{"tool_input":{"command":"mkdir blocked-dir"}}' \
  ".claude/hooks/validate-pre-approval.sh"

run_expect_fail_pipe \
  "risk policy blocks high tier dependency changes" \
  '{"tool_input":{"command":"npm install left-pad"}}' \
  ".claude/hooks/enforce-risk-policy.sh"

run_expect_ok "risk classifier output valid tier" sh -c \
  'tier=$(.claude/hooks/classify-risk.sh "git commit -m \"feat: a\""); echo "$tier" | grep -Eq "^(low|medium|high|critical)$"'

run_expect_fail_pipe \
  "pre-approval blocks chained command bypass" \
  '{"tool_input":{"command":"echo hi; mkdir bypass-dir"}}' \
  ".claude/hooks/validate-pre-approval.sh"

run_expect_ok "automation gates push" .claude/hooks/run-automation-gates.sh push
run_expect_ok "quality gates push" .claude/hooks/run-quality-gates.sh push
run_expect_ok "engine readiness check" .claude/hooks/check-engine-readiness.sh
run_expect_ok "engine intent fallback plan" .claude/hooks/run-engine-intent.sh plan "ci-intent"
run_expect_ok "release stage auto" .claude/hooks/run-release-stage.sh

run_expect_ok "autopilot start" .claude/hooks/run-autopilot.sh start "ci-regression"
run_expect_ok "autopilot resume completed" .claude/hooks/run-autopilot.sh resume

run_expect_ok "autopilot state completed" sh -c \
  'test "$(jq -r ".status" .claude/state/autopilot-state.json)" = "completed"'
run_expect_ok "metrics report generated" .claude/hooks/report-automation-metrics.sh

pass "all harness regression checks"
