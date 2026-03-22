#!/usr/bin/env bash
# transform.sh — Transform a plugin SKILL.md into a local variant.
# Usage: transform.sh <source> <dest> <dash-name> <short-name>

set -euo pipefail

SRC="$1"
DEST="$2"
DASH_NAME="$3"
SHORT_NAME="$4"

# --- Trigger phrase map ---
get_triggers() {
  case "$1" in
    init)
      echo '"pmm-init", "/pmm-init", "initialize memory", "set up memory", "start pmm", "init pmm", "scaffold memory", "set up poor man'\''s memory", or any request to initialize the PMM memory system in a project.'
      ;;
    save)
      echo '"pmm-save", "/pmm-save", "save memory", "commit memory", "persist session", "save session", "wrap up memory", "update memory files", or any request to save the current session state to memory.'
      ;;
    query)
      echo '"pmm-query", "/pmm-query", "query memory", "search memory", "recall", "what did we decide about", "find in memory", "look up", "what do we know about", or any request to search or recall information from memory files.'
      ;;
    hydrate)
      echo '"pmm-hydrate", "/pmm-hydrate", "hydrate memory", "populate memory", "fill in memory files", "hydrate files", "backfill memory", or any request to populate empty or thin memory files from existing context.'
      ;;
    settings)
      echo '"pmm-settings", "/pmm-settings", "change memory settings", "configure pmm", "memory configuration", "update pmm settings", "pmm preferences", or any request to view or change PMM configuration.'
      ;;
    viz)
      echo '"pmm-viz", "/pmm-viz", "visualize memory", "memory graph", "show the graph", "interactive graph", "d3 visualization", "open memory viz", or any request to generate an interactive memory visualization.'
      ;;
    status)
      echo '"pmm-status", "/pmm-status", "memory status", "pmm health", "is memory working", "is memory saving", "memory dashboard", or any request to check the health or status of the PMM system.'
      ;;
    dump)
      echo '"pmm-dump", "/pmm-dump", "dump memory", "ascii memory", "text memory overview", "show memory heatmap", "memory dump", or any request for a text-based ASCII visualization of memory state.'
      ;;
    update)
      echo '"pmm-update", "/pmm-update", "update pmm", "check for pmm updates", "upgrade memory system", "pmm version", or any request to check for and apply upstream PMM updates.'
      ;;
    *)
      echo "\"$DASH_NAME\", \"/$DASH_NAME\""
      ;;
  esac
}

TRIGGERS=$(get_triggers "$SHORT_NAME")

# --- Use awk for the entire transform ---
# Parse: extract description, strip argument-hint, extract body.
# Then reassemble with new frontmatter + transformed body.

awk -v dash_name="$DASH_NAME" -v triggers="$TRIGGERS" '
BEGIN {
  in_front = 0
  front_count = 0
  in_desc = 0
  in_arg_hint = 0
  desc = ""
  body = ""
  past_front = 0
}

# Track frontmatter delimiters
/^---$/ {
  front_count++
  if (front_count == 1) { in_front = 1; next }
  if (front_count == 2) { in_front = 0; past_front = 1; next }
}

# Inside frontmatter
in_front && !past_front {
  # Start of description field
  if ($0 ~ /^description: *>/) {
    in_desc = 1
    in_arg_hint = 0
    next
  }
  # Start of description field (quoted or plain)
  if ($0 ~ /^description:/) {
    in_desc = 0
    in_arg_hint = 0
    # Extract inline description value
    line = $0
    sub(/^description: *"?/, "", line)
    sub(/"$/, "", line)
    desc = line
    next
  }
  # Start of argument-hint field (skip it)
  if ($0 ~ /^argument-hint:/) {
    in_desc = 0
    in_arg_hint = 1
    next
  }
  # Start of name field (skip — we rebuild it)
  if ($0 ~ /^name:/) {
    in_desc = 0
    in_arg_hint = 0
    next
  }
  # Any other top-level YAML key
  if ($0 ~ /^[a-z]/ && !in_desc && !in_arg_hint) {
    next
  }
  # Continuation lines of description
  if (in_desc) {
    line = $0
    sub(/^  /, "", line)  # strip 2-space indent
    if (desc != "") desc = desc " "
    desc = desc line
    next
  }
  # Continuation lines of argument-hint (discard)
  if (in_arg_hint) {
    next
  }
  next
}

# Body (after frontmatter)
past_front {
  if (body != "") body = body "\n"
  body = body $0
}

END {
  # Transform description: pmm: → pmm-
  gsub(/pmm:/, "pmm-", desc)

  # Append trigger phrases
  desc = desc " Trigger on: " triggers

  # Wrap description at ~93 chars with 2-space indent
  # Simple word-wrap
  words_left = desc
  line = ""
  wrapped = ""
  n = split(desc, words, " ")
  line_len = 0
  for (i = 1; i <= n; i++) {
    wlen = length(words[i])
    if (line_len + wlen + 1 > 93 && line_len > 0) {
      if (wrapped != "") wrapped = wrapped "\n"
      wrapped = wrapped "  " line
      line = words[i]
      line_len = wlen
    } else {
      if (line != "") { line = line " "; line_len++ }
      line = line words[i]
      line_len = line_len + wlen
    }
  }
  if (line != "") {
    if (wrapped != "") wrapped = wrapped "\n"
    wrapped = wrapped "  " line
  }

  # Transform body: pmm: → pmm-
  gsub(/pmm:/, "pmm-", body)

  # Transform slash invocations: /pmm- references stay as-is (already correct after gsub)

  # Output
  print "---"
  print "name: " dash_name
  print "description: >"
  print wrapped
  print "---"
  print body
}
' "$SRC" > "$DEST"

echo "  transformed: $DASH_NAME"
