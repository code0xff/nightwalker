# Project Automation Profile

완전 자동화 실행 정책을 정의한다.
이 파일은 `/autopilot` 실행 기준이며, 변경 시 사용자 확인이 필요하다.

## Mode

- automation_mode: full-auto
- allow_midway_user_prompt: false
- final_report_only: true
- auto_start_autopilot_on_ready: true
- preapproval_enforcement: report
- risk_enforcement: report
- unresolved_config_enforcement: report
- allow_auto_push: true
- engine_runtime_mode: strict
- allow_engine_stub: false
- execute_engine_commands: true

## Retry Policy

- max_fix_attempts_per_gate: 5
- max_autopilot_cycles: 10

## Stage Commands

- plan_cmd: .claude/hooks/run-project-onboarding.sh && .claude/hooks/run-engine-intent.sh plan "${AUTOPILOT_GOAL:-autopilot-goal}"
- implement_cmd: .claude/hooks/run-engine-intent.sh build "${AUTOPILOT_GOAL:-autopilot-goal}"
- review_cmd: .claude/hooks/run-engine-intent.sh review "${AUTOPILOT_GOAL:-autopilot-goal}"

## Engine Adapter Commands (optional)

- engine_cmd_codex: codex --help >/dev/null
- engine_cmd_claude: claude --help >/dev/null
- engine_cmd_openai: unset
- engine_cmd_cursor: unset
- engine_cmd_gemini: unset
- engine_cmd_copilot: unset

## Gate Fix Commands

- lint_fix_cmd: .claude/hooks/run-engine-intent.sh build "${AUTOPILOT_GOAL:-autopilot-goal}"
- build_fix_cmd: .claude/hooks/run-engine-intent.sh build "${AUTOPILOT_GOAL:-autopilot-goal}"
- test_fix_cmd: .claude/hooks/run-engine-intent.sh build "${AUTOPILOT_GOAL:-autopilot-goal}"
- security_fix_cmd: .claude/hooks/run-engine-intent.sh build "${AUTOPILOT_GOAL:-autopilot-goal}"

## Gate Commands

gate 명령이 비어 있으면 `.claude/hooks/suggest-automation-gates.sh`를 먼저 실행해 후보를 채운 뒤 확정한다.

- lint_cmd: find .claude/hooks -type f -name "*.sh" -print0 | xargs -0 -I{} bash -n "{}"
- build_cmd: echo "no build step for harness-only repository"
- test_cmd: .claude/hooks/validate-project-profile.sh && .claude/hooks/validate-project-approvals.sh && .claude/hooks/validate-project-automation.sh && .claude/hooks/validate-completion-contract.sh
- security_cmd: if rg -n --hidden -S "(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY-----|password\s*=|secret\s*=)" .; then echo "잠재적 시크릿 패턴 감지"; exit 1; else exit 0; fi

## Hook Enforcement

- run_gates_on_commit: false
- run_gates_on_push: true
- run_quality_on_commit: false
- run_quality_on_push: true

## Quality Policy

- enable_quality_gates: true
- quality_cmd: find .claude/hooks -type f -name "*.sh" -print0 | xargs -0 -I{} bash -n "{}" && .claude/hooks/validate-project-profile.sh && .claude/hooks/validate-project-approvals.sh && .claude/hooks/validate-project-automation.sh && .claude/hooks/validate-completion-contract.sh
- quality_coverage_cmd: unset
- quality_perf_cmd: unset
- quality_architecture_cmd: unset

## Risk Policy

- auto_apply_risk_tier: low,medium
- require_user_for_risk_tier: high,critical
