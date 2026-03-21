# Poor Man's Memory

Structured, git-backed agent memory for Claude Code.

PMM gives Claude Code a persistent, compounding memory system: 16 specialized markdown files organized in tiers, auto-loaded at session start via hooks, auto-saved at threshold or on request.

---

## What it does

- **Structured memory**: 16 files with distinct jobs — decisions, lessons, preferences, timeline, graph, vectors, and more. Each file stays focused; nothing bleeds between them.
- **Auto-loads at session start**: The `SessionStart` hook injects Tier 1 files (the 12 essential files) directly into context. Tier 2 files (graph, vectors, taxonomies, assets) load on demand.
- **Auto-saves**: The `Stop` hook tracks save cadence. When the threshold fires, `pmm:save` runs. You can also save manually at any milestone.
- **Git-backed**: Every save commits to git. Full audit trail. Memory compounds — earlier sessions inform later ones.
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
- **Stop** (`should-save.sh`): Tracks save cadence based on your `config.md` settings. Zero token cost — pure bash counter. Fires `pmm:save` when threshold is reached.
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
