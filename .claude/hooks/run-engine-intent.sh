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

shell_quote() {
  printf "%q" "$1"
}

validate_intent_artifact() {
  local intent="$1"
  local artifact="$2"
  local required=()

  case "$intent" in
    plan)
      required=("## Goal And Constraints" "## Approach" "## Implementation Plan" "## Uncertainties")
      ;;
    build)
      required=("## Build Changes" "## Validation Results" "## Updated Files")
      ;;
    review)
      required=("## Findings" "## Applied Fixes" "## User Follow Ups")
      ;;
  esac

  if [ "${#required[@]}" -eq 0 ]; then
    return 0
  fi

  local heading
  for heading in "${required[@]}"; do
    if ! grep -Fqx "$heading" "$artifact"; then
      echo "engine-intent 실패: intent output contract 불충족 ($intent missing: $heading)" >&2
      return 1
    fi
  done

  return 0
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
adapter_cmd="unset"

case "$engine" in
  codex) adapter_cmd="$(get_automation_value engine_cmd_codex)" ;;
  claude) adapter_cmd="$(get_automation_value engine_cmd_claude)" ;;
  openai) adapter_cmd="$(get_automation_value engine_cmd_openai)" ;;
  cursor) adapter_cmd="$(get_automation_value engine_cmd_cursor)" ;;
  gemini) adapter_cmd="$(get_automation_value engine_cmd_gemini)" ;;
  copilot) adapter_cmd="$(get_automation_value engine_cmd_copilot)" ;;
esac

mkdir -p "$STATE_DIR"
artifact="${STATE_DIR}/${INTENT}-$(date +%s)-$RANDOM.md"

prompt="[intent=${INTENT}] goal=${GOAL}"
cmd=""

if [ -n "$adapter_cmd" ] && [ "$adapter_cmd" != "unset" ]; then
  quoted_intent="$(shell_quote "$INTENT")"
  quoted_goal="$(shell_quote "$GOAL")"
  quoted_model="$(shell_quote "$model")"
  quoted_prompt="$(shell_quote "$prompt")"
  cmd="$(echo "$adapter_cmd" | sed \
    -e "s/{intent}/${quoted_intent}/g" \
    -e "s/{goal}/${quoted_goal}/g" \
    -e "s/{model}/${quoted_model}/g" \
    -e "s/{prompt}/${quoted_prompt}/g")"
else
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
fi

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
    validate_intent_artifact "$INTENT" "$artifact"
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
