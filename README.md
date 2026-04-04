# Claude Rules

AI 개발 워크플로우를 위한 harness rules/skills 모음.
기본값은 Claude 중심 프로파일을 권장하지만, 프로젝트 시작 시 엔진/모델을 고정해 범용으로 운영할 수 있다.

새 프로젝트에 `.claude/` 디렉토리를 복사하여 사용한다.

## 사용법

```bash
cp -r .claude/ /path/to/your-project/.claude/
```

## 구성

## Harness 정책

이 저장소는 `Core Rules + Engine Profile` 구조를 사용한다.

- Core Rules: 품질/테스트/보안/커밋/문서 기준 (엔진 중립)
- Engine Profile: Plan/Build/Review를 어떤 엔진/모델로 수행할지 결정

기본 권장 프로파일은 현재와 동일하다.

`Codex Plan → Claude Build → Codex Review`

프로젝트 시작 시 `/init-harness`로 엔진/모델을 고정하면, 이후 모든 실행은 해당 고정값을 따른다.
세부 규칙은 `.claude/rules/engine-profile.md`, `.claude/rules/workflow.md`, `CLAUDE.md`를 따른다.


### Rules (12개) — 개발 원칙

| 파일 | 역할 |
|------|------|
| `guardrails.md` | 코드 품질, 에러 처리, 외부 연동, 확장성 |
| `security.md` | 입력 검증, secrets, 로깅 보안, 최소 권한 |
| `dependencies.md` | 의존성 추가/업데이트/제거 기준 |
| `docs.md` | 문서 유형, README/API 기준, 품질 원칙 |
| `testing.md` | 테스트 레이어, 원칙, 규칙 |
| `commits.md` | 커밋 단위, 메시지, 히스토리 품질 |
| `engine-profile.md` | 엔진/모델 프로파일, 기본값/고정값 정책 |
| `engine-adapters.md` | 엔진별 실행 매핑과 intent contract |
| `token-optimization.md` | 컨텍스트/토큰 사용 최적화 기준 |
| `autopilot.md` | 완전 자동 실행 루프와 중단/위험 정책 |
| `workflow.md` | 워크플로우, 문서 계층, workstream 규칙 |
| `autonomy.md` | 자율 실행 범위, 사용자 확인 경계, 에스컬레이션 |

### Skills (7개) — 실행 워크플로우

| 스킬 | 역할 |
|------|------|
| `/plan` | 구현 전 설계 및 계획 수립 |
| `/init-harness` | 프로젝트 시작 시 엔진/모델/게이트 고정 |
| `/autopilot` | 목표 기반 end-to-end 자동 실행 |
| `/workstream` | Workstream 시작~종료 오케스트레이션 |
| `/codex-review` | 구현 완료 후 외부 Codex CLI 반복 리뷰 |
| `/self-review` | 구현 완료 후 내부 thinking mode 반복 리뷰 |
| `/security-review` | 구현 완료 후 보안 관점 반복 리뷰 |

### 라이프사이클

```
/init-harness → /plan → /workstream (구현 + 리뷰 포함) → (push)
```

`/workstream`은 구현, 커밋, 코드 리뷰를 내부에서 순차 수행한다. 변경 크기에 따라 경량 리뷰(빌드+테스트만) 또는 전체 리뷰(`/codex-review` + `/self-review`)를 선택한다. 리뷰를 별도로 실행하려면 `/workstream` 없이 직접 호출한다.

## 프로젝트별 확장

복사 후 프로젝트에 맞게 추가할 것:

- `docs/architecture.md` — 프로젝트 아키텍처 문서
- `docs/roadmap/` — Workstream 정의와 deliverable
- `.claude/project-profile.md` — 프로젝트 엔진/모델 고정값
- `.claude/project-approvals.md` — 프로젝트 사전 승인 범위
- `.claude/project-automation.md` — 자동화 모드/재시도/게이트 정책
- `.claude/profiles/` — 프로파일 템플릿(claude-default, generic-ai, lightweight-fast)
- `.claude/rules/` — 프로젝트 특화 규칙 추가
- `.claude/settings.json` — 프로젝트에서 사용하는 빌드/테스트 도구에 맞게 권한 추가 (예: `Bash(cargo:*)`, `Bash(go:*)`, `Bash(make:*)`)
- `.claude/tests/harness-regression.sh` — 하네스 회귀 테스트

## Enforcement

- 모든 `Bash` 실행 전 `project-approvals` 기반 pre-approval hook이 실행된다.
- 모든 `Bash` 실행 전 `project-automation` 기반 risk-tier hook이 실행된다.
- `git commit`, `git push` 전에 `.claude/project-profile.md` 유효성 검증 hook이 실행된다.
- `git commit`, `git push` 전에 `.claude/project-approvals.md` 유효성 검증 hook이 실행된다.
- `git commit`, `git push` 전에 `.claude/project-automation.md` 유효성 검증 hook이 실행된다.
- `git push` 전에 automation gate(lint/build/test/security)가 자동 실행된다.
- profile 필수 키 누락, gate 값 오류, placeholder 값(`user-selected`) 미확정 상태는 commit/push를 차단한다.
- `run_gates_on_push: true`일 때 gate command를 `unset`으로 둘 수 없다.

## Automation Bootstrap

프로젝트별 lint/build/test 명령이 아직 미확정이면 아래로 후보를 자동 감지한다.

```bash
.claude/hooks/suggest-automation-gates.sh
```

감지 결과를 검토한 뒤 `.claude/project-automation.md` 값을 확정한다.

## Autopilot State

`/autopilot` 실행 상태는 `.claude/state/autopilot-state.json`에 기록한다.
실패/중단 후 재개 시 이 파일의 `last_stage`, `last_gate_result`, `error`를 기준으로 이어서 실행한다.

실행 예시:

```bash
.claude/hooks/run-autopilot.sh start "your-goal"
.claude/hooks/run-autopilot.sh resume
```

## CI Enforcement

GitHub Actions(`.github/workflows/harness-ci.yml`)가 push/PR마다 회귀 테스트를 실행한다.

```bash
.claude/tests/harness-regression.sh
```
