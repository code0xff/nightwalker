## Autopilot Goal

사용자가 목표만 주면 중간 승인 없이 가능한 범위에서 끝까지 구현 완료한다.

## Execution Loop

`plan -> implement -> validate -> review -> fix -> repeat`

- validate는 `project-automation.md`의 gate 명령을 따른다.
- gate 실패 시 원인 분석 후 자동 수정한다.
- 수정 후 같은 gate를 재실행한다.

## Stop Conditions

- gate별 수정 시도가 `max_fix_attempts_per_gate`를 초과
- 전체 사이클이 `max_autopilot_cycles`를 초과
- high/critical 위험 작업이 감지됨

## Risk Handling

- `auto_apply_risk_tier` 범위의 변경은 자동 반영한다.
- `require_user_for_risk_tier` 범위는 자동 적용하지 않고 보고 후 대기한다.

## Reporting

- 기본은 `final_report_only: true`를 따른다.
- 최종 보고에는 변경 요약, 검증 결과, 남은 리스크만 포함한다.
