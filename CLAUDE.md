# Claude Rules Harness

이 저장소는 AI 코딩 에이전트의 개발 행동을 제어하는 harness다.
기본값은 Claude 중심 프로파일을 권장하지만, 프로젝트별 고정 프로파일을 우선한다.
rules/는 개발 규칙, skills/는 실행 가능한 워크플로우를 정의한다.

## 구조

- `.claude/rules/` — 개발 규칙 (코드 품질, 테스트, 보안, 커밋, 문서, 의존성, 워크플로우, 자율 범위)
- `.claude/skills/` — 실행 워크플로우 (/init-harness, /plan, /workstream, /self-review, /codex-review, /security-review)
- `.claude/project-profile.md` — 프로젝트 엔진/모델/게이트 고정값 (없으면 기본 권장 프로파일 적용)
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
- **프로젝트 프로파일 검증** — commit/push 전 `.claude/project-profile.md` 필수 키/값 검증

#### 권장 (프로젝트별 명령어 설정)

- **빌드 검증** — 커밋 전 빌드 통과 확인
- **테스트 실행** — 커밋 전 변경 범위 테스트 통과 확인
- **Lint** — 코드 스타일 일관성 확인

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
