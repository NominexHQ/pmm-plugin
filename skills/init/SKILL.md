---
name: pmm:init
description: Initialize Poor Man's Memory in your project — runs preference wizard, scaffolds memory/ directory, configures hooks.
argument-hint: [project-name]
---

# pmm:init

Initialize Poor Man's Memory in the current project. Runs the preference wizard, scaffolds `memory/`, and configures the plugin hooks.

**When to run:** First time only. If `memory/` already exists, skip to Step 4 (check for config drift).

**Plugin note:** PMM auto-loads at session start via the SessionStart hook. No CLAUDE.md changes needed — the hook handles Tier 1 injection automatically when you install the pmm plugin.

---

## Step 1 — Check for existing installation

Read the current directory. If `memory/config.md` exists, PMM is already initialised. Tell the user:

> PMM is already initialised in this project. Run `pmm:settings` to change configuration.

Stop. Do not overwrite existing memory files.

---

## Step 2 — Preference wizard

Present these questions interactively before creating any files. Use the `AskUserQuestion` tool with multiple-choice options where specified.

**Q1: Save cadence** — How often should memory be updated?

Options:
- `every-milestone` (default) — at decisions, completions, session breaks
- `every-N-messages` — specify a number, e.g. every 5 messages
- `on-request` — only when you explicitly ask

*Note: For frequent saves, choose `every-N-messages` — hooks handle the trigger automatically.*

**Q2: Commit behaviour** — When should changes be committed to git?

Options:
- `auto-commit` (default) — each save cycle ends with a commit
- `session-end` — files updated throughout, one commit at session end
- `manual` — you decide when to commit

*Git commits are your audit trail. Auto-commit means you never lose work.*

**Q3: Sliding window size** — How many entries to load at session start for timeline.md and summaries.md:

Options:
- `light` — 30 timeline / 5 summaries
- `moderate` (default) — 50 timeline / 10 summaries
- `heavy` — 100 timeline / 20 summaries
- `unlimited` — load full file at session start

*Files are never truncated on disk. The window controls session-start injection only. Git is the full audit trail.*

**Q4: Verbosity** — How should memory updates be communicated?

Options:
- `silent` — agent status indicator only
- `summary` (default) — one-line confirmation after updates
- `verbose` — full detail of what changed

**Q5: Repository visibility** — Is this repository public or private?

Options:
- `public` (default) — avoid personal emails, use handles over full names, summarise sensitive decisions without verbatim internal detail
- `private` — no PII restrictions, full fidelity

*Memory files accumulate names, decisions, and business context. This controls how the maintain agent handles that data.*

**Q6: Maintain agent model** — Which model handles memory updates?

Options:
- `haiku` (default) — fastest and cheapest, good for structured file edits
- `sonnet` — balanced, better for nuanced or complex updates
- `opus` — most capable, highest cost

*Maintain work is mechanical (read, append, replace sections). Haiku handles it well at ~10x less cost than Opus.*

**Q7: Active files** — Which memory files do you want? All are active by default.

Multi-select from:
- `memory.md` — long-term project facts
- `assets.md` — people, tools, systems, organisations
- `decisions.md` — committed decisions, append-only
- `processes.md` — workflows and repeatable procedures
- `preferences.md` — user style, quirks, working habits
- `voices.md` — tone profiles and reasoning lenses
- `lessons.md` — mistakes and lessons learned, append-only
- `timeline.md` — compressed chronological record (sliding window)
- `summaries.md` — periodic session rollups (sliding window)
- `progress.md` — current state, milestones, what's next
- `last.md` — last 3–5 significant actions in detail
- `graph.md` — typed edges between concepts, decisions, entities
- `vectors.md` — semantic similarities, clusters, embedding registry
- `taxonomies.md` — classification systems and naming conventions
- `standinginstructions.md` — persistent rules that always apply, append-only

*Deactivated files are not created and won't be maintained. You can activate them later with `pmm:settings`.*

**Q8: Context tiers** — How should memory files load at session start?

Options:
- `tiered` (default) — Tier 1 (12 core files) via SessionStart hook; Tier 2 (graph, vectors, taxonomies, assets) read on demand. Saves ~14k tokens per session.
- `all-in-context` — all active files loaded at session start

*Tier 1 covers everything needed for session orientation. Tier 2 is reference/historical data — loaded on demand when a request needs it.*

**Q9: Memory priority** — How should PMM interact with Claude's built-in auto-memory?

Options:
- `pmm-first` (default) — PMM is the source of truth; Claude auto-memory kept minimal (skill references and feedback only)
- `deduplicate` — actively merge overlapping content between both systems
- `coexist` — both operate independently

*Claude Code has its own auto-memory. PMM-first means PMM wins — no duplication of decisions, lessons, or timeline events.*

---

## Step 3 — Write config.md

Write `memory/config.md` using the user's answers. Use this exact format:

```markdown
# PMM Configuration

Settings that control how Poor Man's Memory behaves.
Run `pmm:settings` at any time to change these.

## Save Cadence

- Mode: <Q1 answer>

## Commit Behaviour

- Mode: <Q2 answer>

## Sliding Window Size

- Timeline max: <from Q3: light=30, moderate=50, heavy=100, unlimited=9999>
- Summaries max: <from Q3: light=5, moderate=10, heavy=20, unlimited=9999>

## Verbosity

- Mode: <Q4 answer>

## Repository Visibility

- Visibility: <Q5 answer>

## Maintain Agent Model

- Model: <Q6 answer>

## Readonly Agent Model

- Model: haiku

## Session Start

- Mode: lazy

## Maintain Strategy

- Strategy: single

## Recall Beyond Window

- Mode: prompt

## Context Tiers

- Mode: <Q8 answer>

## Memory Priority

- Mode: <Q9 answer>

## Pre-Compact Hook

- pre_compact: on

## Active Files

<!-- Which memory files are active. Deactivated files are not created or loaded. -->
<!-- config.md and BOOTSTRAP.md are always active. -->
<!-- Load Strategy column is optional. Missing = defaults to full. -->
<!-- Valid strategies: full | tail:N | header | skip -->
<!-- Tier 2 files (graph, vectors, taxonomies, assets) are not loaded at session start regardless of strategy. -->
<for each active file, apply default load strategy:>
- memory.md: active | full
- assets.md: active
- decisions.md: active | tail:10
- processes.md: active | full
- preferences.md: active | full
- voices.md: active | full
- lessons.md: active | tail:5
- timeline.md: active | tail:5
- summaries.md: active | full
- progress.md: active | full
- last.md: active | full
- graph.md: active
- vectors.md: active
- taxonomies.md: active
- standinginstructions.md: active | full
<for each file NOT in Q7 active list: "- <file>: inactive">

## Protected Files

- secrets.md: protected
- secrets_git: never
```

---

## Step 4 — Scaffold memory files

Dispatch a `general-purpose` agent using the `Readonly Agent Model` from config (haiku by default) with this prompt:

> Scaffold the memory/ directory for Poor Man's Memory. This is a WRITE task — create files. Do NOT run git commands.
>
> 1. Read `references/core.md` for the file inventory and rules.
> 2. Read `references/templates.md` for the initial content of each file.
> 3. Read `memory/config.md` to determine which files are active.
> 4. Create the `memory/` directory if it doesn't exist.
> 5. Always create `memory/BOOTSTRAP.md` — use the template from `references/templates.md`.
> 6. `memory/config.md` is already written — skip it.
> 7. For each file marked `active` in config.md, create it using its template from `references/templates.md`. Skip `inactive` files.
> 8. Always create `memory/secrets.md` from its template — it is local-only and gitignored regardless of the active files list.
> 9. Return a confirmation listing: files created, files skipped (inactive), and any errors.

Wait for the agent to return before proceeding.

---

## Step 5 — Git setup

Run the following in order:

1. Check if a git repo exists:
   ```bash
   git rev-parse --is-inside-work-tree 2>/dev/null
   ```
   - If exit code is non-zero: run `git init` and tell the user the repo was initialised.
   - If already a git repo: note it and continue.

2. Create `.gitignore` entry for secrets.md if not already present:
   ```bash
   grep -q "memory/secrets.md" .gitignore 2>/dev/null || echo "memory/secrets.md" >> .gitignore
   ```

3. Stage and commit the scaffolded files:
   ```bash
   git add memory/ .gitignore && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: initialise PMM structured memory"
   ```

---

## Step 6 — Confirm and guide

Tell the user:

> PMM is initialised. Here's what was set up:
>
> - `memory/` scaffolded with <N> files
> - Config: <save cadence>, <commit behaviour>, <verbosity>
> - Active files: <list of active files>
>
> **How it works:**
> - The SessionStart hook loads Tier 1 memory files into context automatically when you start a session. No CLAUDE.md changes needed.
> - Run `pmm:save` to save memory at any time.
> - Run `pmm:settings` to change configuration.
> - Run `pmm:hydrate` to populate memory files from existing project context.
>
> To pre-approve git commands for memory operations (avoids permission prompts), add this to `.claude/settings.json`:
>
> ```json
> {
>   "permissions": {
>     "allow": [
>       "Bash(git add memory/*)",
>       "Bash(git commit -m *)",
>       "Bash(git push origin main*)"
>     ]
>   }
> }
> ```

---

## Rules

- Never overwrite an existing `memory/` installation. Check first (Step 1).
- File structure rules and file-by-file operating rules are in `references/core.md` — do not duplicate them here.
- Templates for each memory file are in `references/templates.md`.
- Agents edit files only. Main context handles all git commands.
- `memory/secrets.md` is always created, always gitignored, never committed.
- The SessionStart hook injects Tier 1 files into context at session start. No CLAUDE.md changes needed.

---

## Phase 4 — Implicit Recall (mid-conversation)

Implicit recall handles mid-conversation memory lookups without explicit `pmm:query` invocation. It follows a tiered escalation:

### T1 — In-Context (0ms overhead)
Search files already loaded in the context window via the SessionStart hook. Whatever load strategy delivered at session start — full, tail:N, or header — search that content first.

### T2 — Extended Context (<500ms)
If T1 misses, read Tier 2 files on demand (graph.md, vectors.md, taxonomies.md, assets.md). Only read files relevant to the query — not all four.

### T3 — Full File Reads (<2s)
If still no results, re-read all active files in full (overriding tail:N / header load strategies from session start) and search again. This catches entries that exist in memory files but were outside the loaded window at session start.

### T4 — Git History (<10s)
If T1+T2+T3 all miss, fall back to git history search (`git log --grep` + `git show`).

**Implicit recall never prompts for T4 git access.** It follows the `Recall Beyond Window` config silently:
- If `Mode: auto` — search git history silently
- If `Mode: prompt` — implicit recall stops at T3. The user must run `pmm:query` explicitly to trigger the prompt gate for git history access.

Each tier stops on hit. No unnecessary escalation.
