# Project Automation Profile

완전 자동화 실행 정책을 정의한다.
이 파일은 `/autopilot` 실행 기준이며, 변경 시 사용자 확인이 필요하다.

## Mode

- automation_mode: full-auto
- allow_midway_user_prompt: false
- final_report_only: true
- allow_auto_push: true
- engine_runtime_mode: stub-fallback
- allow_engine_stub: true
- execute_engine_commands: false

## Retry Policy

- max_fix_attempts_per_gate: 3
- max_autopilot_cycles: 8

## Stage Commands

- plan_cmd: unset
- implement_cmd: unset
- review_cmd: unset

## Gate Fix Commands

- lint_fix_cmd: unset
- build_fix_cmd: unset
- test_fix_cmd: unset
- security_fix_cmd: unset

## Gate Commands

gate 명령이 비어 있으면 `.claude/hooks/suggest-automation-gates.sh`를 먼저 실행해 후보를 채운 뒤 확정한다.

- lint_cmd: find .claude/hooks -type f -name "*.sh" -print0 | xargs -0 -I{} bash -n "{}"
- build_cmd: echo "no build step for harness-only repository"
- test_cmd: .claude/hooks/validate-project-profile.sh && .claude/hooks/validate-project-approvals.sh && .claude/hooks/validate-project-automation.sh
- security_cmd: if rg -n --hidden -S "(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|PRIVATE) KEY-----|password\s*=|secret\s*=)" .; then echo "잠재적 시크릿 패턴 감지"; exit 1; else exit 0; fi

## Hook Enforcement

- run_gates_on_commit: false
- run_gates_on_push: true
- run_quality_on_commit: false
- run_quality_on_push: true

## Quality Policy

- enable_quality_gates: true
- quality_cmd: find .claude/hooks -type f -name "*.sh" -print0 | xargs -0 -I{} bash -n "{}" && .claude/hooks/validate-project-profile.sh && .claude/hooks/validate-project-approvals.sh && .claude/hooks/validate-project-automation.sh

## Release Policy

- release_mode: manual
- allow_auto_release: false
- require_clean_worktree_before_release: true
- deploy_cmd: unset
- verify_release_cmd: unset
- rollback_cmd: unset

## Risk Policy

- auto_apply_risk_tier: low,medium
- require_user_for_risk_tier: high,critical
