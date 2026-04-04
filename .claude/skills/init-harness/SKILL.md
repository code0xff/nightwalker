---
name: init-harness
description: 프로젝트 시작 시 엔진/모델/게이트를 고정하는 초기화 workflow
user-invocable: true
---

# Init Harness

프로젝트 시작 단계에서 실행할 초기화 절차다.
목표는 엔진/모델/게이트를 한 번 확정하고 이후 일관되게 적용하는 것이다.

## 1. 프로파일 선택

다음 중 하나를 선택한다.

- `claude-default`: `Codex Plan → Claude Build → Codex Review`
- `generic-ai`: 범용 도구 조합으로 운영
- `lightweight-fast`: 속도 우선, 게이트를 recommended로 운영

필요하면 `.claude/profiles/`의 템플릿을 기준으로 시작한다.

## 2. 실행 엔진 고정

`.claude/project-profile.md`에 다음을 기록한다.

- `profile_name`
- `plan_engine`, `build_engine`, `review_engine`
- 필요하면 `plan_model`, `build_model`, `review_model`
- `plan_gate`, `review_gate` (`required`/`recommended`)

## 3. 검증

- rules의 required gate와 profile gate가 충돌하지 않는지 확인한다.
- 향후 `/plan`, `/workstream`, `/codex-review` 실행 시 이 고정값을 따를 수 있는지 확인한다.
- 프로젝트 README 또는 운영 문서에 활성 프로파일을 명시한다.
- `.claude/hooks/validate-project-profile.sh` 검증을 통과하는지 확인한다.

## 4. 변경 규칙

- 프로파일 변경은 설계 변경으로 취급한다.
- 변경 전 사용자 확인을 받고, 변경 이유를 커밋 메시지나 문서에 남긴다.
