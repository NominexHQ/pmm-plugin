#!/usr/bin/env bash
# session-start.sh — PMM SessionStart hook
# Cats Tier 1 memory files + session-instructions into stdout at session start.
# Claude Code makes this stdout visible to Claude as initial context.
# Runs with cwd = project root (where .claude/ lives).

set -euo pipefail

MEMORY_DIR="./memory"

# No memory dir = PMM not initialised. Exit silently.
if [[ ! -d "$MEMORY_DIR" ]]; then
  exit 0
fi

CONFIG="$MEMORY_DIR/config.md"

# Parse active file list from config.md ## Active Files section.
# Returns 1 if a given filename is marked active (or if config missing = treat all active).
is_active() {
  local filename="$1"
  if [[ ! -f "$CONFIG" ]]; then
    return 0  # no config = all active
  fi
  # Look for "- <filename>: active" in the Active Files section.
  # grep returns 0 on match, 1 on no match.
  grep -q "^- ${filename}: active" "$CONFIG"
}

# Emit a file if: it exists, has content, and is active per config.
emit() {
  local path="$1"
  local label="$2"
  local filename
  filename="$(basename "$path")"

  if ! is_active "$filename"; then
    return 0
  fi

  if [[ -s "$path" ]]; then
    echo "--- PMM: $label ---"
    cat "$path"
    echo ""
  fi
}

# Tier 1 files in load order.
# config.md is always emitted — it's the config itself, never in its own Active Files list.
if [[ -s "$MEMORY_DIR/config.md" ]]; then
  echo "--- PMM: memory/config.md ---"
  cat "$MEMORY_DIR/config.md"
  echo ""
fi
emit "$MEMORY_DIR/standinginstructions.md" "memory/standinginstructions.md"
emit "$MEMORY_DIR/last.md"               "memory/last.md"
emit "$MEMORY_DIR/progress.md"           "memory/progress.md"
emit "$MEMORY_DIR/decisions.md"          "memory/decisions.md"
emit "$MEMORY_DIR/lessons.md"            "memory/lessons.md"
emit "$MEMORY_DIR/preferences.md"        "memory/preferences.md"
emit "$MEMORY_DIR/memory.md"             "memory/memory.md"
emit "$MEMORY_DIR/summaries.md"          "memory/summaries.md"
emit "$MEMORY_DIR/voices.md"             "memory/voices.md"
emit "$MEMORY_DIR/processes.md"          "memory/processes.md"
emit "$MEMORY_DIR/timeline.md"           "memory/timeline.md"

# agents.md is optional — only present in coordinator repos.
# Bypass is_active check: if it exists and has content, always emit it.
if [[ -s "$MEMORY_DIR/agents.md" ]]; then
  echo "--- PMM: memory/agents.md ---"
  cat "$MEMORY_DIR/agents.md"
  echo ""
fi

# Session instructions — always last, always emitted if file exists and has content.
INSTRUCTIONS="${CLAUDE_PLUGIN_ROOT}/context/session-instructions.md"
if [[ -s "$INSTRUCTIONS" ]]; then
  echo "--- PMM: session-instructions ---"
  cat "$INSTRUCTIONS"
  echo ""
fi
