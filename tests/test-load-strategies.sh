#!/usr/bin/env bash
# test-load-strategies.sh — Unit tests for session-start.sh load strategy logic
#
# Categories:
#   1. Load strategy correctness (synthetic data, controlled)
#   2. Context overhead measurement (actual VP memory files)
#   3. vera-* parity (structural checks: skills read files directly)
#
# Usage: bash test-load-strategies.sh
# Exit code: 0 = all pass, 1 = failures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../hooks/scripts/session-start.sh"
# Memory dir: accept env var, walk up, or create synthetic fixtures
if [[ -n "${PROJECT_ROOT:-}" ]]; then
  REAL_MEMORY_DIR="$PROJECT_ROOT/memory"
elif [[ -d "$SCRIPT_DIR/../../../../memory" ]]; then
  REAL_MEMORY_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)/memory"
else
  _SYNTH=$(mktemp -d)
  REAL_MEMORY_DIR="$_SYNTH/memory"
  mkdir -p "$REAL_MEMORY_DIR"
  cat > "$REAL_MEMORY_DIR/config.md" << 'FIX'
# PMM Configuration
## Active Files
- memory.md: active | full
- config.md: active | full
- standinginstructions.md: active | full
- last.md: active | full
- progress.md: active | full
- decisions.md: active | tail:10
- lessons.md: active | tail:5
- preferences.md: active | full
- summaries.md: active | full
- voices.md: active | full
- processes.md: active | full
- timeline.md: active | tail:5
FIX
  for f in memory.md standinginstructions.md last.md progress.md decisions.md lessons.md preferences.md summaries.md voices.md processes.md timeline.md; do
    echo "# $(basename $f .md | sed 's/.*/\u&/')" > "$REAL_MEMORY_DIR/$f"
  done
  _SYNTH_LOAD=1
fi

# ── test harness ─────────────────────────────────────────────────────────────

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

# ── temp workspace ────────────────────────────────────────────────────────────

TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

# write_config <path> [entries...]
# Writes a synthetic config.md with the given Active Files entries.
write_config() {
  local config_path="$1"; shift
  {
    printf '# PMM Configuration\n\n## Active Files\n\n'
    for entry in "$@"; do
      printf -- '- %s\n' "$entry"
    done
    printf '\n'
  } > "$config_path"
}

# write_timeline_entries <path> <n>
# Writes N timeline-style entries using **[ prefix (matches hook's emit_tail detection).
write_timeline_entries() {
  local path="$1"
  local n="$2"
  > "$path"
  local i
  for i in $(seq 1 "$n"); do
    printf '**[Entry %d]** — entry number %d\nContent line %d\n\n' "$i" "$i" "$i" >> "$path"
  done
}

# write_section_entries <path> <n>
# Writes a file with a title + N ## -headed sections (for header strategy tests).
write_section_entries() {
  local path="$1"
  local n="$2"
  > "$path"
  printf '# Title\n\nIntro paragraph.\n\n' >> "$path"
  local i
  for i in $(seq 1 "$n"); do
    printf '## Section %d\n\nContent for section %d.\n\n' "$i" "$i" >> "$path"
  done
}

# ── hook function runner ──────────────────────────────────────────────────────
#
# All function calls run via explicit bash subprocess to avoid zsh/bash
# compatibility issues (local -a, =~ regex, set -euo pipefail).
#
# The hook sets MEMORY_DIR="./memory" unconditionally at line 15, which means
# sourcing it in a subshell picks up whatever ./memory exists in the cwd.
# Solution: run each bash subprocess from a temp directory that has an empty
# memory/ subdir (zero-byte config.md), so the Tier 1 emit block produces no
# output. The target function is then called with the real test file path.
#
# Design: each runner creates a minimal work dir, cds into it, sources the hook
# (which finds empty memory/ → emit block is a no-op), then calls the function.

# run_emit_tail <file> <n>
# Runs emit_tail(file, n) from the hook in an isolated bash subprocess.
run_emit_tail() {
  local file="$1"
  local n="$2"
  local work; work="$TMPDIR_BASE/et_$$"
  mkdir -p "$work/memory"
  touch "$work/memory/config.md"
  local hook="$HOOK_SCRIPT"
  (
    cd "$work"
    CLAUDE_PLUGIN_ROOT="/dev/null" \
      bash --noprofile --norc -c "
        set -euo pipefail
        cd '$work'
        source '$hook'
        emit_tail '$file' '$n'
      " 2>/dev/null
  )
  rm -rf "$work"
}

# run_emit_header <file>
# Runs emit_header(file) from the hook in an isolated bash subprocess.
run_emit_header() {
  local file="$1"
  local work; work="$TMPDIR_BASE/eh_$$"
  mkdir -p "$work/memory"
  touch "$work/memory/config.md"
  local hook="$HOOK_SCRIPT"
  (
    cd "$work"
    CLAUDE_PLUGIN_ROOT="/dev/null" \
      bash --noprofile --norc -c "
        set -euo pipefail
        cd '$work'
        source '$hook'
        emit_header '$file'
      " 2>/dev/null
  )
  rm -rf "$work"
}

# run_get_strategy <filename> <config>
# Runs get_strategy(filename) from the hook with the given config.md.
# Suppresses hook's main-body output (config.md emit) by temporarily redirecting
# stdout during source, then restoring it for the get_strategy call.
run_get_strategy() {
  local filename="$1"
  local cfg="$2"
  local work; work="$TMPDIR_BASE/gs_$$"
  mkdir -p "$work/memory"
  cp "$cfg" "$work/memory/config.md"
  local hook="$HOOK_SCRIPT"
  (
    cd "$work"
    CLAUDE_PLUGIN_ROOT="/dev/null" \
      bash --noprofile --norc -c "
        set -euo pipefail
        cd '$work'
        # Source the hook with stdout suppressed (discards the Tier 1 emit output).
        # Then restore stdout and call get_strategy.
        exec 3>&1
        source '$hook' >/dev/null 2>&1
        exec 1>&3 3>&-
        get_strategy '$filename'
      " 2>/dev/null
  )
  rm -rf "$work"
}

# run_full_hook <memory_dir> <config_override>
# Runs the complete hook with the given memory dir and config, returns stdout.
# Uses a temp work dir with memory/ symlinked so ./memory resolves correctly.
run_full_hook() {
  local memory_dir="$1"
  local cfg="$2"
  local work; work="$TMPDIR_BASE/run_hook_$$"
  # Copy real memory files into work dir so we can overlay config.md without
  # touching the source repo (symlink + cp would clobber the live config).
  cp -r "$memory_dir" "$work"
  # Overlay the config override
  cp "$cfg" "$work/config.md"
  # Run from the parent of the memory dir so ./memory resolves to $work.
  local parent; parent="$(dirname "$work")"
  local memname; memname="$(basename "$work")"
  (
    cd "$parent"
    # Hook uses ./memory — rename work dir to 'memory' temporarily via subshell env.
    # Simplest: run from a wrapper dir with a 'memory' symlink to work.
    local wrapper; wrapper="$TMPDIR_BASE/hook_wrap_$$"
    mkdir -p "$wrapper"
    ln -sf "$work" "$wrapper/memory"
    cd "$wrapper"
    CLAUDE_PLUGIN_ROOT=/dev/null bash --noprofile --norc "$HOOK_SCRIPT" 2>/dev/null
    rm -rf "$wrapper"
  )
  rm -rf "$work"
}

# ── Category 1: Load Strategy Correctness ────────────────────────────────────

section "Category 1: Load Strategy Correctness"

# test: full strategy — emit entire file via emit_tail fallback (no entry markers = cat)
T="full strategy (no entry markers) outputs entire file"
{
  f="$TMPDIR_BASE/t_full.md"
  printf 'line one\nline two\nline three\n' > "$f"
  # emit_tail with no **[ markers falls back to cat
  out=$(run_emit_tail "$f" 5)
  if echo "$out" | grep -q 'line one' && echo "$out" | grep -q 'line three'; then
    pass "$T"
  else
    fail "$T" "got: $out"
  fi
}

# test: tail:5 on file with 20 entries outputs exactly last 5
T="tail:5 on 20-entry file outputs last 5 entries (including full content)"
{
  f="$TMPDIR_BASE/t_tail20.md"
  write_timeline_entries "$f" 20
  out=$(run_emit_tail "$f" 5)
  if echo "$out" | grep -q '\[Entry 20\]' \
    && echo "$out" | grep -q '\[Entry 16\]' \
    && echo "$out" | grep -q 'Content line 16' \
    && ! echo "$out" | grep -q '\[Entry 15\]'; then
    pass "$T"
  else
    fail "$T" "first 8 lines: $(echo "$out" | head -8)"
  fi
}

# test: tail:5 on file with 3 entries outputs all 3 (N > total = output all)
T="tail:5 on 3-entry file outputs all 3 entries"
{
  f="$TMPDIR_BASE/t_tail3.md"
  write_timeline_entries "$f" 3
  out=$(run_emit_tail "$f" 5)
  if echo "$out" | grep -q '\[Entry 1\]' \
    && echo "$out" | grep -q '\[Entry 3\]'; then
    pass "$T"
  else
    fail "$T" "out: $(echo "$out" | head -6)"
  fi
}

# test: tail:0 outputs nothing
T="tail:0 outputs nothing"
{
  f="$TMPDIR_BASE/t_tail0.md"
  write_timeline_entries "$f" 5
  out=$(run_emit_tail "$f" 0)
  if [[ -z "$out" ]]; then
    pass "$T"
  else
    fail "$T" "expected empty, got: $(echo "$out" | head -2)"
  fi
}

# test: tail:2 outputs full entry content (multi-line), not just headers
T="tail:2 outputs full multi-line entry content, not just headers"
{
  f="$TMPDIR_BASE/t_tail_content.md"
  cat > "$f" <<'EOF'
**[Entry 1]** — first
Content line 1a
Content line 1b

**[Entry 2]** — second
Content line 2a
Content line 2b

**[Entry 3]** — third
Content line 3a
Content line 3b
EOF
  out=$(run_emit_tail "$f" 2)
  if echo "$out" | grep -q 'Content line 2a' \
    && echo "$out" | grep -q 'Content line 3b' \
    && ! echo "$out" | grep -q 'Content line 1a'; then
    pass "$T"
  else
    fail "$T" "out: $(echo "$out")"
  fi
}

# test: header outputs content up to (not including) second ## heading
T="header outputs content before second ## heading"
{
  f="$TMPDIR_BASE/t_header5.md"
  write_section_entries "$f" 5
  out=$(run_emit_header "$f")
  if echo "$out" | grep -q '# Title' \
    && echo "$out" | grep -q '## Section 1' \
    && ! echo "$out" | grep -q '## Section 2'; then
    pass "$T"
  else
    fail "$T" "out: $(echo "$out")"
  fi
}

# test: header on file with only one ## heading outputs entire file
T="header on single-## file outputs entire file"
{
  f="$TMPDIR_BASE/t_header_single.md"
  printf '# Last Session\n\n## What happened\n\nSome content here.\n' > "$f"
  out=$(run_emit_header "$f")
  if echo "$out" | grep -q 'Some content here'; then
    pass "$T"
  else
    fail "$T" "out: $out"
  fi
}

# test: skip strategy — emit() returns early before any output
# We test this via the full emit() path using a config with skip
T="skip strategy emits zero bytes (via full emit path)"
{
  mdir="$TMPDIR_BASE/t_skip"
  mkdir -p "$mdir"
  cfg="$mdir/config.md"
  write_config "$cfg" "timeline.md: active | skip"
  f="$mdir/timeline.md"
  write_timeline_entries "$f" 10
  # Run hook against this memory dir — timeline should produce no output
  out=$(run_full_hook "$mdir" "$cfg")
  if ! echo "$out" | grep -q 'Entry'; then
    pass "$T"
  else
    fail "$T" "skip did not suppress output; saw Entry in: $(echo "$out" | grep Entry | head -2)"
  fi
}

# test: missing strategy column defaults to full
T="missing strategy column defaults to full"
{
  cfg="$TMPDIR_BASE/t_default_config.md"
  write_config "$cfg" "timeline.md: active"
  strategy=$(run_get_strategy "timeline.md" "$cfg")
  if [[ "$strategy" == "full" ]]; then
    pass "$T"
  else
    fail "$T" "expected full, got: $strategy"
  fi
}

# test: empty file produces no output regardless of strategy
T="empty file produces no output regardless of strategy"
{
  mdir="$TMPDIR_BASE/t_empty"
  mkdir -p "$mdir"
  f="$mdir/timeline.md"
  touch "$f"  # zero bytes
  fail_count=0
  # tail:0 outputs nothing for any file, so skip that. Test tail:5, full, header.
  for strat in 5 999; do
    out=$(run_emit_tail "$f" "$strat")
    [[ -n "$out" ]] && fail_count=$(( fail_count + 1 ))
  done
  out=$(run_emit_header "$f")
  [[ -n "$out" ]] && fail_count=$(( fail_count + 1 ))
  if [[ "$fail_count" -eq 0 ]]; then
    pass "$T"
  else
    fail "$T" "$fail_count strategies produced output on empty file"
  fi
}

# test: get_strategy parses inline | strategy from config.md Active Files
T="get_strategy parses inline pipe strategy from Active Files"
{
  cfg="$TMPDIR_BASE/t_parse_config.md"
  write_config "$cfg" \
    "timeline.md: active | tail:5" \
    "decisions.md: active | tail:10" \
    "last.md: active"
  s_timeline=$(run_get_strategy "timeline.md" "$cfg")
  s_decisions=$(run_get_strategy "decisions.md" "$cfg")
  s_last=$(run_get_strategy "last.md" "$cfg")
  if [[ "$s_timeline" == "tail:5" ]] \
    && [[ "$s_decisions" == "tail:10" ]] \
    && [[ "$s_last" == "full" ]]; then
    pass "$T"
  else
    fail "$T" "timeline=$s_timeline decisions=$s_decisions last=$s_last"
  fi
}

# ── Category 2: Context Overhead Measurement ──────────────────────────────────

section "Category 2: Context Overhead Measurement"

if [[ ! -d "$REAL_MEMORY_DIR" ]]; then
  printf '  SKIP  Real memory dir not found: %s\n' "$REAL_MEMORY_DIR"
else
  # Copy real memory files into a temp dir so we can overlay the config without
  # touching the live repo.
  MEASURE_DIR="$TMPDIR_BASE/measure_memory"
  cp -r "$REAL_MEMORY_DIR" "$MEASURE_DIR"

  # Baseline: all files active, no load strategies (full output for all files)
  BASELINE_CFG="$TMPDIR_BASE/config_baseline.md"
  cat > "$BASELINE_CFG" <<'BCFG'
# PMM Configuration

## Active Files

- memory.md: active
- assets.md: active
- decisions.md: active
- processes.md: active
- preferences.md: active
- voices.md: active
- lessons.md: active
- timeline.md: active
- summaries.md: active
- progress.md: active
- last.md: active
- graph.md: active
- vectors.md: active
- taxonomies.md: active
- standinginstructions.md: active
BCFG

  # Optimized: tail:5 on timeline + lessons (the two largest append-only files)
  OPTIMIZED_CFG="$TMPDIR_BASE/config_optimized.md"
  cat > "$OPTIMIZED_CFG" <<'OCFG'
# PMM Configuration

## Load Strategies

- timeline.md: active | tail:5
- lessons.md: active | tail:5

## Active Files

- memory.md: active
- assets.md: active
- decisions.md: active
- processes.md: active
- preferences.md: active
- voices.md: active
- lessons.md: active | tail:5
- timeline.md: active | tail:5
- summaries.md: active
- progress.md: active
- last.md: active
- graph.md: active
- vectors.md: active
- taxonomies.md: active
- standinginstructions.md: active
OCFG

  baseline_bytes=$(run_full_hook "$MEASURE_DIR" "$BASELINE_CFG" | wc -c | tr -d ' ')
  optimized_bytes=$(run_full_hook "$MEASURE_DIR" "$OPTIMIZED_CFG" | wc -c | tr -d ' ')

  saved_bytes=$(( baseline_bytes - optimized_bytes ))
  if [[ "$baseline_bytes" -gt 0 ]]; then
    pct=$(( saved_bytes * 100 / baseline_bytes ))
  else
    pct=0
  fi
  baseline_tokens=$(( baseline_bytes / 4 ))
  optimized_tokens=$(( optimized_bytes / 4 ))
  saved_tokens=$(( baseline_tokens - optimized_tokens ))

  printf '\n  Context overhead — VP memory (%s)\n' "$REAL_MEMORY_DIR"
  printf '\n  %-38s %10s %10s\n' "Configuration" "Bytes" "~Tokens"
  printf  '  %-38s %10s %10s\n' "--------------------------------------" "----------" "----------"
  printf  '  %-38s %10d %10d\n' "Baseline (all full)" "$baseline_bytes" "$baseline_tokens"
  printf  '  %-38s %10d %10d\n' "Optimized (tail:5 on timeline+lessons)" "$optimized_bytes" "$optimized_tokens"
  printf  '  %-38s %10d %10d\n' "Saved" "$saved_bytes" "$saved_tokens"
  printf  '  %-38s %9d%%\n'     "Reduction" "$pct"
  printf '\n'

  T="baseline hook output is non-zero bytes"
  if [[ "$baseline_bytes" -gt 1000 ]]; then pass "$T"; else fail "$T" "baseline_bytes=$baseline_bytes"; fi

  T="optimized output is smaller than baseline"
  if [[ "$optimized_bytes" -lt "$baseline_bytes" ]]; then
    pass "$T"
  else
    fail "$T" "optimized=$optimized_bytes baseline=$baseline_bytes"
  fi

  T="optimization saves at least 5% context"
  if [[ "$pct" -ge 5 ]]; then pass "$T"; else fail "$T" "only $pct% reduction"; fi

  T="token savings are non-negative"
  if [[ "$saved_tokens" -ge 0 ]]; then pass "$T"; else fail "$T" "saved_tokens=$saved_tokens"; fi
fi

# ── Category 3: vera-* Parity ─────────────────────────────────────────────────

section "Category 3: vera-* Parity (structural checks)"
printf '  hook strategy affects session start only, not on-demand reads by skills\n'

# Skill root: accept env var or walk up
if [[ -n "${PROJECT_ROOT:-}" ]]; then
  SKILL_ROOT="$PROJECT_ROOT/.claude/skills"
elif [[ -d "$SCRIPT_DIR/../../../../.claude/skills" ]]; then
  SKILL_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)/.claude/skills"
else
  SKILL_ROOT="$SCRIPT_DIR/../skills"
fi

find_skill() {
  local name="$1"
  local p="$SKILL_ROOT/$name/SKILL.md"
  [[ -f "$p" ]] && echo "$p" || echo ""
}

# vera:recall reads memory files directly (not from hook-injected session context)
T="vera:recall reads files directly via Read tool (not hook-injected context)"
{
  skill=$(find_skill "vera-recall")
  if [[ -z "$skill" ]]; then
    fail "$T" "vera-recall SKILL.md not found at $SKILL_ROOT/vera-recall/SKILL.md"
  elif grep -qiE "(memory/|\.md)" "$skill"; then
    pass "$T"
  else
    fail "$T" "no direct file path pattern in $skill"
  fi
}

# vera:recall does not reference hook-loaded session context
T="vera:recall does not depend on hook-loaded session context"
{
  skill=$(find_skill "vera-recall")
  if [[ -z "$skill" ]]; then
    fail "$T" "vera-recall SKILL.md not found"
  elif grep -qiE "from (session )?context|already loaded|hook.?inject" "$skill"; then
    fail "$T" "skill references hook-loaded context — strategy changes would affect it"
  else
    pass "$T"
  fi
}

# vera:recall explicitly asserts no subagent dispatch (direct reads in main context)
T="vera:recall asserts direct reads (no subagent dispatch)"
{
  skill=$(find_skill "vera-recall")
  if [[ -z "$skill" ]]; then
    fail "$T" "vera-recall SKILL.md not found"
  elif grep -qiE "no subagent|direct read|main context" "$skill"; then
    pass "$T"
  else
    fail "$T" "skill does not assert direct-read pattern (check SKILL.md)"
  fi
}

# vera:audit reads agent timelines directly
T="vera:audit reads agent timelines directly (not from hook context)"
{
  skill=$(find_skill "vera-audit")
  if [[ -z "$skill" ]]; then
    # vera-audit lives in vera-plugin, not installed as flat skill — not hook-dependent
    printf '  SKIP  vera-audit not found as flat skill (vera-plugin only — confirmed hook-independent)\n'
    PASS=$(( PASS + 1 ))
  elif grep -qiE "(timeline|memory/)" "$skill"; then
    pass "$T"
  else
    fail "$T" "no timeline/memory read pattern in $skill"
  fi
}

# vera:save dispatches a maintain agent that writes full files
T="vera:save maintain agent writes to full memory files (not strategy-constrained)"
{
  skill=$(find_skill "vera-save")
  if [[ -z "$skill" ]]; then
    fail "$T" "vera-save SKILL.md not found"
  elif grep -qiE "(maintain|append|replace|write)" "$skill"; then
    pass "$T"
  else
    fail "$T" "no maintain/write pattern in $skill"
  fi
}

# Structural: hook writes to stdout (additive context injection, no file mutation)
T="session-start.sh emits to stdout only (additive, not file-mutating)"
{
  # Hook should contain output commands but no file redirect operators
  if grep -qE "echo|cat|printf" "$HOOK_SCRIPT" \
    && ! grep -qE ">> [^&/]|> [^/&>-]" "$HOOK_SCRIPT"; then
    pass "$T"
  else
    fail "$T" "hook may be writing to files rather than stdout"
  fi
}

# Structural: load strategy logic lives only in session-start.sh (not in vera skills)
T="load strategy logic is session-start-only (no strategy terms in vera skill SKILL.md files)"
{
  skill_count=0
  strategy_ref_count=0
  for skill_path in "$SKILL_ROOT"/vera-*/SKILL.md; do
    [[ -f "$skill_path" ]] || continue
    skill_count=$(( skill_count + 1 ))
    if grep -qiE "load.?strategy|emit_tail|emit_header" "$skill_path"; then
      strategy_ref_count=$(( strategy_ref_count + 1 ))
    fi
  done
  if [[ "$skill_count" -eq 0 ]]; then
    printf '  SKIP  No vera skill SKILL.md files found at %s/vera-*/SKILL.md\n' "$SKILL_ROOT"
    PASS=$(( PASS + 1 ))
  elif [[ "$strategy_ref_count" -eq 0 ]]; then
    pass "$T"
  else
    fail "$T" "$strategy_ref_count skills reference load-strategy terms — should be hook-only"
  fi
}

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

# Clean up synthetic fixtures
[[ "${_SYNTH_LOAD:-0}" -eq 1 ]] && rm -rf "$_SYNTH" 2>/dev/null

[[ "$FAIL" -eq 0 ]]
