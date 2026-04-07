# dev-harness

AI 개발 워크플로우를 위한 harness rules/skills 모음.
기본값은 Claude 중심 프로파일을 권장하지만, 프로젝트 시작 시 엔진/모델을 고정해 범용으로 운영할 수 있다.

## 빠른 시작 (curl|bash 단독)

빈 폴더에서 아래 한 줄만 실행하면 `.claude`와 `.devharness`를 자동으로 설치하고 온보딩을 시작한다.

```bash
mkdir my-project && cd my-project
curl -fsSL https://raw.githubusercontent.com/code0xff/dev-harness/main/scripts/bootstrap-project.sh | bash
```

이 명령은 `dev-harness`를 자동으로 내려받아 실행 권한을 맞추고 온보딩 훅을 1회 실행한다.
이후 Claude에서 `/init-project`를 실행하면 목표/스택 확정과 문서/정책 동기화가 자동으로 완료되고, 준비가 끝나면 autopilot이 `/plan -> build`를 이어서 수행한다. 기본 목표는 remote 없이 로컬 개발을 끝까지 완주하는 것이다.

`session.yaml`을 수동으로 편집한 경우에만 아래 명령으로 동기화를 다시 실행한다.

```bash
.claude/hooks/run-project-onboarding.sh
```

## 수동 사용법

새 프로젝트에 `.claude/`와 `.devharness/`를 복사해 사용할 수도 있다.

```bash
cp -r .claude/ /path/to/your-project/.claude/
cp -r .devharness/ /path/to/your-project/.devharness/
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

### Skills (8개) — 실행 워크플로우

| 스킬 | 역할 |
|------|------|
| `/plan` | 구현 전 설계 및 계획 수립 |
| `/init-harness` | 프로젝트 시작 시 엔진/모델/게이트 고정 |
| `/init-project` | 목표/스택 대화형 온보딩 후 개발 시작 문서 생성 |
| `/autopilot` | 목표 기반 end-to-end 자동 실행 |
| `/workstream` | Workstream 시작~종료 오케스트레이션 |
| `/codex-review` | 구현 완료 후 외부 Codex CLI 반복 리뷰 |
| `/self-review` | 구현 완료 후 내부 thinking mode 반복 리뷰 |
| `/security-review` | 구현 완료 후 보안 관점 반복 리뷰 |

### 라이프사이클

```
/init-project → /autopilot
```

`/autopilot`의 첫 단계인 `/plan`은 roadmap의 모든 workstream을 먼저 설계하고, 이후 build 단계가 그 순서대로 구현을 이어간다.
기본 `full-auto` 정책은 로컬 개발 완주와 자동 커밋까지를 범위로 두고, push/배포는 개발 후 별도 전략으로 분리한다.
구현 후에는 QA 단계에서 초기 요구사항 충족 여부를 다시 검수하고, 문제가 나오면 remediation workstream을 등록해 같은 flow로 후속 개발을 이어간다.
`/workstream`은 구현, 커밋, 코드 리뷰를 내부에서 순차 수행한다. 변경 크기에 따라 경량 리뷰(빌드+테스트만) 또는 전체 리뷰(`/codex-review` + `/self-review`)를 선택한다. 리뷰를 별도로 실행하려면 `/workstream` 없이 직접 호출한다.

여기서 `roadmap`은 프로젝트 전체 순서와 범위를 정의하는 상위 계획이고, `workstream`은 그 roadmap을 구성하는 개별 실행 단위다. 작은 프로젝트는 `docs/roadmap.md` 하나로 충분하지만, 필요하면 `docs/workstreams/` 아래에 단계별 문서를 분리해도 된다.

## 프로젝트별 확장

복사 후 프로젝트에 맞게 추가할 것:

- `docs/architecture.md` — 프로젝트 아키텍처 문서
- `docs/roadmap.md` — 전체 workstream 순서, 범위, 의존성을 정리하는 상위 계획 문서
- `.claude/project-profile.md` — 프로젝트 엔진/모델 고정값
- `.claude/project-approvals.md` — 프로젝트 사전 승인 범위
- `.claude/project-automation.md` — 자동화 모드/재시도/게이트 정책
- `.claude/completion-contract.md` — 앱 완료 판정 계약(artifact/smoke/acceptance/release)
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
- `git commit`, `git push` 전에 quality gate가 자동 실행될 수 있다.
- `git push` 전에 automation gate(lint/build/test/security)가 자동 실행된다.
- profile 필수 키 누락, gate 값 오류, placeholder 값(`user-selected`) 미확정 상태는 commit/push를 차단한다.
- `run_gates_on_push: true`일 때 gate command를 `unset`으로 둘 수 없다.

## Automation Bootstrap

프로젝트별 lint/build/test 명령이 아직 미확정이면 아래로 후보를 자동 감지한다.

```bash
.claude/hooks/suggest-automation-gates.sh
```

감지 결과를 검토한 뒤 `.claude/project-automation.md` 값을 확정한다.

초기 프로젝트 세팅을 자동화하려면 다음 bootstrap을 사용한다.

```bash
.claude/hooks/bootstrap-init-harness.sh
```

이 명령은 gate/quality/engine adapter 기본값과 approvals allowlist를 자동으로 채운다.
또한 completion contract를 현재 게이트 명령 기준으로 자동 연결한다.
또한 stage/fix 기본 명령(`implement_cmd`, `review_cmd`, `*_fix_cmd`)을 자동 연결한다.
또한 실제 intent 실행용 engine adapter 템플릿과 autopilot 로컬 완주 기본 정책을 자동 채운다.

새 프로젝트 온보딩(문서 생성 + 정책 검증 + ready 리포트)은 아래 명령으로 한 번에 수행한다.

```bash
.claude/hooks/run-project-onboarding.sh
```

온보딩 입력 상태는 `.devharness/session.yaml`에 저장된다.
이 파일을 기준으로 아래 문서가 자동 생성된다.

- `docs/project-goal.md`
- `docs/scope.md`
- `docs/architecture.md`
- `docs/stack-decision.md`
- `docs/roadmap.md`
- `docs/execution-plan.md`
- `ONBOARDING_READY.md`

## Non-Blocking Automation Policy

완전 자동화를 위해 기본 정책은 `report` 모드다.
위험/승인 미충족 항목이 있어도 실행은 진행하고, 경고는 리포트 파일로 남긴다.

- `.claude/state/policy-warnings.log`
- `.claude/state/unset-config-report.txt`
- `.claude/state/done-check-report.txt`

## Autopilot State

`/autopilot` 실행 상태는 `.claude/state/autopilot-state.json`에 기록한다.
실패/중단 후 재개 시 이 파일의 `last_stage`, `last_gate_result`, `error`를 기준으로 이어서 실행한다.
완료 직전에는 `.claude/hooks/run-done-check.sh`를 실행해 completion contract 기준을 점검한다.

실행 예시:

```bash
.claude/hooks/run-autopilot.sh start "your-goal"
.claude/hooks/run-autopilot.sh resume
```

완료 기준 점검만 단독 실행하려면:

```bash
.claude/hooks/run-done-check.sh
```

엔진 어댑터 실행:

```bash
.claude/hooks/run-engine-intent.sh plan "your-goal"
```

기본값은 `engine_runtime_mode: strict`, `execute_engine_commands: true`이며, 엔진 준비 상태를 강제 검증한다.
엔진 바이너리 미설치 환경에서는 `stub-fallback` + `allow_engine_stub: true`로 완화할 수 있다.

stage 실행과 복구에는 fallback 체인이 적용된다.

- `plan`: stage command → engine intent → inferred command
- `implement`: stage command → inferred command(build/test) → engine intent
- `review`: stage command → inferred command(quality/test) → engine intent
- gate fix: `<gate>_fix_cmd` → gate command → `implement_cmd` → gate 재감지
- qa: requirement QA → remediation workstream registration on failure
- delivery: done-check → auto commit

## CI Enforcement

GitHub Actions(`.github/workflows/harness-ci.yml`)가 push/PR마다 회귀 테스트를 실행한다.

```bash
.claude/tests/harness-regression.sh
```
