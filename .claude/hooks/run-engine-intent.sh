#!/bin/bash

set -euo pipefail

PROFILE_FILE=".claude/project-profile.md"
AUTOMATION_FILE=".claude/project-automation.md"
STATE_DIR=".claude/state/intents"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "engine-intent 실패: $PROFILE_FILE 파일이 없습니다." >&2
  exit 2
fi
if [ ! -f "$AUTOMATION_FILE" ]; then
  echo "engine-intent 실패: $AUTOMATION_FILE 파일이 없습니다." >&2
  exit 2
fi

get_profile_value() {
  local key="$1"
  grep -E "^- ${key}:" "$PROFILE_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

get_automation_value() {
  local key="$1"
  grep -E "^- ${key}:" "$AUTOMATION_FILE" | head -n 1 | sed -E "s/^- ${key}:[[:space:]]*//"
}

INTENT="${1:-}"
GOAL="${2:-autopilot-goal}"
if [ "$INTENT" != "plan" ] && [ "$INTENT" != "build" ] && [ "$INTENT" != "review" ]; then
  echo "usage: $0 {plan|build|review} [goal]" >&2
  exit 2
fi

engine_key="${INTENT}_engine"
model_key="${INTENT}_model"
engine="$(get_profile_value "$engine_key")"
model="$(get_profile_value "$model_key")"
[ -z "$model" ] && model="unset"

runtime_mode="$(get_automation_value "engine_runtime_mode")"
allow_stub="$(get_automation_value "allow_engine_stub")"
execute_engine_commands="$(get_automation_value "execute_engine_commands")"

mkdir -p "$STATE_DIR"
artifact="${STATE_DIR}/${INTENT}-$(date +%s)-$RANDOM.md"

prompt="[intent=${INTENT}] goal=${GOAL}"
cmd=""

case "$engine" in
  codex)
    cmd="codex exec \"$prompt\""
    ;;
  claude)
    cmd="claude -p \"$prompt\""
    ;;
  openai)
    cmd="openai api responses.create -d '{\"model\":\"${model}\",\"input\":\"${prompt}\"}'"
    ;;
  cursor|gemini|copilot)
    cmd="echo \"${engine} adapter placeholder: ${prompt}\""
    ;;
  *)
    cmd="echo \"unknown engine=${engine} intent=${INTENT}\""
    ;;
esac

{
  echo "# Engine Intent Artifact"
  echo
  echo "- intent: $INTENT"
  echo "- engine: $engine"
  echo "- model: $model"
  echo "- runtime_mode: $runtime_mode"
  echo "- command: $cmd"
  echo "- goal: $GOAL"
} > "$artifact"

binary="$(echo "$cmd" | awk '{print $1}')"
if [ "$execute_engine_commands" != "true" ]; then
  {
    echo
    echo "[stub]"
    echo "execute_engine_commands=false. configured command is not executed."
  } >> "$artifact"
  exit 0
fi

if command -v "$binary" >/dev/null 2>&1; then
  if eval "$cmd" >> "$artifact" 2>&1; then
    exit 0
  fi
  if [ "$runtime_mode" = "strict" ] || [ "$allow_stub" != "true" ]; then
    echo "engine-intent 실패: intent 실행 실패 ($INTENT/$engine)" >&2
    exit 2
  fi
  {
    echo
    echo "[stub]"
    echo "binary=${binary} execution failed. stub-fallback mode로 통과."
  } >> "$artifact"
  exit 0
fi

if [ "$runtime_mode" = "strict" ] || [ "$allow_stub" != "true" ]; then
  echo "engine-intent 실패: ${binary}를 찾을 수 없습니다. strict runtime에서는 stub이 금지됩니다." >&2
  exit 2
fi

{
  echo
  echo "[stub]"
  echo "binary=${binary} not found. stub-fallback mode로 통과."
} >> "$artifact"

exit 0
