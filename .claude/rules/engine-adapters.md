## Engine Adapter Contract

엔진이 달라도 하네스 실행 인터페이스는 동일해야 한다.

- Intent는 항상 3개다: `plan`, `build`, `review`
- 각 intent는 활성 프로파일의 `*_engine`, `*_model`을 따른다.
- 특정 도구 명령이 없어도 intent 결과물은 동일 형식이어야 한다.

## Intent Output Contract

### Plan

- 입력: 사용자 요구사항, architecture/roadmap/rules
- 출력: 목표/제약, 구현 단계, 위험 요소, 검증 계획
- 완료 조건: 실행 가능한 단계별 계획이 확정됨

### Build

- 입력: plan 산출물
- 출력: 코드 변경, 테스트 결과, 문서 갱신
- 완료 조건: plan 범위 구현 + 빌드/테스트 통과

### Review

- 입력: 최종 코드와 변경 내역
- 출력: 이슈 목록(심각도/근거), 즉시 반영 항목, 사용자 판단 항목
- 완료 조건: required gate 충족 + 미해결 치명 이슈 0

## Example Adapter Mapping

- `claude` engine: Claude Code 명령/워크플로우로 intent 수행
- `codex` engine: Codex CLI 명령/워크플로우로 intent 수행
- `openai` engine: OpenAI API 기반 내부 워크플로우로 intent 수행
- `cursor`, `copilot`, `gemini`: 도구별 인터페이스는 달라도 위 intent contract는 유지

## Compatibility Rule

- 엔진 전환 시 rules 문서는 바꾸지 않는다.
- 변경은 `project-profile.md`의 engine/model 값만 수정해 반영한다.
- intent contract를 충족할 수 없는 도구는 해당 단계 엔진으로 선택하지 않는다.
