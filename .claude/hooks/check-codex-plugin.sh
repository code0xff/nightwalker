#!/bin/bash

# check-codex-plugin.sh — codex 플러그인 가용성 확인
#
# 사용: check-codex-plugin.sh check
# 출력: plugin | cli | none
#
# 판정 순서:
#   1. .mcp.json에 codex MCP 서버가 설정되어 있고 실행 커맨드가 가용하면 → plugin
#   2. codex CLI가 설치되어 있으면 → cli
#   3. 그 외 → none

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MCP_JSON="${REPO_ROOT}/.mcp.json"

check_plugin() {
  # .mcp.json에 codex MCP 서버가 설정되어 있는지 확인
  if [ -f "$MCP_JSON" ] && command -v jq >/dev/null 2>&1; then
    local server_cmd
    server_cmd="$(jq -r '.mcpServers.codex.command // empty' "$MCP_JSON" 2>/dev/null || true)"
    if [ -n "$server_cmd" ]; then
      # 커맨드가 실행 가능한지 확인 (npx, node 등)
      if command -v "$server_cmd" >/dev/null 2>&1; then
        echo "plugin"
        return
      fi
    fi
  fi

  # codex CLI fallback
  if command -v codex >/dev/null 2>&1; then
    echo "cli"
    return
  fi

  echo "none"
}

CMD="${1:-check}"

case "$CMD" in
  check)
    check_plugin
    ;;
  *)
    echo "usage: $0 check" >&2
    exit 2
    ;;
esac
