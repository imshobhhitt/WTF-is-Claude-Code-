#!/usr/bin/env bash
# Claude Code PostToolUse hook (Windows / Git Bash)
# Logs the tool name + timestamp after each tool runs, so we can see the hook fire.
# Claude Code pipes a JSON payload on stdin; we pull "tool_name" from it with grep
# (no jq in this environment).

input=$(cat)
tool=$(printf '%s' "$input" | grep -oP '"tool_name"\s*:\s*"\K[^"]+')
echo "$(date '+%Y-%m-%d %H:%M:%S') PostToolUse: ${tool:-unknown}" >> "$(dirname "$0")/posttool.log"
