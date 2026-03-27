---
name: phase-review
description: Phase 종료 시 self-review — 현재 phase 범위 내 코드/문서 품질 검증
user_invocable: true
---

# Phase $ARGUMENTS Review

## Review 범위

- 현재 phase 문서를 읽고 해당 phase에서 실제 구현된 코드와 문서로 제한한다.
- 다음 phase에서 자연스럽게 다뤄질 내용, 미래 확장 이슈, 아직 구현되지 않은 컴포넌트를 전제로 한 우려는 포함하지 않는다.
- 현재 phase 범위를 넘는 리팩토링은 현재 phase 품질에 직접 영향을 주지 않으면 제외한다.

## Review 관점

1. **Bug 및 Issue** — 현재 코드에 존재하는 버그나 잘못된 동작
2. **Behavior Regression** — 기존 동작을 깨뜨릴 가능성
3. **Missing Validation** — 누락된 입력 검증이나 에러 처리
4. **Test Gap** — 테스트가 부족한 경로나 edge case
5. **Refactor Candidate** — 현재 phase 품질에 직접 영향을 주는 리팩토링 후보

## 보고 형식

review 결과를 사용자에게 다음 형식으로 보고한다:

### 발견된 버그 및 이슈
(없으면 `없음`)

### 즉시 수정이 필요한 항목
(없으면 `없음`)

### 추후 리팩토링 후보
(없으면 `없음`)

## 후속 조치

- review 결과가 architecture, roadmap, rules 변경을 요구하면 해당 문서까지 갱신한다.
