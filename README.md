# Claude Rules

범용 개발 워크플로우를 위한 Claude Code rules와 skills 모음.

새 프로젝트에 `.claude/` 디렉토리를 복사하여 사용한다.

## 사용법

```bash
cp -r .claude/ /path/to/your-project/.claude/
```

## 구성

## Harness 정책

이 저장소의 기본 엔진은 **Claude Code**다.

다만 개발 업무 정형화를 위해 아래 게이트를 **필수**로 강제한다.

1. Plan: `/plan` (**Codex 필수**)
2. Build: 구현 실행 (**Claude 필수**)
3. Review: `/codex-review` (**Codex 필수**)

즉, 기본 플로우는 다음과 같다.

`Codex Plan → Claude Build → Codex Review`

세부 강제 규칙은 `.claude/rules/workflow.md`와 `CLAUDE.md`를 기준으로 한다.


### Rules (8개) — 개발 원칙

| 파일 | 역할 |
|------|------|
| `guardrails.md` | 코드 품질, 에러 처리, 외부 연동, 확장성 |
| `security.md` | 입력 검증, secrets, 로깅 보안, 최소 권한 |
| `dependencies.md` | 의존성 추가/업데이트/제거 기준 |
| `docs.md` | 문서 유형, README/API 기준, 품질 원칙 |
| `testing.md` | 테스트 레이어, 원칙, 규칙 |
| `commits.md` | 커밋 단위, 메시지, 히스토리 품질 |
| `workflow.md` | 워크플로우, 문서 계층, workstream 규칙 |
| `autonomy.md` | 자율 실행 범위, 사용자 확인 경계, 에스컬레이션 |

### Skills (5개) — 실행 워크플로우

| 스킬 | 역할 |
|------|------|
| `/plan` | 구현 전 설계 및 계획 수립 |
| `/workstream` | Workstream 시작~종료 오케스트레이션 |
| `/codex-review` | 구현 완료 후 외부 Codex CLI 반복 리뷰 |
| `/self-review` | 구현 완료 후 내부 thinking mode 반복 리뷰 |
| `/security-review` | 구현 완료 후 보안 관점 반복 리뷰 |

### 라이프사이클

```
/plan → /workstream (구현 + 리뷰 포함) → (push)
```

`/workstream`은 구현, 커밋, 코드 리뷰를 내부에서 순차 수행한다. 변경 크기에 따라 경량 리뷰(빌드+테스트만) 또는 전체 리뷰(`/codex-review` + `/self-review`)를 선택한다. 리뷰를 별도로 실행하려면 `/workstream` 없이 직접 호출한다.

## 프로젝트별 확장

복사 후 프로젝트에 맞게 추가할 것:

- `docs/architecture.md` — 프로젝트 아키텍처 문서
- `docs/roadmap/` — Workstream 정의와 deliverable
- `.claude/rules/` — 프로젝트 특화 규칙 추가
- `.claude/settings.json` — 프로젝트에서 사용하는 빌드/테스트 도구에 맞게 권한 추가 (예: `Bash(cargo:*)`, `Bash(go:*)`, `Bash(make:*)`)
