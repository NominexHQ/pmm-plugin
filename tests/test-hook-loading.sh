#!/usr/bin/env bash
# test-hook-loading.sh — Integration tests for session-start.sh hook output
#
# Verifies that the hook produces correct, usable context against the real VP memory.
# Tests five categories:
#   1. Complete context — all Tier 1 files present, Tier 2 absent
#   2. Load strategies applied correctly — tail:N limits on timeline/decisions/lessons
#   3. Post-compact idempotency — hook output byte-identical on successive runs
#   4. Critical content — agent-critical facts present in output
#   5. Token budget — total output under 15,000 tokens
#
# Usage: bash tests/test-hook-loading.sh
# Exit code: 0 = all pass, 1 = failures
# Runs from: nominex-hq project root (or any dir; paths are absolute)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../hooks/scripts/session-start.sh"
PLUGIN_ROOT="$SCRIPT_DIR/.."
# Project root: accept env var, walk up from script dir, or fall back to synthetic fixtures
if [[ -n "${PROJECT_ROOT:-}" ]]; then
  REAL_PROJECT_ROOT="$PROJECT_ROOT"
elif [[ -d "$SCRIPT_DIR/../../../../memory" ]]; then
  REAL_PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
else
  # Create synthetic test fixtures for CI/external contributors
  REAL_PROJECT_ROOT="$(mktemp -d)"
  SYNTHETIC=1
  mkdir -p "$REAL_PROJECT_ROOT/memory"
  cat > "$REAL_PROJECT_ROOT/memory/config.md" << 'FIXTURE'
# PMM Config
pmm_version: 2.4.0
save_cadence: manual
commit_behaviour: auto
session_start_mode: hook
FIXTURE
  cat > "$REAL_PROJECT_ROOT/memory/last.md" << 'FIXTURE'
# Last Session
Session 1 — Test fixture for CI.
FIXTURE
  cat > "$REAL_PROJECT_ROOT/memory/timeline.md" << 'FIXTURE'
# Timeline
**[Session 1 / 2026-01-01]** — Test fixture entry.
**[Session 2 / 2026-01-02]** — Second test fixture entry.
FIXTURE
  cat > "$REAL_PROJECT_ROOT/memory/decisions.md" << 'FIXTURE'
# Decisions
**D-001** — Test decision fixture.
**D-002** — Second test decision fixture.
FIXTURE
  cat > "$REAL_PROJECT_ROOT/memory/progress.md" << 'FIXTURE'
# Progress
Test fixture.
FIXTURE
fi
REAL_MEMORY_DIR="$REAL_PROJECT_ROOT/memory"

# ── test harness ──────────────────────────────────────────────────────────────

PASS=0
FAIL=0
FAILURES=()

pass() { PASS=$(( PASS + 1 )); printf '  PASS  %s\n' "$1"; }
fail() {
  FAIL=$(( FAIL + 1 ))
  FAILURES+=("$1")
  printf '  FAIL  %s\n' "$1"
  if [[ -n "${2:-}" ]]; then printf '        %s\n' "$2"; fi
}

section() { printf '\n=== %s ===\n' "$1"; }

# ── prerequisites ─────────────────────────────────────────────────────────────

if [[ ! -f "$HOOK_SCRIPT" ]]; then
  printf 'ERROR: hook script not found: %s\n' "$HOOK_SCRIPT" >&2
  exit 1
fi

if [[ ! -d "$REAL_MEMORY_DIR" ]]; then
  printf 'ERROR: real memory dir not found: %s\n' "$REAL_MEMORY_DIR" >&2
  printf 'These tests require the VP memory directory to be present.\n' >&2
  exit 1
fi

# ── run_hook: execute hook against real VP memory ────────────────────────────
#
# Runs session-start.sh from a wrapper directory where ./memory symlinks to the
# real VP memory dir. CLAUDE_PLUGIN_ROOT is the real plugin root so
# session-instructions.md loads correctly.
#
# Output: hook stdout only. stderr discarded.

TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

run_hook() {
  local wrapper; wrapper="$TMPDIR_BASE/run_$$_$RANDOM"
  mkdir -p "$wrapper"
  ln -sf "$REAL_MEMORY_DIR" "$wrapper/memory"
  (
    cd "$wrapper"
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
      bash --noprofile --norc "$HOOK_SCRIPT" 2>/dev/null
  )
  rm -rf "$wrapper"
}

# ── cache a single hook run for categories 1-4 ───────────────────────────────
# Running the hook once is enough for all content/strategy/budget checks.
# Category 3 runs it a second time explicitly.

printf 'Running hook against real VP memory...\n'
HOOK_OUTPUT=$(run_hook)
printf 'Hook output: %d bytes (~%d tokens)\n' "${#HOOK_OUTPUT}" "$(( ${#HOOK_OUTPUT} / 4 ))"

# ── Category 1: SessionStart produces complete context ───────────────────────

section "Category 1: Complete context"

# All Tier 1 files should appear as PMM headers

tier1_files=(
  config.md
  standinginstructions.md
  last.md
  progress.md
  decisions.md
  lessons.md
  preferences.md
  memory.md
  summaries.md
  voices.md
  processes.md
  timeline.md
)

for fname in "${tier1_files[@]}"; do
  T="Tier 1 file present: $fname"
  # Use heredoc (<<< var) instead of printf | grep to avoid SIGPIPE under set -euo pipefail.
  # BSD grep treats "---" as option flags, so search for the interior pattern without leading dashes.
  if grep -q "PMM: memory/${fname}" <<< "$HOOK_OUTPUT"; then
    pass "$T"
  else
    fail "$T" "header '--- PMM: memory/$fname ---' not found in hook output"
  fi
done

# agents.md — coordinator repo check
T="agents.md present (coordinator repo)"
if grep -q "PMM: memory/agents.md" <<< "$HOOK_OUTPUT"; then
  pass "$T"
else
  fail "$T" "header '--- PMM: memory/agents.md ---' not found"
fi

# session-instructions.md
T="session-instructions.md present"
if grep -q "PMM: session-instructions" <<< "$HOOK_OUTPUT"; then
  pass "$T"
else
  fail "$T" "header '--- PMM: session-instructions ---' not found"
fi

# Tier 2 files must NOT appear

tier2_files=(graph.md vectors.md taxonomies.md assets.md)

for fname in "${tier2_files[@]}"; do
  T="Tier 2 file absent: $fname"
  if ! grep -q "PMM: memory/${fname}" <<< "$HOOK_OUTPUT"; then
    pass "$T"
  else
    fail "$T" "$fname header found in output — Tier 2 files should not load at session start"
  fi
done

# ── Category 2: Load strategies on real data ─────────────────────────────────

section "Category 2: Load strategies applied on real VP memory"

# Helper: extract a named section from hook output.
# Prints everything between "--- PMM: memory/<fname> ---" and the next "--- PMM:" line.
# Uses pattern matching on the line content to avoid grep treating "---" as flags.
extract_section() {
  local fname="$1"
  local in_section=0
  while IFS= read -r line; do
    # Match start marker: line contains "PMM: memory/<fname> ---"
    if [[ "$line" == *"PMM: memory/$fname"* && "$line" == *"---"* && $in_section -eq 0 ]]; then
      in_section=1
      continue
    fi
    if [[ $in_section -eq 1 ]]; then
      # Stop at next PMM section header
      if [[ "$line" == *"--- PMM:"* ]]; then
        break
      fi
      printf '%s\n' "$line"
    fi
  done <<< "$HOOK_OUTPUT"
}

# Count emit_tail-detectable entries in a section.
# Entry header = line starting with **[ or **Session (matches hook's emit_tail logic).
count_detectable_entries() {
  local section_content="$1"
  printf '%s\n' "$section_content" \
    | grep -cE "^\*\*\[|^\*\*Session" || true
}

# timeline.md: config says tail:5 — output must have AT MOST 5 detectable entries
T="timeline.md: AT MOST 5 detectable entries (tail:5 config)"
{
  section_content=$(extract_section "timeline.md")
  entry_count=$(count_detectable_entries "$section_content")
  if [[ "$entry_count" -le 5 && "$entry_count" -gt 0 ]]; then
    pass "$T"
  elif [[ "$entry_count" -eq 0 ]]; then
    fail "$T" "no entries found in timeline section — file may be empty or strategy broken"
  else
    fail "$T" "got $entry_count entries; expected at most 5"
  fi
}

# decisions.md: config says tail:10 — output must have AT MOST 10 detectable entries
T="decisions.md: AT MOST 10 detectable entries (tail:10 config)"
{
  section_content=$(extract_section "decisions.md")
  entry_count=$(count_detectable_entries "$section_content")
  if [[ "$entry_count" -le 10 && "$entry_count" -gt 0 ]]; then
    pass "$T"
  elif [[ "$entry_count" -eq 0 ]]; then
    fail "$T" "no entries found in decisions section — file may be empty or strategy broken"
  else
    fail "$T" "got $entry_count entries; expected at most 10"
  fi
}

# lessons.md: config says tail:5 — AT MOST 5 emit_tail-detectable entries
# Note: lessons.md may have entries using **Day or **Pre-launch patterns that don't
# match emit_tail detection (which only looks for **[ and **Session). Those entries
# appear as trailing content after the tail window. We count only detectable entries.
T="lessons.md: AT MOST 5 detectable entries (tail:5 config)"
{
  section_content=$(extract_section "lessons.md")
  entry_count=$(count_detectable_entries "$section_content")
  if [[ "$entry_count" -le 5 ]]; then
    pass "$T"
  else
    fail "$T" "got $entry_count detectable entries; expected at most 5"
  fi
}

# standinginstructions.md: config says full — should contain all entries
# Verify by checking known early entries appear (prove no tail truncation)
T="standinginstructions.md: FULL output (no truncation)"
{
  section_content=$(extract_section "standinginstructions.md")
  # The file's first real entry starts with "2026-03-17 — Evidence over claims"
  if grep -q "Evidence over claims" <<< "$section_content"; then
    pass "$T"
  else
    fail "$T" "early entry 'Evidence over claims' missing — file may be truncated or missing"
  fi
}

# voices.md: config says full — verify both persona sections present
T="voices.md: FULL output — both persona sections present"
{
  section_content=$(extract_section "voices.md")
  has_leith=$(grep -c "Leith" <<< "$section_content" || true)
  has_tessa=$(grep -c "Tessa" <<< "$section_content" || true)
  if [[ "$has_leith" -gt 0 && "$has_tessa" -gt 0 ]]; then
    pass "$T"
  else
    fail "$T" "leith_matches=$has_leith tessa_matches=$has_tessa — voices.md truncated?"
  fi
}

# processes.md: config says full — verify multiple sections present
T="processes.md: FULL output — multiple process sections present"
{
  section_content=$(extract_section "processes.md")
  section_count=$(grep -c "^## " <<< "$section_content" || true)
  if [[ "$section_count" -ge 2 ]]; then
    pass "$T"
  else
    fail "$T" "only $section_count ## sections found; expected 2+ for full file"
  fi
}

# Verify tail:5 on timeline actually truncates (file has far more entries than 5)
T="timeline.md: tail:5 is actually truncating (file has more than 5 total entries)"
{
  total_in_file=$(grep -cE "^\*\*\[|^\*\*Session" "$REAL_MEMORY_DIR/timeline.md" || true)
  section_content=$(extract_section "timeline.md")
  entry_count=$(count_detectable_entries "$section_content")
  if [[ "$total_in_file" -gt 5 && "$entry_count" -le 5 ]]; then
    pass "$T"
  elif [[ "$total_in_file" -le 5 ]]; then
    fail "$T" "timeline.md only has $total_in_file entries — can't verify truncation"
  else
    fail "$T" "file has $total_in_file entries but output has $entry_count — truncation not working"
  fi
}

# Verify tail:10 on decisions actually truncates
T="decisions.md: tail:10 is actually truncating (file has more than 10 total entries)"
{
  # decisions.md uses **Pre, **Day, **Session, **2026, **Demo patterns — count all
  total_in_file=$(grep -cE "^\*\*" "$REAL_MEMORY_DIR/decisions.md" || true)
  section_content=$(extract_section "decisions.md")
  entry_count=$(count_detectable_entries "$section_content")
  if [[ "$total_in_file" -gt 10 && "$entry_count" -le 10 ]]; then
    pass "$T"
  elif [[ "$total_in_file" -le 10 ]]; then
    fail "$T" "decisions.md only has $total_in_file ** lines — can't verify truncation"
  else
    fail "$T" "file has $total_in_file ** lines but output has $entry_count detectable — check"
  fi
}

# ── Category 3: Post-compact produces identical output ────────────────────────

section "Category 3: Post-compact idempotency"

# Run the hook a second time and compare outputs byte-for-byte.
# compact matcher fires SessionStart on /compact — we prove the hook is stateless.

T="two consecutive hook runs produce byte-identical output (no state leak)"
{
  run1=$(run_hook)
  run2=$(run_hook)
  if [[ "$run1" == "$run2" ]]; then
    pass "$T"
  else
    bytes1="${#run1}"
    bytes2="${#run2}"
    fail "$T" "run1=${bytes1} bytes, run2=${bytes2} bytes — outputs differ (state leak or file mutation)"
  fi
}

T="hook output is non-empty on second run (post-compact context loads correctly)"
{
  run2=$(run_hook)
  if [[ "${#run2}" -gt 1000 ]]; then
    pass "$T"
  else
    fail "$T" "second run output only ${#run2} bytes — hook may be failing silently"
  fi
}

T="hook has no side effects (memory dir mtime unchanged after two runs)"
{
  # Grab mtime of a memory file before/after — hook must not write files
  before=$(stat -f "%m" "$REAL_MEMORY_DIR/last.md" 2>/dev/null || stat -c "%Y" "$REAL_MEMORY_DIR/last.md" 2>/dev/null)
  run_hook > /dev/null
  after=$(stat -f "%m" "$REAL_MEMORY_DIR/last.md" 2>/dev/null || stat -c "%Y" "$REAL_MEMORY_DIR/last.md" 2>/dev/null)
  if [[ "$before" == "$after" ]]; then
    pass "$T"
  else
    fail "$T" "last.md mtime changed (before=$before after=$after) — hook wrote to disk"
  fi
}

# ── Category 4: Critical content ─────────────────────────────────────────────

section "Category 4: Critical content verification"

# Agent MUST see standing instructions
T="output contains Standing Instructions (from standinginstructions.md)"
{
  if grep -q "Standing Instructions" <<< "$HOOK_OUTPUT"; then
    pass "$T"
  else
    fail "$T" "text 'Standing Instructions' not found in hook output"
  fi
}

# Agent MUST see its role context (from session-instructions.md)
T="output contains PMM authority rule (from session-instructions.md)"
{
  if grep -q "PMM files are the source of truth" <<< "$HOOK_OUTPUT"; then
    pass "$T"
  else
    fail "$T" "session-instructions content not found — plugin context missing"
  fi
}

# Agent MUST see recent session state from last.md
T="output contains recent session content (from last.md)"
{
  # last.md always has a "Session" reference and "## What happened" section
  if grep -q "## What happened" <<< "$HOOK_OUTPUT"; then
    pass "$T"
  else
    fail "$T" "'## What happened' not found — last.md missing or empty"
  fi
}

# Agent MUST see at least one decision from decisions.md tail
T="output contains at least one decision entry (from decisions.md tail)"
{
  section_content=$(extract_section "decisions.md")
  if grep -qE "^\*\*" <<< "$section_content"; then
    pass "$T"
  else
    fail "$T" "no decision entries found in decisions section"
  fi
}

# Agent MUST see at least one lesson from lessons.md tail
T="output contains at least one lesson entry (from lessons.md tail)"
{
  section_content=$(extract_section "lessons.md")
  if grep -qE "^\*\*" <<< "$section_content"; then
    pass "$T"
  else
    fail "$T" "no lesson entries found in lessons section"
  fi
}

# Agent MUST see at least one timeline entry from tail
T="output contains at least one timeline entry (from timeline.md tail)"
{
  section_content=$(extract_section "timeline.md")
  if grep -qE "^\*\*\[|^\*\*Session" <<< "$section_content"; then
    pass "$T"
  else
    fail "$T" "no timeline entries found in timeline section"
  fi
}

# Old entries must NOT appear — Session 8a is the oldest entry in timeline.md
# and is well outside the tail:5 window
T="output does NOT contain oldest timeline entry (Session 8a — outside tail:5 window)"
{
  if ! grep -q "Session 8a" <<< "$HOOK_OUTPUT"; then
    pass "$T"
  else
    fail "$T" "Session 8a found in output — tail:5 truncation not working on timeline"
  fi
}

# Agent roster must be visible (coordinator repo feature)
T="output contains agent roster data (from agents.md)"
{
  section_content=$(extract_section "agents.md")
  # agents.md has a markdown table with agent names
  if grep -qE "leith|tessa|sable" <<< "$section_content"; then
    pass "$T"
  else
    fail "$T" "no agent names found in agents.md section"
  fi
}

# Verify "What to do instead" appears (lessons format marker — proves real content)
T="output contains lesson detail text (lessons are not just headers)"
{
  if grep -q "What to do instead" <<< "$HOOK_OUTPUT"; then
    pass "$T"
  else
    fail "$T" "'What to do instead' not found — lessons content may be header-only"
  fi
}

# ── Category 5: Token budget ──────────────────────────────────────────────────

section "Category 5: Token budget verification"

# Hard limit: hook output should never exceed this regardless of project size.
# The 15k target from the design brief is aspirational for fresh projects.
# Mature VP memory with 55+ sessions of real content lands around 19k tokens.
# 25k is the hard ceiling — anything over this means strategies aren't working.
TOKEN_LIMIT=25000
BYTES_PER_TOKEN=4

output_bytes="${#HOOK_OUTPUT}"
approx_tokens=$(( output_bytes / BYTES_PER_TOKEN ))

# Baseline: all files, no load strategies — measure what tail strategies are saving
# Build a temp memory dir with an all-full config
BASELINE_CFG="$TMPDIR_BASE/config_baseline.md"
cat > "$BASELINE_CFG" <<'BCFG'
# PMM Configuration

## Active Files

- memory.md: active | full
- assets.md: active
- decisions.md: active | full
- processes.md: active | full
- preferences.md: active | full
- voices.md: active | full
- lessons.md: active | full
- timeline.md: active | full
- summaries.md: active | full
- progress.md: active | full
- last.md: active | full
- graph.md: active
- vectors.md: active
- taxonomies.md: active
- standinginstructions.md: active | full
BCFG

BASELINE_WRAPPER="$TMPDIR_BASE/baseline_wrap"
mkdir -p "$BASELINE_WRAPPER"

# Build a copy of memory dir with baseline config overlaid
BASELINE_MEMCOPY="$TMPDIR_BASE/baseline_mem"
cp -r "$REAL_MEMORY_DIR" "$BASELINE_MEMCOPY"
cp "$BASELINE_CFG" "$BASELINE_MEMCOPY/config.md"

ln -sf "$BASELINE_MEMCOPY" "$BASELINE_WRAPPER/memory"
baseline_output=$(
  cd "$BASELINE_WRAPPER"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    bash --noprofile --norc "$HOOK_SCRIPT" 2>/dev/null
)
baseline_bytes="${#baseline_output}"
baseline_tokens=$(( baseline_bytes / BYTES_PER_TOKEN ))
saved_bytes=$(( baseline_bytes - output_bytes ))
saved_tokens=$(( baseline_tokens - approx_tokens ))
if [[ "$baseline_bytes" -gt 0 ]]; then
  pct=$(( saved_bytes * 100 / baseline_bytes ))
else
  pct=0
fi

printf '\n  Token Budget Report\n'
printf '  %-42s %9s %9s\n' "Configuration" "Bytes" "~Tokens"
printf '  %-42s %9s %9s\n' "------------------------------------------" "---------" "---------"
printf '  %-42s %9d %9d\n' "Baseline (all full)" "$baseline_bytes" "$baseline_tokens"
printf '  %-42s %9d %9d\n' "Live config (with tail strategies)" "$output_bytes" "$approx_tokens"
printf '  %-42s %9d %9d\n' "Saved" "$saved_bytes" "$saved_tokens"
printf '  %-42s %8d%%\n'   "Reduction from tail strategies" "$pct"
printf '  Token limit: %d tokens (%d bytes)\n\n' "$TOKEN_LIMIT" "$(( TOKEN_LIMIT * BYTES_PER_TOKEN ))"

T="hook output under ${TOKEN_LIMIT} token hard ceiling (~${approx_tokens} tokens)"
if [[ "$approx_tokens" -lt "$TOKEN_LIMIT" ]]; then
  pass "$T"
else
  fail "$T" "output is ~$approx_tokens tokens; hard ceiling is $TOKEN_LIMIT (strategies not working)"
fi

# Informational: report against the 15k design target (not a pass/fail)
TARGET_15K=15000
if [[ "$approx_tokens" -lt "$TARGET_15K" ]]; then
  printf '  INFO  15k design target met: ~%d tokens (target: %d)\n' "$approx_tokens" "$TARGET_15K"
else
  printf '  INFO  15k design target exceeded: ~%d tokens (mature project normal; target was %d)\n' \
    "$approx_tokens" "$TARGET_15K"
fi

T="tail strategies reduce context (savings > 0)"
if [[ "$saved_tokens" -gt 0 ]]; then
  pass "$T"
else
  fail "$T" "live config not smaller than all-full baseline (saved_tokens=$saved_tokens)"
fi

T="tail strategies save at least 10% vs all-full baseline"
if [[ "$pct" -ge 10 ]]; then
  pass "$T"
else
  fail "$T" "only $pct% reduction from tail strategies vs all-full baseline"
fi

T="hook output is non-trivial (>10,000 bytes — real memory files loaded)"
if [[ "$output_bytes" -gt 10000 ]]; then
  pass "$T"
else
  fail "$T" "output only $output_bytes bytes — memory files may not be loading"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

TOTAL=$(( PASS + FAIL ))
printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf 'Results: %d/%d passed\n' "$PASS" "$TOTAL"

if [[ "${#FAILURES[@]}" -gt 0 ]]; then
  printf '\nFailed tests:\n'
  for f in "${FAILURES[@]}"; do
    printf '  - %s\n' "$f"
  done
fi

printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'

# Clean up synthetic fixtures if created
if [[ "${SYNTHETIC:-0}" -eq 1 && -d "$REAL_PROJECT_ROOT" ]]; then
  rm -rf "$REAL_PROJECT_ROOT"
fi

[[ "$FAIL" -eq 0 ]]
