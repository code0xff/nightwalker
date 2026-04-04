## General Workflow

- 구현 전에 변경의 영향 범위를 파악한다.
- 변경 후에는 빌드와 관련 테스트로 검증한다.
- 설계 문서가 있으면 구현 전에 확인하고, 구현이 문서와 어긋나면 문서를 갱신하거나 구현을 조정한다.
- 서브 에이전트 활용과 자율 범위는 autonomy.md를 따른다.

## Source of Truth Hierarchy

1. Architecture 문서 (있는 경우)
2. Roadmap / workstream 문서 (있는 경우)
3. Rules (`.claude/rules/`)

구조적 결정은 architecture 문서가 기준이고, 구현 순서는 roadmap이 기준이며, 개발 방식은 rules가 기준이다. 해당 문서가 없는 프로젝트에서는 rules만을 기준으로 한다.

- 문서와 실제 구현이 불일치하는 경우 문서를 우선한다. 구현을 문서에 맞게 수정하거나, 의도적 변경이라면 문서를 먼저 갱신한 후 구현한다.

## When To Update Documents

- 계층 책임, baseline 기술 선택이 바뀌면 → architecture 갱신
- workstream 범위, deliverable, exit criteria가 바뀌면 → roadmap 갱신
- workflow, guardrail, 테스트 기준이 바뀌면 → rules 갱신
- 구현 중 바뀐 설정 키, 타입, 인터페이스가 있으면 관련 문서에 반영
- 문서 작성 기준은 docs rule을 따른다

## Mandatory Harness Pipeline

이 저장소의 기본 엔진은 Claude Code다. 다만 아래 단계는 필수 게이트로 강제한다.

1. Plan 단계: **Codex 필수** (`/plan` 산출물)
2. Build 단계: **Claude 필수** (plan 범위 내 구현)
3. Review 단계: **Codex 필수** (`/codex-review`)

Plan(Codex) 또는 Review(Codex) 중 하나라도 누락되면 작업 완료로 간주하지 않는다.

## Workstream Execution Rules

workstream 기반 개발을 하는 프로젝트에서 적용한다:

- 현재 workstream에서 필요한 최소 인터페이스만 먼저 만든다.
- 구현 전에 다음 workstream 기능을 미리 섞지 않는다.
- 테스트 없이 핵심 계약이나 인터페이스를 추가하지 않는다.
- 이번 작업의 구현 범위를 현재 workstream 안으로 잠근다.
- roadmap workstream 범위를 넘어 구현하지 않는다.
- Build 단계는 Claude로 수행한다.
- Plan 산출물 범위를 벗어나는 변경은 금지한다. 불가피한 경우 `/plan`을 다시 실행해 계획을 갱신한다.

## Workstream Completion Verification

workstream 구현 중과 완료 시 다음 리뷰를 수행한다:

- `/self-review`는 workstream 실행 중 feature 단위마다 실행하여 문제를 조기에 발견한다.
- workstream 완료 시 다음 순서대로 실행한다. 각 리뷰의 수정이 커밋된 후 다음 리뷰를 진행하여, 항상 최신 코드를 대상으로 분석한다.

1. `/codex-review`로 외부 리뷰를 실행하고, 지적 사항을 평가하여 타당한 항목은 반영한다. (**필수 게이트**)
2. `/security-review`로 보안 관점 분석을 실행하고, 취약점·민감 정보 노출·권한 문제를 확인하여 반영한다.

- `/codex-review`가 누락되거나 미해결 지적이 남아 있으면 완료 보고를 금지한다.
- 모든 리뷰가 즉시 반영 항목이 0건(clean pass)이 될 때까지 반복한다.
- 리뷰 결과를 사용자에게 보고한다.

## Context 관리

- 장시간 작업 시 중간 결과를 커밋하여 코드 상태와 의도를 보존한다.
- 대화 간 유지해야 할 정보(결정 사항, 사용자 선호, 프로젝트 맥락)는 memory에 저장한다.
- 대규모 탐색이나 조사는 서브 에이전트로 분리하여 메인 context의 오염을 방지한다.
- rules/ 전체 instruction 수를 200개 이하로 유지한다. 상세 절차는 skills로 분리하여 필요 시에만 로드한다.

## Future Ideas Rule

- future 확장 아이디어는 architecture 또는 roadmap의 future note에 남긴다. 해당 문서가 없는 프로젝트에서는 이슈 트래커에 기록한다.
- rules에는 현재 구현에서 실제로 지켜야 하는 규칙만 남긴다.
- 현재 구현 결정과 future idea를 같은 문장 안에 섞지 않는다.
