#!/bin/bash

# check-codex-plugin.sh — codex 플러그인 가용성 검증
#
# codex 엔진 사용 시 다음 순서로 가용성을 확인한다:
# 1. codex-plugin-cc (Claude Code 플러그인) — 같은 세션에서 컨텍스트 공유
# 2. codex CLI 바이너리 — 별도 프로세스 fallback
#
# 반환값:
#   plugin  — codex-plugin-cc 사용 가능
#   cli     — codex CLI만 사용 가능
#   none    — codex 사용 불가

set -euo pipefail

MODE="${1:-check}"

check_plugin() {
  # Claude Code 플러그인은 MCP 서버 또는 settings에서 확인
  local settings_file=".claude/settings.json"
  local local_settings=".claude/settings.local.json"
  local user_settings="$HOME/.claude/settings.json"

  # settings에서 codex MCP 서버 설정 확인
  for sf in "$settings_file" "$local_settings" "$user_settings"; do
    if [ -f "$sf" ] && command -v jq >/dev/null 2>&1; then
      if jq -e '.mcpServers.codex // empty' "$sf" >/dev/null 2>&1; then
        return 0
      fi
      # 플러그인이 permissions에 등록되어 있는지도 확인
      if jq -e '.permissions.allow[]? | select(contains("codex"))' "$sf" >/dev/null 2>&1; then
        return 0
      fi
    fi
  done

  # npm global로 설치된 codex-plugin-cc 확인
  if command -v npx >/dev/null 2>&1; then
    if npx --yes codex-plugin-cc --version >/dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

check_cli() {
  command -v codex >/dev/null 2>&1
}

case "$MODE" in
  check)
    if check_plugin; then
      echo "plugin"
    elif check_cli; then
      echo "cli"
    else
      echo "none"
    fi
    ;;
  require)
    if check_plugin; then
      echo "plugin"
      exit 0
    elif check_cli; then
      echo "cli"
      exit 0
    else
      echo "codex-plugin 실패: codex 플러그인과 CLI 모두 사용 불가합니다." >&2
      echo "설치 방법:" >&2
      echo "  플러그인: npm install -g codex-plugin-cc" >&2
      echo "  CLI: npm install -g @openai/codex" >&2
      exit 2
    fi
    ;;
  *)
    echo "usage: $0 {check|require}" >&2
    exit 2
    ;;
esac
