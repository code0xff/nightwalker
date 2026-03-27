## Commit Units

- 개발 작업은 가능한 한 작은 독립 단위로 나눈다.
- 하나의 commit은 하나의 명확한 목적만 담는다.
- commit은 가능하면 독립적으로 리뷰 가능해야 한다.
- commit은 가능하면 독립적으로 되돌릴 수 있어야 한다.
- 큰 작업도 여러 개의 작은 commit으로 나눠 진행한다.
- 인터페이스 정의, 구현체 추가, 테스트 추가, 문서 반영은 가능한 분리하되, 하나의 의미 있는 작업 단위가 깨질 정도로 과하게 쪼개지 않는다.

## Feature-scoped Commit Workflow

- 구현은 기능 단위(feature scope)로 나눈다.
- 각 기능 단위는 구현을 먼저 커밋하고, 테스트는 별도 커밋으로 분리할 수 있다. 단, contract test 선행 규칙(testing.md)이 적용되는 인터페이스 변경은 contract test를 먼저 커밋한다.
- 기능 단위 간 의존성이 있으면 의존되는 쪽을 먼저 커밋한다.
- 각 커밋 후 빌드와 기존 테스트가 통과해야 한다.

## Message Format

- commit message 형식은 `type: commit message`로 통일한다.
- 권장 type: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
- `commit message`는 무엇을 바꿨는지 짧고 구체적으로 적는다.

## Pre-commit Checks

- commit 전에는 빌드 검증과 해당 변경 범위 테스트를 수행한다.

## History Quality

- 작업 완료 전에도 의미 있는 하위 milestone마다 commit을 남긴다.
- 구현 순서가 commit history만 봐도 따라갈 수 있게 유지한다.
- 문서 변경이 코드 변경과 직접 연결되면 같은 commit 또는 바로 이어지는 commit으로 남긴다.
- 작업 종료 시 commit history만 읽어도 구현 순서와 의도를 따라갈 수 있어야 한다.
- 나중에 squashing을 기대한 임시 잡탕 commit보다 읽히는 history를 우선한다.

## Prohibited

- 관련 없는 변경을 한 commit에 섞지 않는다.
- 여러 작업 단위의 변경을 하나의 commit으로 묶지 않는다.
- 테스트가 깨진 중간 상태를 의미 있는 완료 commit으로 남기지 않는다.
