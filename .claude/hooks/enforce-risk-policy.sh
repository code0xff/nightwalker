#!/bin/bash

set -euo pipefail

AUTOMATION_FILE=".claude/project-automation.md"

if [ ! -f "$AUTOMATION_FILE" ]; then
  echo "risk-policy 검증 실패: $AUTOMATION_FILE 파일이 없습니다." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "risk-policy 검증 실패: jq가 필요합니다." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if [ -z "$COMMAND" ]; then
  exit 0
fi

trim() {
  echo "$1" | awk '{$1=$1; print}'
}

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

while IFS= read -r raw_segment; do
  segment=$(trim "$raw_segment")
  [ -z "$segment" ] && continue

  risk_tier="low"
  if [[ "$segment" =~ git[[:space:]]+push.*(--force|-f)([[:space:]]|$) ]] || [[ "$segment" =~ rm[[:space:]].*-rf[[:space:]]+/ ]]; then
    risk_tier="critical"
  elif [[ "$segment" =~ (^|[[:space:]])(npm|pnpm|yarn)[[:space:]]+(install|add|remove|uninstall|update)([[:space:]]|$) ]] \
    || [[ "$segment" =~ (^|[[:space:]])pip([0-9.]*)[[:space:]]+(install|uninstall)([[:space:]]|$) ]] \
    || [[ "$segment" =~ (^|[[:space:]])poetry[[:space:]]+(add|remove|update)([[:space:]]|$) ]] \
    || [[ "$segment" =~ (^|[[:space:]])cargo[[:space:]]+(add|remove)([[:space:]]|$) ]] \
    || [[ "$segment" =~ (^|[[:space:]])go[[:space:]]+get([[:space:]]|$) ]] \
    || [[ "$segment" =~ git[[:space:]]+branch[[:space:]]+(-D|--delete)([[:space:]]|$) ]]; then
    risk_tier="high"
  fi

  if [[ "$segment" =~ ^git[[:space:]]+push([[:space:]]|$) ]] && [ "$allow_auto_push" != "true" ]; then
    echo "risk-policy 차단: allow_auto_push=false 상태에서 push는 금지됩니다." >&2
    echo "command=$segment" >&2
    exit 2
  fi

  if csv_contains "$require_user" "$risk_tier"; then
    echo "risk-policy 차단: ${risk_tier} 변경은 사용자 명시 승인이 필요합니다." >&2
    echo "command=$segment" >&2
    exit 2
  fi

  if csv_contains "$auto_apply" "$risk_tier"; then
    continue
  fi

  if [ "$risk_tier" = "high" ] || [ "$risk_tier" = "critical" ]; then
    echo "risk-policy 차단: ${risk_tier} 티어가 자동 허용 목록에 없습니다." >&2
    echo "command=$segment" >&2
    exit 2
  fi
done < <(split_segments "$COMMAND")

exit 0
