#!/usr/bin/env bash
# session-start.sh — PMM SessionStart hook
# Cats Tier 1 memory files + session-instructions into stdout at session start.
# Claude Code makes this stdout visible to Claude as initial context.
# Runs with cwd = project root (where .claude/ lives).
#
# Load strategies (config.md Active Files section):
#   full      — cat the whole file (default, backwards compatible)
#   tail:N    — output only the last N entries (entry = line starting with **[ or **Session)
#   header    — output everything before the second ## heading
#   skip      — omit this file entirely

set -euo pipefail

MEMORY_DIR="./memory"

# No memory dir = PMM not initialised. Exit silently.
if [[ ! -d "$MEMORY_DIR" ]]; then
  exit 0
fi

CONFIG="$MEMORY_DIR/config.md"

# Parse active file list from config.md ## Active Files section.
# Returns 0 if a given filename is marked active (or if config missing = treat all active).
is_active() {
  local filename="$1"
  if [[ ! -f "$CONFIG" ]]; then
    return 0  # no config = all active
  fi
  # Look for "- <filename>: active" (with optional " | strategy" suffix).
  grep -q "^- ${filename}: active" "$CONFIG"
}

# Get load strategy for a filename from config.md.
# Returns "full" if no strategy specified or config missing.
get_strategy() {
  local filename="$1"
  if [[ ! -f "$CONFIG" ]]; then
    echo "full"
    return
  fi
  # Match "- filename: active | strategy" — extract the strategy part.
  local line
  line=$(grep "^- ${filename}: active" "$CONFIG" || true)
  if [[ "$line" == *"|"* ]]; then
    # Trim whitespace around the strategy token.
    echo "${line##*|}" | tr -d ' '
  else
    echo "full"
  fi
}

# Output last N entries from a file.
# Entry delimiters: lines starting with **[ or **Session
emit_tail() {
  local path="$1"
  local n="$2"

  # Collect line numbers of entry headers.
  local -a entry_lines=()
  local lineno=0
  while IFS= read -r line; do
    lineno=$(( lineno + 1 ))
    if [[ "$line" =~ ^\*\*\[ || "$line" =~ ^\*\*Session ]]; then
      entry_lines+=("$lineno")
    fi
  done < "$path"

  local total="${#entry_lines[@]}"

  # tail:0 = output nothing.
  if [[ "$n" -eq 0 ]]; then
    return 0
  fi

  if [[ "$total" -eq 0 ]]; then
    # No entry headers found — fall back to full output.
    cat "$path"
    return
  fi

  if [[ "$n" -ge "$total" ]]; then
    # Fewer entries than requested — output everything.
    cat "$path"
    return
  fi

  # Start from the (total - n)th entry header (0-indexed).
  local start_idx=$(( total - n ))
  local start_line="${entry_lines[$start_idx]}"

  # Output from that line to EOF.
  tail -n "+${start_line}" "$path"
}

# Output everything before the second ## heading.
emit_header() {
  local path="$1"
  local count=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^##\  ]]; then
      count=$(( count + 1 ))
      if [[ "$count" -eq 2 ]]; then
        break
      fi
    fi
    echo "$line"
  done < "$path"
}

# Emit a file according to its configured load strategy.
emit() {
  local path="$1"
  local label="$2"
  local filename
  filename="$(basename "$path")"

  if ! is_active "$filename"; then
    return 0
  fi

  local strategy
  strategy=$(get_strategy "$filename")

  # skip = no output at all.
  if [[ "$strategy" == "skip" ]]; then
    return 0
  fi

  # Empty file = skip regardless of strategy.
  if [[ ! -s "$path" ]]; then
    return 0
  fi

  # tail:0 = explicit no-op (suppress header too).
  if [[ "$strategy" == "tail:0" ]]; then
    return 0
  fi

  local content
  if [[ "$strategy" == "full" ]]; then
    content=$(cat "$path")
  elif [[ "$strategy" == "header" ]]; then
    content=$(emit_header "$path")
  elif [[ "$strategy" == tail:* ]]; then
    local n="${strategy#tail:}"
    content=$(emit_tail "$path" "$n")
  else
    # Unknown strategy — fall back to full.
    content=$(cat "$path")
  fi

  # Only emit the header + content if there is content to show.
  if [[ -n "$content" ]]; then
    echo "--- PMM: $label ---"
    printf '%s\n' "$content"
    echo ""
  fi
}

# Tier 1 files in load order.
# config.md is always emitted in full — it's the config itself, never in its own Active Files list.
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
# Strategy: always full (coordinator file, not user-configurable via Active Files).
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
