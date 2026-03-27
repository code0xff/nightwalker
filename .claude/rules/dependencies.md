## Adding New Dependencies

- 새 의존성을 추가하기 전에 stdlib 또는 기존 의존성으로 해결 가능한지 먼저 확인한다.
- 의존성 추가 시 다음을 평가한다:
  - 유지보수 상태 (최근 릴리스, 이슈 대응 속도)
  - 라이선스 호환성
  - 패키지 크기와 transitive dependency 수
  - 프로젝트에서 실제로 사용할 기능 대비 패키지 전체 크기

## Updating Dependencies

- 의존성 업데이트 시 breaking change를 반드시 확인한다.
- major 버전 업데이트는 changelog을 읽고 migration guide가 있으면 따른다.
- 업데이트 후 빌드와 테스트가 통과하는지 확인한다.

## Removing Dependencies

- 더 이상 사용하지 않는 의존성은 제거한다.
- 제거 전 프로젝트 내 실제 사용처가 없는지 검색으로 확인한다.
