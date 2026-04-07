#!/bin/bash

set -euo pipefail

SESSION_FILE=".devharness/session.yaml"
DOCS_DIR="docs"

if [ ! -f "$SESSION_FILE" ]; then
  echo "render-onboarding-docs 실패: $SESSION_FILE 파일이 없습니다." >&2
  exit 2
fi

get_value() {
  local key="$1"
  grep -E "^${key}:" "$SESSION_FILE" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//" || true
}

normalize_value() {
  local value="$1"
  if [ -z "$value" ] || [ "$value" = "unset" ]; then
    echo "(to be confirmed)"
  else
    echo "$value"
  fi
}

project_goal="$(normalize_value "$(get_value project_goal)")"
target_users="$(normalize_value "$(get_value target_users)")"
core_features="$(normalize_value "$(get_value core_features)")"
constraints="$(normalize_value "$(get_value constraints)")"
stack_1="$(normalize_value "$(get_value stack_candidate_1)")"
stack_2="$(normalize_value "$(get_value stack_candidate_2)")"
stack_3="$(normalize_value "$(get_value stack_candidate_3)")"
selected_stack="$(normalize_value "$(get_value selected_stack)")"
open_questions="$(normalize_value "$(get_value open_questions)")"

mkdir -p "$DOCS_DIR"

cat > "$DOCS_DIR/project-goal.md" <<DOC
# Project Goal

## Goal

- ${project_goal}

## Target Users

- ${target_users}

## Core Features

- ${core_features}
DOC

cat > "$DOCS_DIR/scope.md" <<DOC
# Scope

## In Scope

- MVP feature set required for first release
- Technical foundation needed to start implementation immediately

## Out Of Scope

- Non-critical optimization and scale tuning before MVP
- Nice-to-have features without measurable release impact

## Constraints

- ${constraints}
DOC

cat > "$DOCS_DIR/architecture.md" <<DOC
# Architecture

## Baseline

- Selected stack: ${selected_stack}
- System style: modular service + clear boundaries between API, domain, and persistence

## Initial Components

- API layer
- Domain/business logic layer
- Data access layer
- Test and quality gate layer
DOC

cat > "$DOCS_DIR/stack-decision.md" <<DOC
# Stack Decision

## Candidate Options

1. ${stack_1}
2. ${stack_2}
3. ${stack_3}

## Selected

- ${selected_stack}

## Open Questions

- ${open_questions}
DOC

cat > "$DOCS_DIR/roadmap.md" <<DOC
# Roadmap

## Workstream 1

- Goal: finalize requirements, boundaries, and API/data contracts
- Deliverables: architecture baseline, contract definitions, repository skeleton
- Exit Criteria: interfaces are documented and implementation can begin without open blockers

## Workstream 2

- Goal: implement the MVP core flow end-to-end on the selected stack
- Deliverables: primary use-case path, persistence wiring, integration path
- Exit Criteria: the main user flow works and core tests pass

## Workstream 3

- Goal: harden quality, security, and release readiness
- Deliverables: automation gates, regression coverage, release checklist
- Exit Criteria: quality gates pass and the project is ready for release validation
DOC

cat > "$DOCS_DIR/execution-plan.md" <<DOC
# Execution Plan

## Global Plan

- Design all roadmap workstreams before implementation starts
- Execute workstreams sequentially in roadmap order
- Run requirement QA after implementation and register remediation workstreams if needed
- Re-run plan only when roadmap scope or architecture decisions change

## Workstream 1 Plan

- Define domain model, repository boundaries, and API contracts
- Create the minimum project skeleton required for downstream implementation
- Validate assumptions that unblock Workstream 2

## Workstream 2 Plan

- Implement the main user journey end-to-end
- Connect API, domain, and persistence layers
- Add tests for the critical path and failure handling

## Workstream 3 Plan

- Add automation gates, regression checks, and release validation
- Close security and operational readiness gaps
- Prepare final quality/review pass for release
DOC

echo "render-onboarding-docs 완료: docs/*.md 생성"
exit 0
