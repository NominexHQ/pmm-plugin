#!/usr/bin/env bash
# should-save.sh — Stop command hook
# Tracks response count, signals pmm:save when cadence threshold is hit.
# Zero LLM cost between saves. Pure bash.

set -euo pipefail

# --- Read stdin (Claude Code sends JSON to Stop hooks) ---
STDIN_JSON=""
if [ -t 0 ]; then
  # no stdin (e.g. direct invocation in testing)
  STDIN_JSON="{}"
else
  STDIN_JSON=$(cat)
fi

# Parse stop_hook_active — use jq if available, fallback to grep
STOP_HOOK_ACTIVE="false"
if command -v jq &>/dev/null; then
  STOP_HOOK_ACTIVE=$(echo "$STDIN_JSON" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
else
  if echo "$STDIN_JSON" | grep -q '"stop_hook_active": *true'; then
    STOP_HOOK_ACTIVE="true"
  fi
fi

# Guard: if Claude is already in a forced continuation, don't block again
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# --- Read cadence config from ./memory/config.md ---
CONFIG_FILE="./memory/config.md"

if [ ! -f "$CONFIG_FILE" ]; then
  # No config — silent no-op
  exit 0
fi

# Extract the save cadence mode line
# Expected format: "- Mode: every-milestone" or "- Mode: every-5"
CADENCE_LINE=$(grep -A1 "## Save Cadence" "$CONFIG_FILE" | grep "Mode:" | head -1 || echo "")

if [ -z "$CADENCE_LINE" ]; then
  exit 0
fi

CADENCE_MODE=$(echo "$CADENCE_LINE" | sed 's/.*Mode: *//' | tr -d '[:space:]')

# If every-milestone (default): no counter, save is soft-instruction only
if [ "$CADENCE_MODE" = "every-milestone" ]; then
  exit 0
fi

# Check if mode is every-N
if ! echo "$CADENCE_MODE" | grep -qE '^every-[0-9]+$'; then
  # Unknown mode — silent no-op
  exit 0
fi

# Extract N
N=$(echo "$CADENCE_MODE" | sed 's/every-//')

# --- Counter logic ---
COUNTER_FILE="./.pmm-save-counter"

# Read current count (default 0 if missing or unreadable)
COUNT=0
if [ -f "$COUNTER_FILE" ]; then
  RAW=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
  if echo "$RAW" | grep -qE '^[0-9]+$'; then
    COUNT=$RAW
  fi
fi

# Increment
COUNT=$((COUNT + 1))

# Check threshold
if [ "$COUNT" -ge "$N" ]; then
  # Reset counter
  echo "0" > "$COUNTER_FILE"
  # Signal Claude Code to force a continuation turn
  printf '{"decision":"block","reason":"PMM save threshold reached — run pmm:save"}\n'
else
  # Not yet — write incremented count and exit silently
  echo "$COUNT" > "$COUNTER_FILE"
  exit 0
fi
