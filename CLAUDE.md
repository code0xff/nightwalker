# Claude Rules Harness

이 저장소는 AI 코딩 에이전트의 개발 행동을 제어하는 harness다.
기본값은 Claude 중심 프로파일을 권장하지만, 프로젝트별 고정 프로파일을 우선한다.
rules/는 개발 규칙, skills/는 실행 가능한 워크플로우를 정의한다.

## 구조

- `.claude/rules/` — 개발 규칙 (코드 품질, 테스트, 보안, 커밋, 문서, 의존성, 워크플로우, 자율 범위)
- `.claude/skills/` — 실행 워크플로우 (/init-harness, /autopilot, /plan, /workstream, /self-review, /codex-review, /security-review)
- `.claude/project-profile.md` — 프로젝트 엔진/모델/게이트 고정값 (없으면 기본 권장 프로파일 적용)
- `.claude/project-approvals.md` — 프로젝트 사전 승인 범위
- `.claude/project-automation.md` — 자동화 실행 정책
- `.claude/completion-contract.md` — 앱 완료 판정 계약
- `.claude/state/autopilot-state.json` — autopilot 상태/재개 지점
- `.claude/tests/harness-regression.sh` — 하네스 회귀 테스트
- `.claude/hooks/run-engine-intent.sh` — plan/build/review 엔진 어댑터 실행기
- `.claude/profiles/` — 프로파일 템플릿 모음

## 핵심 플로우

rules/는 모든 작업에 항상 적용된다. 실행 엔진/모델은 `.claude/project-profile.md`를 우선한다.

기본 권장 프로파일은 다음과 같다.

1. **Plan (Codex 권장)** — `/plan`
2. **Build (Claude 권장)** — `/workstream` 또는 직접 구현
3. **Review (Codex 권장)** — `/codex-review`
4. Security review — `/security-review` (권장, 민감 변경 시 필수)

활성 프로파일에서 required인 게이트(`plan_gate`, `review_gate`)가 누락되면 작업을 완료로 보고하지 않는다.

### workstream 기반 (기능 개발, 대규모 변경)

1. `/plan` (profile.plan_engine) — 설계 및 구현 계획 수립
2. `/workstream` (profile.build_engine) — 계획 실행 (체크리스트 기반)
   - feature 단위마다 `/self-review` 실행
3. workstream 완료 리뷰 — `/codex-review` (profile.review_engine에 따라 필수/권장) → `/security-review`

### 단순 작업 (버그 수정, 설정 변경, 소규모 개선)

규모가 작아도 Plan/Review 게이트는 동일하다.
- 최소: `/plan` → 구현(profile.build_engine) → `/codex-review`
- 변경 후 빌드와 테스트 통과를 확인한다.

## 프로젝트 시작 고정

새 프로젝트 시작 시 `/init-harness`를 먼저 실행한다.

- 엔진 세트 선택: `claude-default` 또는 `generic-ai`
- plan/build/review 엔진 고정
- 필요 시 단계별 모델 고정
- gate 강도(`required`/`recommended`) 고정

고정 이후에는 권장값보다 프로젝트 고정값을 우선한다.
자동화 gate 명령이 비어 있으면 `.claude/hooks/suggest-automation-gates.sh`로 후보를 채우고 확정한다.
초기 프로젝트 입력을 줄이려면 `.claude/hooks/bootstrap-init-harness.sh`로 gate/quality/engine/allowlist/completion-contract를 자동 채운다.
autopilot 실행/재개는 `.claude/hooks/run-autopilot.sh start|resume`를 사용한다.
완료 판정 검증은 `.claude/hooks/run-done-check.sh`를 사용한다.
엔진 어댑터 직접 실행은 `.claude/hooks/run-engine-intent.sh <plan|build|review> "<goal>"`를 사용한다.
기본 설정은 strict runtime(`engine_runtime_mode: strict`, `execute_engine_commands: true`)이며 엔진 바이너리 준비 상태를 강제한다.
완전 자동화 기본 정책은 non-blocking report 모드(`preapproval_enforcement/risk_enforcement/unresolved_config_enforcement=report`)다.

## 다른 프로젝트에 적용

1. `.claude/` 디렉토리를 프로젝트 루트에 복사한다.
2. settings.json의 permissions를 프로젝트 환경에 맞게 조정한다.
3. settings.json에 hooks를 설정한다 (아래 Hooks 설정 참조).
4. 프로젝트에 이미 CLAUDE.md가 있으면 이 harness 설명을 병합한다.

### Hooks 설정

settings.json에 프로젝트 환경에 맞는 hooks를 설정한다.
Claude Code hooks는 이벤트 기반으로, 도구 실행 전후에 검증을 수행한다.

#### 필수

- **커밋 메시지 형식 검증** — `type: message` 형식 강제 (commits.md 참조)
- **사전 승인 강제** — 모든 Bash 명령을 project-approvals allowlist 기준으로 검증
- **리스크 티어 강제** — high/critical 명령은 project-automation risk policy로 차단
- **프로젝트 프로파일 검증** — commit/push 전 `.claude/project-profile.md` 필수 키/값 검증
- **사전 승인 범위 검증** — commit/push 전 `.claude/project-approvals.md` 필수 섹션 검증
- **자동화 정책 검증** — commit/push 전 `.claude/project-automation.md` 필수 키/값 검증
- **자동 게이트 실행** — push 전 lint/build/test/security gate 실행 (project-automation 기준)
- **품질 게이트 실행** — commit/push 전 quality_cmd 실행 (설정 시)

#### 권장 (프로젝트별 명령어 설정)

- **빌드 검증** — 커밋 전 빌드 통과 확인
- **테스트 실행** — 커밋 전 변경 범위 테스트 통과 확인
- **Lint** — 코드 스타일 일관성 확인
- **CI 회귀 테스트** — push/PR에서 `.claude/tests/harness-regression.sh` 실행

#### 설정 예시

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "커밋 메시지 형식 검증 스크립트 경로",
            "if": "Bash(git commit*)"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "프로젝트 lint 명령어"
          }
        ]
      }
    ]
  }
}
```

프로젝트의 빌드 도구에 맞게 명령어를 교체한다.
