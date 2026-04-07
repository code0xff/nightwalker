#!/bin/bash

set -euo pipefail

INTENT="${1:-}"
GOAL="${2:-autopilot-goal}"
MODEL="${3:-unset}"

build_prompt() {
  local intent="$1"
  local goal="$2"
  case "$intent" in
    plan)
      cat <<EOF
[intent=plan] goal=${goal}

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

Return markdown only.
You must make the required code/document changes before answering.
You must include these exact headings:
## Build Changes
## Validation Results
## Updated Files
EOF
      ;;
    review)
      cat <<EOF
[intent=review] goal=${goal}

Return markdown only.
You must include these exact headings:
## Findings
## Applied Fixes
## User Follow Ups
EOF
      ;;
    *)
      printf '[intent=%s] goal=%s\n' "$intent" "$goal"
      ;;
  esac
}

PROMPT="$(build_prompt "$INTENT" "$GOAL")"

if [ -z "$INTENT" ]; then
  echo "usage: $0 <intent> [goal] [model]" >&2
  exit 2
fi

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

if [ "$MODEL" != "unset" ]; then
  claude --model "$MODEL" -p "$PROMPT"
  exit 0
fi

claude -p "$PROMPT"
