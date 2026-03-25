---
name: pmm-settings
description: >
  Change Poor Man's Memory configuration. Re-presents preference prompts for save cadence,
  commit behaviour, push behaviour, sliding window size, verbosity, repository visibility,
  maintain agent model, maintain strategy, readonly agent model, session start mode, recall
  beyond window, secrets_git, pre-compact hook, active files, and load strategies. Use when the
  user runs /pmm-settings or asks to change memory system settings. Trigger on: "pmm-settings",
  "/pmm-settings", "change memory settings", "configure pmm", "memory configuration", "update
  pmm settings", "pmm preferences", or any request to view or change PMM configuration.
---
# PMM Settings

Reconfigure the Poor Man's Memory system. This skill presents the same preference prompts used during first-run initialisation, pre-filled with current values.

## When Triggered

User runs `/pmm-settings` or asks to change memory configuration.

## Flow

### Step 1 — Read current config

Read `memory/config.md` and display the current settings to the user as a summary:

> **Current PMM settings:**
> - Save cadence: [current]
> - Commit behaviour: [current]
> - Auto-push: [current]
> - Window size: [current preset or custom]
> - Verbosity: [current]
> - Repository visibility: [current]
> - Maintain agent model: [current]
> - Maintain strategy: [current]
> - Readonly agent model: [current]
> - Session start: [current]
> - Recall beyond window: [current]
> - Secrets in git: [current]
> - Pre-compact hook: [current]
> - Context tiers: [current]
> - Memory priority: [current]
> - Active files: [count] of 15 active
> - Deactivated: [list, or "none"]
> - Load strategies: [list files with non-default strategies, or "all full"]

### Step 2 — Present preference prompts

Use `AskUserQuestion` to present the same questions from Phase 1 of the main skill, pre-filled with current values. The user can change any or all options.

**Q1: Save cadence** — How often should memory be updated?
- Every major milestone (default) — updates at decisions, milestones, session breaks
- Every N messages — specify a number (e.g. every 5 messages)
- On explicit request only — only when you ask

*Note: For fine-grained control, use `/loop` to run a save prompt on a recurring interval.*

**Q2: Commit behaviour** — When should changes be committed to git?
- Auto-commit after every update batch (default)
- Batch commits at session end only
- Manual commits only

**Q3: Auto-push** — Should memory commits be automatically pushed to the remote?
- Off (default) — commits stay local until you push manually
- On — git push runs after every memory commit (failures reported, not swallowed)

**Q4: Sliding window size** — How many entries to keep before trimming?
- Light (30 timeline / 5 summaries)
- Moderate (50 / 10, default)
- Heavy (100 / 20)
- Unlimited (no trimming)

**Q5: Verbosity** — How should memory updates be communicated?
- Silent — agent status indicator only
- Summary (default) — one-line confirmation
- Verbose — full detail

**Q6: Repository visibility** — Is this repository public or private?
- Public (default) — maintain agent avoids personal emails, uses handles over full names, summarises sensitive decisions
- Private — no PII restrictions, full fidelity in all files

**Q7: Maintain agent model** — Which model should handle memory updates?
- Haiku (default) — fastest and cheapest, good for mechanical file edits
- Sonnet — balanced, better at nuanced updates
- Opus — most capable, highest cost

*Note: Session-start and recall agents use the Readonly Agent Model (Q11 below).*

**Q8: Maintain strategy** — How should memory saves dispatch agents?
- Single (default) — all files updated in one agent dispatch per save (minimises token/message overhead, budget-friendly)
- Tiered — 3 concurrent agents grouped by file dependency (faster for large installations with many active files)

*Explain: Single mode saves 2 agent dispatches per /pmm-save. Tiered mode is faster if you have a large memory installation and need parallel tier updates — but costs 3x the agent dispatches.*

**Q9: Secrets in git** — Should `memory/secrets.md` be committed to git?
- Never (default) — pre-commit hook blocks any commit containing secrets.md
- Allow with warning — hook warns but does not block. **Only use this if you understand the implications: secrets.md contents will be in git history and permanently exposed if pushed to a public remote.**

**Q10: Active files** — Which memory files to activate? (multi-select, config.md always active)
- memory.md, assets.md, decisions.md, processes.md, preferences.md, voices.md, lessons.md, timeline.md, summaries.md, progress.md, last.md, graph.md, vectors.md, taxonomies.md, standinginstructions.md

**Q11: Readonly agent model** — Which model should handle read-only operations (session-start, recall, pmm-query, pmm-dump, pmm-status, pmm-viz)?
- Haiku (default) — cheapest, ~95% cheaper than Opus. Ideal for mechanical reads.
- Sonnet — balanced, ~73% cheaper than Opus. Better at synthesis.
- Opus — most capable, highest cost.
- Inherit — use the parent model (pre-v1.5.0 behaviour, not recommended for Opus users)

*Haiku is strongly recommended — read-only agents do simple file I/O and retrieval, not nuanced reasoning.*

**Q12: Session start mode** — How should PMM load memory at session start?
- Lazy (default) — skip Phase 2 agent; memory files are already in context via plugin SessionStart hook. Saves ~33k tokens per session. Requires pmm plugin to be installed.
- Eager — always dispatch a Phase 2 agent to read and synthesise all memory files (pre-v1.5.0 behaviour)

*Lazy mode works automatically when the pmm plugin is installed — the SessionStart hook handles loading.*

**Q13: Recall beyond window** — When a recall query isn't found in the current memory window, should PMM ask before searching git history?
- Prompt (default) — ask permission before dispatching an agent to search git history (one agent dispatch per beyond-window query)
- Auto — silently search git history when needed, without prompting (costs 1 agent dispatch per miss)

*In lazy mode, all active memory files are already in context — git history is only needed for entries that have been trimmed from sliding-window files (timeline.md, summaries.md). Most queries will be answered from context without any agent dispatch.*

**Q14: Pre-compact hook** — Should PMM save before `/compact`?
- On (default) — session-instructions.md soft instruction directs Claude to save before compact
- Off — suppress the pre-compact save instruction entirely

**Q15: Context tiers** — How should memory files be loaded at session start?
- Tiered (default) — Tier 1 (12 essential files) injected by SessionStart hook; Tier 2 (4 reference files) read on demand. Saves ~14k tokens vs all-in-context.
- All in context — all active files loaded at session start (pre-v1.8.0 behaviour)

*Explain: Tier 1 (config, standinginstructions, progress, last, preferences, decisions, lessons, processes, voices, memory, summaries, timeline) covers everything needed for session orientation. Tier 2 (graph, vectors, taxonomies, assets) is available on demand via the Read tool when a recall query needs it.*

**Q16: Memory priority** — How should PMM interact with Claude's built-in auto-memory?
- PMM first (default) — PMM is the primary memory system; Claude auto-memory kept minimal (skill references and feedback only)
- Deduplicate — actively merge overlapping content between PMM and Claude auto-memory
- Coexist — both systems operate independently (pre-v1.8.0 behaviour)

*Explain: Claude Code has its own auto-memory system (in .claude/projects/.../memory/). PMM-first means PMM is the source of truth — Claude auto-memory should not duplicate facts, decisions, or timeline events that PMM already tracks.*

**Q17: Load strategies** — How much of each Tier 1 file should the SessionStart hook inject at session start?

Read the current `## Active Files` section from `memory/config.md` and display each active Tier 1 file with its current strategy (or `full` if none set). For each file the user wants to change, accept a new strategy:
- `full` (default) — load the entire file
- `tail:N` — load only the last N lines/entries (recommended for `timeline.md`, `decisions.md`, `lessons.md`)
- `header` — load only the file header
- `skip` — exclude from session-start injection (file remains active for maintain; use `pmm-recall` to load on demand)

Suggested defaults if starting fresh:
- `timeline.md`: tail:5
- `decisions.md`: tail:10
- `lessons.md`: tail:5
- All others: full (or omit the column)

Format written to `config.md`:
```
- timeline.md: active | tail:5
- decisions.md: active | tail:10
```

Missing `| strategy` = `full`. Tier 2 files (`graph.md`, `vectors.md`, `taxonomies.md`, `assets.md`) ignore load strategies — they are never loaded at session start.

*Note: Load strategies only affect what the SessionStart hook injects. `pmm-recall` always loads the full file on demand regardless of the configured strategy.*

### Step 3 — Write updated config

Update `memory/config.md` with the new values. Preserve the file format from the template.

If active files changed OR context tier mode changed:
- Update the tier configuration in `${CLAUDE_PLUGIN_ROOT}/context/session-instructions.md` based on current active files and context tier mode:
  - If `Mode: tiered` (default): Tier 1 active files are injected by the SessionStart hook; Tier 2 active files are listed as on-demand only
  - If `Mode: all-in-context`: all active files are injected by the SessionStart hook
- Tier 1 files: config, standinginstructions, progress, last, preferences, decisions, lessons, processes, voices
- Tier 2 files: graph, vectors, taxonomies, timeline, summaries, memory, assets
- If files were deactivated, do NOT delete them — just remove them from the file list
- If files were activated that don't exist yet, create them from templates in `${CLAUDE_PLUGIN_ROOT}/references/templates.md`
- **For each newly activated file**, dispatch Phase 5 (Hydrate) using the prompt from `${CLAUDE_PLUGIN_ROOT}/references/README.md`. This ensures activated files start with synthesized content from existing memory, not empty templates. Commit hydrated files separately: `git add memory/<file> && git commit -m "memory: hydrate <file> from existing context"`

### Step 4 — Commit

```bash
git add memory/config.md && git commit -m "memory: update PMM configuration"
```

Confirm to the user: settings updated and saved.
