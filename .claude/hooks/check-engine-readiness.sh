#!/bin/bash

set -euo pipefail

PROFILE_FILE=".claude/project-profile.md"
AUTOMATION_FILE=".claude/project-automation.md"

if [ ! -f "$PROFILE_FILE" ] || [ ! -f "$AUTOMATION_FILE" ]; then
  exit 0
fi

get_profile_value() {
  local key="$1"
  grep -E "^- ${key}:" "$PROFILE_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//" || true
}

get_automation_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//" || true
}

execute_engine_commands="$(get_automation_value execute_engine_commands)"
runtime_mode="$(get_automation_value engine_runtime_mode)"
allow_stub="$(get_automation_value allow_engine_stub)"

if [ "$execute_engine_commands" != "true" ]; then
  exit 0
fi

PLUGIN_CHECK=".claude/hooks/check-codex-plugin.sh"

missing=0
for engine_key in plan_engine build_engine review_engine; do
  engine="$(get_profile_value "$engine_key")"
  case "$engine" in
    codex)
      # codex는 plugin → cli → claude fallback 순서로 확인
      if [ -x "$PLUGIN_CHECK" ]; then
        codex_mode="$("$PLUGIN_CHECK" check)"
        if [ "$codex_mode" = "none" ]; then
          # plugin도 cli도 없지만, claude가 있으면 fallback 가능
          if ! command -v claude >/dev/null 2>&1; then
            echo "engine-readiness: codex engine requires codex plugin, codex CLI, or claude CLI" >&2
            missing=1
          fi
        fi
      elif ! command -v codex >/dev/null 2>&1 && ! command -v claude >/dev/null 2>&1; then
        echo "engine-readiness: missing binary for ${engine_key}=${engine}" >&2
        missing=1
      fi
      ;;
    claude) bin="claude" ;;
    openai) bin="openai" ;;
    cursor) bin="cursor" ;;
    gemini) bin="gemini" ;;
    copilot) bin="gh" ;;
    *) bin="" ;;
  esac

  if [ "$engine" != "codex" ] && [ -n "${bin:-}" ] && ! command -v "$bin" >/dev/null 2>&1; then
    echo "engine-readiness: missing binary for ${engine_key}=${engine} (${bin})" >&2
    missing=1
  fi
done

if [ "$missing" -eq 1 ] && { [ "$runtime_mode" = "strict" ] || [ "$allow_stub" != "true" ]; }; then
  echo "engine-readiness 실패: strict runtime에서 필요한 엔진 바이너리가 없습니다." >&2
  exit 2
fi

exit 0
