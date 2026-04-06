#!/bin/bash

set -euo pipefail

ROOT_DIR="."
RUN_ONBOARDING=1
SOURCE="${DEV_HARNESS_SOURCE:-https://github.com/code0xff/dev-harness.git}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-onboarding)
      RUN_ONBOARDING=0
      shift
      ;;
    --source)
      if [ "$#" -lt 2 ]; then
        echo "bootstrap-project 실패: --source 값이 필요합니다." >&2
        exit 2
      fi
      SOURCE="$2"
      shift 2
      ;;
    --source=*)
      SOURCE="${1#*=}"
      shift
      ;;
    *)
      ROOT_DIR="$1"
      shift
      ;;
  esac
done

mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"

install_harness() {
  local src="$1"
  local install_from=""
  local tmpdir=""

  if [ -d "$src" ] && [ -d "$src/.claude" ] && [ -d "$src/.devharness" ]; then
    install_from="$src"
  else
    if ! command -v git >/dev/null 2>&1; then
      echo "bootstrap-project 실패: git 명령이 필요합니다." >&2
      exit 2
    fi

    tmpdir="$(mktemp -d)"
    if ! git clone --depth 1 "$src" "$tmpdir/dev-harness" >/dev/null 2>&1; then
      echo "bootstrap-project 실패: dev-harness를 가져오지 못했습니다: $src" >&2
      rm -rf "$tmpdir"
      exit 2
    fi
    install_from="$tmpdir/dev-harness"
  fi

  if [ ! -d ".claude" ]; then
    cp -R "$install_from/.claude" .
  fi
  if [ ! -d ".devharness" ]; then
    cp -R "$install_from/.devharness" .
  fi
  if [ ! -f "CLAUDE.md" ] && [ -f "$install_from/CLAUDE.md" ]; then
    cp "$install_from/CLAUDE.md" .
  fi

  if [ -n "$tmpdir" ]; then
    rm -rf "$tmpdir"
  fi
}

if [ ! -d ".claude" ] || [ ! -d ".devharness" ]; then
  install_harness "$SOURCE"
fi

if [ ! -x ".claude/hooks/run-project-onboarding.sh" ]; then
  chmod +x .claude/hooks/*.sh
fi

missing=0
for bin in jq rg; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "bootstrap-project 경고: '$bin' 명령을 찾지 못했습니다." >&2
    missing=1
  fi
done

if [ "$RUN_ONBOARDING" -eq 1 ]; then
  .claude/hooks/run-project-onboarding.sh
fi

echo
echo "bootstrap-project 완료"
echo "- 다음 단계: Claude에서 /init-project 실행"
if [ "$RUN_ONBOARDING" -eq 1 ]; then
  echo "- /init-project가 완료되면 문서/정책 동기화까지 자동 처리됩니다"
  echo "- 수동으로 session.yaml을 직접 수정한 경우에만 .claude/hooks/run-project-onboarding.sh 를 다시 실행하세요"
fi

if [ "$missing" -eq 1 ]; then
  echo "- 참고: jq/rg 설치 후 다시 실행하면 품질 게이트/탐지 정확도가 좋아집니다"
fi

exit 0
