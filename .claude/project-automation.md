# Project Automation Profile

완전 자동화 실행 정책을 정의한다.
이 파일은 `/autopilot` 실행 기준이며, 변경 시 사용자 확인이 필요하다.

## Mode

- automation_mode: full-auto
- allow_midway_user_prompt: false
- final_report_only: true

## Retry Policy

- max_fix_attempts_per_gate: 3
- max_autopilot_cycles: 8

## Gate Commands

- lint_cmd: unset
- build_cmd: unset
- test_cmd: unset
- security_cmd: unset

## Hook Enforcement

- run_gates_on_commit: false
- run_gates_on_push: true

## Risk Policy

- auto_apply_risk_tier: low,medium
- require_user_for_risk_tier: high,critical
