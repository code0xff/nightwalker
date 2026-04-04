# Project Pre-Approvals

프로젝트에서 반복적으로 사용하는 명령/행동의 사전 승인 범위를 정의한다.
이 파일은 팀 합의 문서이며, 변경 시 사용자 확인이 필요하다.

## Command Prefix Allowlist

- `git add`
- `git commit`
- `git push`
- `npm run build`
- `npm test`

프로젝트별로 실제 사용하는 명령만 남기고 불필요한 항목은 제거한다.

## Always Require Explicit Approval

- 의존성 추가/제거
- 브랜치 삭제
- force push
- secrets 또는 credentials 관련 파일 변경
- rules/skills/profile 수정
- project-automation 정책 수정

## Sandbox / Escalation Policy

- 샌드박스에서 실패하면 동일 명령을 `require_escalated`로 1회 재시도한다.
- 재시도도 실패하면 원인과 필요한 권한을 사용자에게 보고한다.

## Audit

- 사전 승인 범위 변경 시 커밋 메시지에 변경 이유를 남긴다.
