#!/bin/bash

set -euo pipefail

CONTRACT_FILE=".claude/completion-contract.md"

if [ ! -f "$CONTRACT_FILE" ]; then
  echo "completion-contract 검증 실패: $CONTRACT_FILE 파일이 없습니다." >&2
  exit 2
fi

required_keys=(
  "done_enforcement"
  "artifact_definition"
  "artifact_check_cmd"
  "run_smoke_cmd"
  "acceptance_test_cmd"
  "release_readiness_cmd"
)

for key in "${required_keys[@]}"; do
  if ! grep -Eq "^- ${key}:[[:space:]]*.+" "$CONTRACT_FILE"; then
    echo "completion-contract 검증 실패: '${key}' 값이 없습니다." >&2
    exit 2
  fi
done

get_value() {
  local key="$1"
  grep -E "^- ${key}:" "$CONTRACT_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

done_enforcement="$(get_value done_enforcement)"
if [ "$done_enforcement" != "report" ] && [ "$done_enforcement" != "block" ]; then
  echo "completion-contract 검증 실패: done_enforcement는 report 또는 block이어야 합니다." >&2
  exit 2
fi

exit 0
