# Poor Man's Memory

Structured, git-backed memory for Claude Code. Memory that compounds, not rots.

Claude Code's recall is shallow. Native auto-memory writes flat summaries. Each `/compact` cycle compresses further. Decisions lose their rationale. Lessons lose their context. By Monday, you're re-explaining choices you made on Thursday. That's context rot. Not forgetting, but fading.

PMM fixes that: structured markdown files for the most recent context, git log for everything else.

---

## What it does

- **Structured memory**: 16 files with distinct jobs — decisions, lessons, preferences, timeline, graph, vectors, and more. Each file stays focused; nothing bleeds.
- **Auto-loads at session start**: The `SessionStart` hook injects Tier 1 files (the 12 essential files) directly into context. Tier 2 files (graph, vectors, taxonomies, assets) load on demand.
- **Auto-saves**: The `Stop` hook monitors save cadence. When the threshold is reached, it blocks exit until `pmm:save` runs. Save manually at any milestone.
- **Decision history**: Every decision is committed to git with context. `git log` is your memory audit trail — you can trace any choice back to when it was made and why.
- **Configurable**: model selection (haiku by default), sliding window size, verbosity, repository visibility, PII handling.

---

## Quick start

1. Install this plugin via the Claude Code plugin manager
2. Run `pmm:init` — answers a few setup questions, creates `memory/` in your project
3. Start working — memory saves automatically at milestones

That's it. PMM handles the rest.

---

## Skills

| Skill | What it does |
|---|---|
| `pmm:init` | First-run setup: creates `memory/`, writes `config.md`, installs hooks |
| `pmm:save` | Save current session to memory — synthesises delta, dispatches maintain agent, commits |
| `pmm:query` | Deep recall with explicit search — traverses graph, vectors, and taxonomy |
| `pmm:hydrate` | Populate empty or thin memory files from existing session context |
| `pmm:settings` | Reconfigure PMM — re-presents all setup prompts pre-filled with current values |
| `pmm:status` | Summary of current memory state — file counts, last save, active config |
| `pmm:viz` | Generate a D3.js graph visualization of the memory graph |
| `pmm:dump` | Export memory files as a single structured document for external use |
| `pmm:update` | Update PMM to a new version — handles file migrations |

---

## How hooks work

Installing PMM wires three hooks into your project:

- **SessionStart** (`session-start.sh`): Runs when Claude Code opens your project. Reads `config.md`, injects active Tier 1 files into context, loads `session-instructions.md`. No manual `@-import` editing needed.
- **Stop** (`should-save.sh`): Monitors save cadence based on your `config.md` settings. Zero token cost — pure bash counter. When the threshold is reached, blocks exit until a save completes.
- **SessionEnd** (soft instruction in `session-instructions.md`): Prompts Claude to save before closing. Best-effort — not a blocking hook.

---

## Memory file tiers

**Tier 1** (always loaded via SessionStart hook):
`config.md`, `standinginstructions.md`, `last.md`, `progress.md`, `decisions.md`, `lessons.md`, `preferences.md`, `memory.md`, `summaries.md`, `voices.md`, `processes.md`, `timeline.md`

**Tier 2** (on demand — read when a query needs them):
`graph.md`, `vectors.md`, `taxonomies.md`, `assets.md`

---

## Full documentation

[https://github.com/NominexHQ/poor-man-memory](https://github.com/NominexHQ/poor-man-memory)

---

## License

MIT. Built by [NominexHQ](https://github.com/NominexHQ).
