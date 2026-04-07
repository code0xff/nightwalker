#!/bin/bash

set -euo pipefail

PROFILE_FILE=".claude/project-profile.md"
AUTOMATION_FILE=".claude/project-automation.md"
REPORT_FILE=".claude/state/qa-report.md"
GOAL="${1:-autopilot-goal}"

get_profile_value() {
  local key="$1"
  grep -E "^- ${key}:" "$PROFILE_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//" || true
}

get_automation_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//" || true
}

validate_report() {
  local report="$1"
  local heading
  for heading in "# QA Report" "## Requirement Coverage" "## Findings" "## Follow Up Workstreams"; do
    if ! grep -Fqx "$heading" "$report"; then
      echo "qa-check 실패: 보고서 형식이 올바르지 않습니다. missing=$heading" >&2
      return 2
    fi
  done
}

build_prompt() {
  cat <<EOF
You are performing QA against the project's initial requirements.
Inspect the repository and at least these files when present:
- docs/project-goal.md
- docs/scope.md
- docs/roadmap.md
- docs/execution-plan.md
- .claude/state/done-check-report.txt
- .claude/state/autopilot-state.json

Goal: ${GOAL}

Return markdown only and include these exact headings:
# QA Report
- status: pass|fail
- summary: short summary
## Requirement Coverage
- bullet list of requirement coverage
## Findings
- use '- none' if there are no QA issues
- otherwise each finding must start with '- [severity:<low|medium|high>]'
## Follow Up Workstreams
- use '- none' if there is nothing to register
- otherwise each line must start with '- QA workstream:'
EOF
}

mkdir -p "$(dirname "$REPORT_FILE")"

if [ "${DEV_HARNESS_TEST_MODE:-false}" = "true" ]; then
  cat > "$REPORT_FILE" <<EOF
# QA Report
- status: pass
- summary: test mode QA pass
## Requirement Coverage
- initial requirement coverage validated in test mode
## Findings
- none
## Follow Up Workstreams
- none
EOF
  cat "$REPORT_FILE"
  exit 0
fi

if [ ! -f "$PROFILE_FILE" ] || [ ! -f "$AUTOMATION_FILE" ]; then
  echo "qa-check 실패: profile/automation 파일이 필요합니다." >&2
  exit 2
fi

engine="$(get_profile_value review_engine)"
model="$(get_profile_value review_model)"
[ -z "$model" ] && model="unset"
prompt="$(build_prompt)"

case "$engine" in
  codex)
    if [ "$model" != "unset" ]; then
      codex exec --model "$model" "$prompt" > "$REPORT_FILE"
    else
      codex exec "$prompt" > "$REPORT_FILE"
    fi
    ;;
  claude)
    if [ "$model" != "unset" ]; then
      claude --model "$model" -p "$prompt" > "$REPORT_FILE"
    else
      claude -p "$prompt" > "$REPORT_FILE"
    fi
    ;;
  *)
    echo "qa-check 실패: review_engine=$engine 는 지원되지 않습니다." >&2
    exit 2
    ;;
esac

validate_report "$REPORT_FILE"
cat "$REPORT_FILE"

status="$(grep -E '^- status:' "$REPORT_FILE" | head -n 1 | sed -E 's/^- status:[[:space:]]*//')"
if [ "$status" = "pass" ]; then
  exit 0
fi

exit 1
