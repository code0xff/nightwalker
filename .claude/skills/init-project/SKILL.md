---
name: init-project
description: 프로젝트 목표를 대화형으로 정리하고 스택 3안 비교 후 개발 시작 문서를 확정하는 workflow
user-invocable: true
---

# Init Project

새 프로젝트를 개발 실행 직전 상태까지 끌어올리는 대화형 온보딩 절차다.

## 목적

- 프로젝트 목표/대상 사용자/핵심 기능/제약을 확정한다.
- 기술 스택 3안을 비교하고 사용자 선택으로 최종 스택을 확정한다.
- 문서 6종과 하네스 정책 파일을 최신화해 바로 `/plan`으로 넘어갈 수 있게 만든다.

## 실행 순서

1. `.devharness/session.yaml`을 먼저 읽는다.
2. 아래 질문을 통해 미확정 값을 채운다.
   - project_goal
   - target_users
   - core_features
   - constraints
3. stack 후보 3개를 제시한다.
   - 각 후보의 장점/리스크/운영 비용을 간단히 제시한다.
4. 사용자가 최종 `selected_stack`을 고르게 한다.
5. 확정값을 `session.yaml`에 반영하도록 편집을 수행한다.
6. 아래 명령을 실행해 문서/정책을 동기화한다.

```bash
.claude/hooks/run-project-onboarding.sh
```

## 산출물

- `docs/project-goal.md`
- `docs/scope.md`
- `docs/architecture.md`
- `docs/stack-decision.md`
- `docs/roadmap.md`
- `docs/execution-plan.md`
- `ONBOARDING_READY.md`

## 완료 조건

- `ONBOARDING_READY.md`가 생성된다.
- `status`가 `ready` 또는 `proposed`로 갱신된다.
- 미확정 항목이 남으면 사용자에게 어떤 값을 확정해야 하는지 명확히 안내한다.
