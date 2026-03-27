# Claude Rules

범용 개발 워크플로우를 위한 Claude Code rules와 skills 모음.

새 프로젝트에 `.claude/` 디렉토리를 복사하여 사용한다.

## 사용법

```bash
cp -r .claude/ /path/to/your-project/.claude/
```

## 구성

### Rules (7개) — 개발 원칙

| 파일 | 역할 |
|------|------|
| `guardrails.md` | 코드 품질, 에러 처리, 외부 연동, 확장성 |
| `security.md` | 입력 검증, secrets, 로깅 보안, 최소 권한 |
| `dependencies.md` | 의존성 추가/업데이트/제거 기준 |
| `docs.md` | 문서 유형, README/API 기준, 품질 원칙 |
| `testing.md` | 테스트 레이어, 원칙, 규칙 |
| `commits.md` | 커밋 단위, 메시지, 히스토리 품질 |
| `workflow.md` | 워크플로우, 문서 계층, phase 규칙 |

### Skills (6개) — 실행 워크플로우

| 스킬 | 역할 |
|------|------|
| `/plan` | 구현 전 설계 및 계획 수립 |
| `/phase` | Phase 시작~종료 오케스트레이션 |
| `/codex-review` | 외부 Codex CLI 반복 리뷰 |
| `/self-review` | 내부 thinking mode 반복 리뷰 |
| `/phase-review` | Phase 종료 품질 검증 |

### 라이프사이클

```
/plan → /phase → /codex-review + /self-review → commit → /phase-review
```

## 프로젝트별 확장

복사 후 프로젝트에 맞게 추가할 것:

- `docs/architecture.md` — 프로젝트 아키텍처 문서
- `docs/roadmap/` — Phase 정의와 deliverable
- `.claude/rules/` — 프로젝트 특화 규칙 추가
