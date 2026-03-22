# Poor Man's Memory

Structured, git-backed memory for Claude Code. Memory that compounds, not rots.

Claude Code's recall is shallow. Native auto-memory writes flat summaries. Each `/compact` cycle compresses further. Decisions lose their rationale. Lessons lose their context. By Monday, you're re-explaining choices you made on Thursday. That's context rot. Not forgetting, but fading.

PMM fixes that: structured markdown files for the most recent context, git log for everything else.

---

## What it does

- **Structured memory**: 16 files with distinct jobs — decisions, lessons, preferences, timeline, graph, vectors, and more. Each file stays focused; nothing bleeds.
- **Auto-loads at session start**: The `SessionStart` hook injects Tier 1 files (the 12 essential files) directly into context. Tier 2 files (graph, vectors, taxonomies, assets) load on demand.
- **Auto-saves**: The `Stop` hook monitors save cadence based on your config. When the threshold is reached, it blocks exit until a save completes. Save manually at any milestone.
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

### `pmm:init`

**The pain**: Without init, there's no structure. You'd have to manually create 16 files, figure out the heading format for each, wire hooks, set up git ignores for secrets — all before writing a single line of memory. Most people would give up or build something ad hoc that falls apart in a week.

**What it does**: Runs a 9-question preference wizard, scaffolds the entire `memory/` directory with properly formatted files, and sets up git integration. First-run only — if `memory/` already exists, it tells you to use `pmm:settings`.

**Arguments**:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `[project-name]` | No | Current directory name | Names the project in config and commit messages |

**Use cases**:
- Starting a new project and want memory from day one
- Adding PMM to an existing project mid-stream (init + `pmm:hydrate --all` bootstraps from current session context)
- Setting up a shared repo where multiple people contribute and need traceable decisions

**Example**:
```
pmm:init my-api-project
```

The wizard asks about save cadence, commit behaviour, window sizes, verbosity, which files to activate, model selection, and context tiers. Every answer has a sensible default — you can enter through all 9 questions and get a working setup.

---

### `pmm:save`

**The pain**: Without explicit saves, memory is whatever auto-memory decided to keep — flat, lossy, no structure. You made a critical architecture decision at 2pm. By 4pm, auto-memory has compressed it into "discussed architecture." The rationale? Gone. The alternatives you rejected? Gone. `pmm:save` captures decisions with rationale, lessons with context, timeline with attribution.

**What it does**: Synthesizes what changed this session, dispatches a maintain agent (haiku by default) to update the relevant memory files, and commits to git.

**Arguments**:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `[notes]` | No | None | Free text about what changed — appended to the synthesis the maintain agent receives |

**Use cases**:
- After making a key decision: `pmm:save decided to use postgres over sqlite for multi-tenant`
- Before running `/compact` — always save first so structured memory captures what compact will compress
- At the end of a working session, even if the Stop hook would catch it — explicit saves with notes produce better memory than automated ones
- After a mistake or lesson learned: `pmm:save the retry logic bug taught us to always test with network failures`

**Example**:
```
pmm:save shipped the auth refactor, decided JWT over session tokens
```

**Behaviour notes**:
- Skip check: if nothing meaningful happened (pure read-only session), skips silently — no wasted tokens
- Pre-check: detects template-only files and auto-hydrates them before the first maintain cycle
- Auto-commit by default. Change via `pmm:settings` if you want manual commit control

---

### `pmm:query`

**The pain**: You know you decided something three weeks ago but can't find it. You remember the conversation but not the file. Native memory doesn't have search — you either remember or you don't. `pmm:query` gives you filtered, attributed recall with provenance. You can trace not just what was decided, but who said it, when, and how the system found it.

**What it does**: Searches memory files with filtering, attribution, and optional deep traversal through graph relationships and vector clusters. Context-first — answers from loaded Tier 1 files without dispatching an agent when possible.

**Arguments**:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `<question>` | Yes | — | Natural language question or search term. Shows usage hint if empty |

**Filters**:

| Filter | Example | What it does |
|--------|---------|--------------|
| `by user:<name>` | `by user:raffi` | Attribution — find entries from a specific person |
| `by agent:<name>` | `by agent:leith` | Attribution — find entries from a specific agent |
| `since <date>` | `since 2026-03-15` | Date range start |
| `before <date>` | `before 2026-03-20` | Date range end |
| `in <file>` | `in decisions` | Scope search to one memory file |

**Flags**:

| Flag | What it does |
|------|--------------|
| `deep` | Expands search via vectors, graph, and taxonomy. Tags results with provenance: `[via vectors]`, `[via graph]`, `[via taxonomy]` |
| `dump` | Returns structured verbatim entries grouped by file instead of prose narrative |

**Use cases**:
- `pmm:query why did we choose sqlite?` — find the decision and its rationale
- `pmm:query auth changes since 2026-03-01 deep` — find everything auth-related with graph traversal
- `pmm:query by user:raffi in decisions` — what did Raffi decide?
- `pmm:query deployment process dump` — get raw entries, not a narrative

**Behaviour notes**:
- Context-first: if `bootstrap_wired` is set, answers from loaded Tier 1 files without dispatching an agent. Tier 2 files load on demand via the Read tool. Agent dispatch only in eager mode or when bootstrap isn't wired.
- Beyond-window fallback: if no results found in current files, checks config for `recall_beyond_window` mode (`prompt` or `auto`) before searching git history.

---

### `pmm:hydrate`

**The pain**: You activate a new file type — say `voices.md` — but it starts empty. The maintain agent will keep it shallow because it has nothing to build on. Each `pmm:save` adds a thin entry to an empty file, and that thin entry becomes the foundation for the next thin entry. The file never catches up. Hydrate breaks the cycle: it reads everything the system already knows and synthesizes a rich starting point.

**What it does**: Populates empty or thin memory files by reading all existing populated memory and synthesizing content for the target files. Cold start prevention.

**Arguments**:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `[file.md]` | No | — | Hydrate one specific file. Shows usage hint + file status list if omitted |
| `--all` | No | — | Hydrate all template-only files in batch |
| `--force` | No | — | Re-hydrate even if the file has content (useful for stale or thin files) |

Combinations: `--all --force` re-hydrates everything.

**Use cases**:
- After activating `graph.md` via `pmm:settings`: `pmm:hydrate graph.md`
- After `pmm:init` on an existing project with session history: `pmm:hydrate --all`
- When a file feels thin after many sessions: `pmm:hydrate preferences.md --force`
- Quick audit of file status: `pmm:hydrate` with no args shows which files are populated vs template-only

**Example**:
```
pmm:hydrate voices.md
```

**Behaviour notes**:
- Template-only detection: strips blank lines, comments, and headings. If fewer than 3 content lines remain, the file is considered template-only.
- Reads ALL populated memory files to build context before synthesizing — the output is informed by everything the system knows.

---

### `pmm:settings`

**The pain**: Your needs change. You started with haiku but want sonnet for a complex codebase. You want to activate `graph.md` now that you have enough sessions for it to be useful. You want to switch from auto-commit to manual because you're working on a shared repo. Without `pmm:settings`, you'd be hand-editing `config.md` and hoping you got the format right.

**What it does**: Shows current configuration as a summary, then re-presents all 16 preference questions pre-filled with current values. Change what you want, skip what you don't.

**Arguments**: None.

**Preferences managed**:

| Category | Settings |
|----------|----------|
| Save behaviour | Save cadence, commit behaviour, auto-push |
| Display | Verbosity, repo visibility |
| Models | Maintain model, readonly model, maintain strategy |
| Memory | Active files, context tiers, memory priority, window sizes |
| Session | Session start mode, recall beyond window, pre-compact hook |
| Security | Secrets in git |

**Use cases**:
- Switching maintain model from haiku to sonnet for a project with complex domain knowledge
- Activating `graph.md` and `vectors.md` after 10+ sessions (enough data to be useful)
- Enabling auto-push for a team repo where others need to see memory updates
- Adjusting sliding window size when timeline.md is getting too long

**Example**:
```
pmm:settings
```

**Behaviour notes**:
- If you activate files that don't exist yet, PMM creates them from templates and auto-hydrates — no separate step needed.

---

### `pmm:status`

**The pain**: "Is memory actually saving?" You can't tell from the outside. Claude seems to have forgotten something — is it because the last save was hours ago? Because a file is still template-only? Because config drifted? Status gives you the dashboard: what the system actually did, not what you assumed it did.

**What it does**: Runs a diagnostic scan of your entire memory system and reports health metrics. Runs as a subagent to keep your main context clean.

**Arguments**: None.

**Output includes**:
- Initialization state
- Last save time
- Recent commits (last 5)
- File health table: last modified, line count, populated vs template-only status
- Token burn estimate per save (read + write tokens)
- Warnings: template-only files, stale files, stale `last.md`, large files (>200 lines)

**Use cases**:
- First thing Monday morning — check what state memory is in before starting work
- After a long session without saves — see if anything was missed
- When Claude seems to have lost context — diagnose whether it's a memory issue or a context window issue
- Periodic health check — are any files growing too large? Are token costs reasonable?

**Example**:
```
pmm:status
```

---

### `pmm:viz`

**The pain**: Memory files are text. You can't see the shape of what you know. Which concepts cluster together? How have relationships evolved over 20 sessions? Where are the dense knowledge areas vs the gaps? Viz turns the graph into something you can explore visually — interactive, scrubbable through time, in your browser.

**What it does**: Generates an interactive D3.js force-directed graph visualization with a time slider for scrubbing through git history. Opens in your default browser. Runs as a subagent.

**Arguments**:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `[mode]` | No | `full` | One of: `graph`, `clusters`, `timeline`, or omit for all three combined |

**Modes**:
- `graph` — relationships from `graph.md` only
- `clusters` — cluster members + similarity edges from `vectors.md` only
- `timeline` — event nodes, decision nodes, and temporal edges
- `full` (default) — everything combined

**Use cases**:
- After a major milestone — see how the knowledge graph has grown
- When onboarding someone to a project — the visualization tells the story of how decisions evolved
- Debugging memory structure — find orphaned nodes, unexpected clusters, missing relationships
- Presentation material — the graph is a visual proof of structured memory at work

**Example**:
```
pmm:viz graph
```

**Behaviour notes**:
- Cache-aware: if the graph hasn't changed since last render, opens the cached HTML instantly — no regeneration cost.

---

### `pmm:dump`

**The pain**: Quick health check without leaving the terminal. You don't want to open a browser, you just want to see: which files are active, which are stale, what does the graph look like in text form? Dump gives you ASCII visualization at three levels of detail.

**What it does**: Terminal-only memory visualization. No browser, no subagent overhead for simple modes. Runs as a subagent for detailed mode.

**Arguments**:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `[level]` | No | `status` | One of: `status`, `summary`, `detailed` |

**Levels**:
- `status` — heatmap only: file activity heat levels + token burn estimate
- `summary` — heatmap + cluster list + last 5 timeline entries
- `detailed` — full ASCII: graph map with boxed nodes and edges, heatmap, similarity matrix, cluster trees

**Use cases**:
- `pmm:dump` — quick glance at file activity before starting work
- `pmm:dump summary` — slightly more context without the full graph render
- `pmm:dump detailed` — full picture when you can't use a browser or want text output for documentation
- Piping to a file for external analysis: `pmm:dump detailed` and copy the output

**Example**:
```
pmm:dump summary
```

---

### `pmm:update`

**The pain**: PMM evolves. New skills, new file types, better templates. You don't want to manually diff upstream changes against your installation, figure out what's new, and hand-apply patches — especially when the update adds a new memory file type that needs hydration or changes a hook script. Update handles migration without losing your memory: system files get replaced, your data stays untouched.

**What it does**: Checks upstream for a new PMM version, shows what changed, and applies updates to system files only. Never touches `memory/`.

**Arguments**: None.

**Update phases**:
1. **Check**: Shallow clone of upstream repo to `/tmp` — compares versions
2. **Report**: Shows modified, added, and deleted files. Asks for confirmation (`yes` / `no` / `show diffs`)
3. **Apply**: Updates system files only — skills, hooks, references, context. Never touches `memory/`
4. **Post-update**: Creates new memory file types if introduced by the update, reinstalls hooks, commits

**Use cases**:
- After seeing a new PMM version announced
- When a new skill or file type is available and you want it
- Periodic maintenance — run `pmm:update` monthly to stay current

**Example**:
```
pmm:update
```

**Behaviour notes**:
- Semantic migration: some versions include migration instructions (e.g., "v2.1 adds `taxonomies.md`, run `pmm:hydrate` after update"). These are shown during the report phase and applied automatically in post-update.

---

## Patterns and anti-patterns

### Patterns (do this)

**Save at milestones, not on a timer**
The default cadence (`every-milestone`) is deliberate. Save after a decision is made, a feature ships, a lesson is learned. Timer-based saves capture noise — milestone saves capture signal. If you want periodic saves, `pmm:save` in a loop works, but milestones produce better memory.

**Hydrate before you maintain**
When you activate a new file (`voices.md`, `graph.md`), run `pmm:hydrate <file>` before the next `pmm:save`. An empty file that gets maintained stays shallow — the maintain agent has nothing to build on. Hydrate gives it a running start from everything the system already knows.

**Let the tiers work**
Tier 1 files (12 core files) auto-load at session start. Tier 2 files (graph, vectors, taxonomies, assets) load on demand when a query needs them. This saves ~14k tokens per session. Don't switch to all-in-context unless you have a specific reason — the tiered system is designed for the way developers actually use memory.

**Use query filters to find, not grep**
`pmm:query` understands attribution (`by user:raffi`), dates (`since 2026-03-15`), file scope (`in decisions`), and deep traversal (`deep`). It's not just text search — it follows relationships through the graph and finds semantically related content through vector clusters. Use it instead of grepping memory files manually.

**Commit auto, push manual**
The default (auto-commit, no auto-push) is intentional. Every save creates a git commit — that's your audit trail. But pushing is your choice. Keep memory local until you're ready to share it. If you want auto-push, `pmm:settings` lets you enable it.

**Check status when something feels off**
`pmm:status` is your diagnostic tool. If Claude seems to have forgotten something, run status first: maybe `last.md` is stale, maybe a file is still template-only, maybe the last save was hours ago. Status shows you what the system actually did, not what you assumed it did.

**Use `pmm:save` before `/compact`**
`/compact` compresses your conversation context. If you compact without saving first, structured memory (decisions, lessons, timeline) may not be captured. Always `pmm:save` first, then `/compact`. PMM captures the structured truth; compact produces the thin summary.

### Anti-patterns (don't do this)

**Don't save after every message**
`every-N-messages` with N=1 creates noise. The maintain agent runs on every save — that's token cost and git commits full of trivial changes. Save when something meaningful happens, not when something was said.

**Don't skip hydration on new files**
Activating a file via `pmm:settings` creates it from a template. If you immediately run `pmm:save`, the maintain agent sees an empty file and writes a thin entry. Run `pmm:hydrate <file>` first — it reads all existing memory and synthesizes a rich starting point.

**Don't use opus for maintenance**
The maintain agent does mechanical work: read files, append entries, replace sections. Haiku handles this at ~10x less cost than opus. Save opus for reasoning tasks. The default (haiku) is the right default.

**Don't manually edit memory files during a session**
PMM's maintain agent reads and writes memory files. If you edit them manually in the same session, the next `pmm:save` may overwrite your changes or create conflicts. Let the system manage its own files. If you need to correct something, use `pmm:save` with a note: `pmm:save corrected the decision about X`.

**Don't ignore template-only warnings**
`pmm:status` flags template-only files. These are active files with no real content — they exist but contribute nothing. Either hydrate them (`pmm:hydrate <file>`) or deactivate them (`pmm:settings`) so they stop cluttering your status.

**Don't treat memory as documentation**
Memory files track what happened, not what should happen. `decisions.md` records decisions that were made. `processes.md` records workflows that were established. They're not specs or roadmaps — they're the audit trail of your project's evolution. Write docs separately; let PMM track the decisions behind them.

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

## License

MIT. Built by [NominexHQ](https://github.com/NominexHQ).
