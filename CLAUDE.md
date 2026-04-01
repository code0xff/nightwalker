# Claude Rules Harness

이 저장소는 Claude Code의 개발 행동을 제어하는 harness다.
rules/는 개발 규칙, skills/는 실행 가능한 워크플로우를 정의한다.

## 구조

- `.claude/rules/` — 개발 규칙 (코드 품질, 테스트, 보안, 커밋, 문서, 의존성, 워크플로우, 자율 범위)
- `.claude/skills/` — 실행 워크플로우 (/plan, /phase, /self-review, /codex-review, /security-review)

## 핵심 플로우

rules/는 모든 작업에 항상 적용된다. skills/는 작업 규모에 따라 선택적으로 사용한다.

### phase 기반 (기능 개발, 대규모 변경)

1. `/plan` — 설계 및 구현 계획 수립
2. `/phase` — 계획 실행 (체크리스트 기반)
   - feature 단위마다 `/self-review` 실행
3. phase 완료 리뷰 — `/codex-review` → `/security-review`

### 단순 작업 (버그 수정, 설정 변경, 소규모 개선)

rules를 따르되 skills 없이 진행한다. 변경 후 빌드와 테스트 통과를 확인한다.

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
