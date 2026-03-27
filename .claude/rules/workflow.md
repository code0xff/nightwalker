## General Workflow

- 구현 전에 변경의 영향 범위를 파악한다.
- 변경 후에는 빌드와 관련 테스트로 검증한다.
- 설계 문서가 있으면 구현 전에 확인하고, 구현이 문서와 어긋나면 문서를 갱신하거나 구현을 조정한다.

## Source of Truth Hierarchy

1. Architecture 문서 (있는 경우)
2. Roadmap / phase 문서 (있는 경우)
3. Rules (`.claude/rules/`)

구조적 결정은 architecture 문서가 기준이고, 구현 순서는 roadmap이 기준이며, 개발 방식은 rules가 기준이다. 해당 문서가 없는 프로젝트에서는 rules만을 기준으로 한다.

## When To Update Documents

- 계층 책임, baseline 기술 선택이 바뀌면 → architecture 갱신
- phase 범위, deliverable, exit criteria가 바뀌면 → roadmap 갱신
- workflow, guardrail, 테스트 기준이 바뀌면 → rules 갱신
- 구현 중 바뀐 설정 키, 타입, 인터페이스가 있으면 관련 문서에 반영
- 문서 작성 기준은 docs rule을 따른다

## Phase Execution Rules

phase 기반 개발을 하는 프로젝트에서 적용한다:

- 현재 phase에서 필요한 최소 인터페이스만 먼저 만든다.
- 구현 전에 다음 phase 기능을 미리 섞지 않는다.
- 테스트 없이 핵심 계약이나 인터페이스를 추가하지 않는다.
- 이번 작업의 구현 범위를 현재 phase 안으로 잠근다.
- roadmap phase 범위를 넘어 구현하지 않는다.

## Future Ideas Rule

- future 확장 아이디어는 architecture 또는 roadmap의 future note에 남긴다. 해당 문서가 없는 프로젝트에서는 이슈 트래커나 별도 `future.md`에 기록한다.
- rules에는 현재 구현에서 실제로 지켜야 하는 규칙만 남긴다.
- 현재 구현 결정과 future idea를 같은 문장 안에 섞지 않는다.
