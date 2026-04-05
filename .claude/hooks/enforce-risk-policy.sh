#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"
CLASSIFIER=".claude/hooks/classify-risk.sh"

if [ ! -f "$AUTOMATION_FILE" ]; then
  echo "risk-policy 검증 실패: $AUTOMATION_FILE 파일이 없습니다." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "risk-policy 검증 실패: jq가 필요합니다." >&2
  exit 2
fi
if [ ! -x "$CLASSIFIER" ]; then
  echo "risk-policy 검증 실패: $CLASSIFIER 실행 권한이 필요합니다." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if [ -z "$COMMAND" ]; then
  exit 0
fi

split_segments() {
  local cmd="$1"
  echo "$cmd" | sed -E 's/(\&\&|\|\||\||;)/\n/g'
}

get_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

csv_contains() {
  local csv="$1"
  local needle="$2"
  echo "$csv" | tr ',' '\n' | tr -d ' ' | grep -Fxq "$needle"
}

allow_auto_push=$(get_value "allow_auto_push")
require_user=$(get_value "require_user_for_risk_tier")
auto_apply=$(get_value "auto_apply_risk_tier")
risk_tier=$("$CLASSIFIER" "$COMMAND")

while IFS= read -r raw_segment; do
  segment=$(echo "$raw_segment" | awk '{$1=$1; print}')
  [ -z "$segment" ] && continue

  if [[ "$segment" =~ ^git[[:space:]]+push([[:space:]]|$) ]] && [ "$allow_auto_push" != "true" ]; then
    echo "risk-policy 차단: allow_auto_push=false 상태에서 push는 금지됩니다." >&2
    echo "command=$segment" >&2
    exit 2
  fi
done < <(split_segments "$COMMAND")

if csv_contains "$require_user" "$risk_tier"; then
  echo "risk-policy 차단: ${risk_tier} 변경은 사용자 명시 승인이 필요합니다." >&2
  echo "command=$COMMAND" >&2
  exit 2
fi

if csv_contains "$auto_apply" "$risk_tier"; then
  exit 0
fi

if [ "$risk_tier" = "high" ] || [ "$risk_tier" = "critical" ]; then
  echo "risk-policy 차단: ${risk_tier} 티어가 자동 허용 목록에 없습니다." >&2
  echo "command=$COMMAND" >&2
  exit 2
fi

exit 0
