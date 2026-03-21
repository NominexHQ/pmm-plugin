# PMM Core Reference

Shared knowledge base for all PMM plugin skills. A skill author reading only this file should understand the full PMM operating model.

---

## Memory File Inventory

| File | Tier | Purpose |
|------|------|---------|
| `config.md` | 1 | PMM configuration — controls all skill behaviour |
| `standinginstructions.md` | 1 | Persistent rules that always apply, append-only, take precedence over session instructions |
| `last.md` | 1 | Last 3–5 significant actions in detail — always replaced, never appended |
| `progress.md` | 1 | Current milestones, state, and what's next — living document |
| `decisions.md` | 1 | Committed decisions — append-only, newest at top, never delete or modify |
| `lessons.md` | 1 | Mistakes and lessons learned — append-only |
| `preferences.md` | 1 | User-specific quirks, style, working habits — living document |
| `memory.md` | 1 | Long-term facts about the project — living document |
| `summaries.md` | 1 | Periodic session/milestone rollups — sliding window (max 10) |
| `voices.md` | 1 | Tone profiles and internal reasoning patterns — living document |
| `processes.md` | 1 | Workflows and processes — living document |
| `timeline.md` | 1 | Compressed chronological record — sliding window (max configured) |
| `graph.md` | 2 | Typed edges between concepts, decisions, and entities — append-only edges |
| `vectors.md` | 2 | Semantic similarities, concept clusters, embedding registry — clusters are living, registry is append-only |
| `taxonomies.md` | 2 | Classification systems, categories, naming conventions — living document |
| `assets.md` | 2 | Key entities: people, tools, systems, organisations — living document |
| `BOOTSTRAP.md` | — | Master operating instructions — never edit without explicit user instruction |
| `secrets.md` | protected | Local-only credential store — gitignored, never read or written by maintain agents |

`config.md` and `BOOTSTRAP.md` are always active. All other files are configurable via `config.md`.

---

## Tier System

**Tier 1 — always loaded**
The 12 core files loaded into context at session start via direct `@-imports` in `CLAUDE.md`. Always available without a Read tool call. Covers everything needed for session orientation (decisions, lessons, preferences, recent work, standing instructions).

Note: `@-imports` do not recurse in Claude Code. All Tier 1 files must be listed as direct `@-imports` in `CLAUDE.md`, not inside `BOOTSTRAP.md`. Imports inside an imported file are never resolved.

**Tier 2 — on demand**
The 4 relational/reference files (`graph.md`, `vectors.md`, `taxonomies.md`, `assets.md`). Live on disk. Load via a haiku agent when a request signals a gap that Tier 2 data would fill. Do not load all four by default — only what the request requires.

Routing:
- Relationships → `graph.md`
- Semantic similarities / clusters → `vectors.md`
- Categories / naming conventions → `taxonomies.md`
- People / tools / systems → `assets.md`

**Tier 3 — registry-tracked only**
Custom files added via `pmm:memory`. Handling is user-specified. Tracked in `memory/registry.md` (VP-only, not a standard PMM file).

---

## Operating Rules

**Append-only files** — never delete or modify existing entries:
- `standinginstructions.md`
- `decisions.md`
- `lessons.md`
- `graph.md` edges (add new relationships, never remove)
- `vectors.md` embedding registry (similarities/clusters are living — update scores/membership)

**Replace on every save:**
- `last.md` — always replaced entirely with the last 3–5 significant actions. Never appended.

**Sliding windows** — oldest entries trimmed first, full history lives in git:
- `timeline.md` — max entries set by `Timeline max` in `config.md` (default: 50)
- `summaries.md` — max entries set by `Summaries max` in `config.md` (default: 10)
- When `timeline.md` entries are about to be trimmed, summarise the batch and append to `summaries.md` first

**Living documents** — update in place:
- `memory.md`, `preferences.md`, `voices.md`, `processes.md`, `progress.md`, `taxonomies.md`, `vectors.md` (clusters section), `assets.md`

**File discipline:**
- Never bleed content between files — each file has one job
- `BOOTSTRAP.md` is immutable unless explicitly instructed by the user
- `standinginstructions.md` takes precedence over session-level instructions when there is a conflict
- `secrets.md` is never read, written, or referenced by maintain agents — it exists outside the maintain scope
- `config.md` is read by agents but never modified by them (only by `pmm:settings`)

**Commit pattern** — always exclude `secrets.md`:
```bash
git add memory/ && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: <description>"
```

**Memory saves** — trigger on:
- End of every major milestone or decision
- New entity, process, or preference established
- Mistake made or lesson noted
- Before `/compact` operation
- Before session exit (user signals they are done)
- Explicit `/pmm-save` command

---

## Agent Permission Model

**Agents edit files only. Main context handles all git commands.**

Agents dispatched for memory operations (maintain, hydrate, session-start recall) have access to Read, Write, Edit, Glob, and Grep tools. They do not run git commands. If an agent cannot commit, it must signal the main context to handle git operations — never silently skip the commit.

Main context runs:
```bash
git add memory/ && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: <description>"
```

**Why:** Agent subprocesses may not have Bash tool permissions depending on project settings. Keeping git in main context ensures commits always happen and history is never lost. Agents as editors, main context as committer.

**Background agents (`run_in_background: true`) do not inherit Edit/Write tool permissions.** For agents that need to write files, dispatch as foreground agents. To achieve parallelism, dispatch multiple Agent tool calls in the same message without `run_in_background`.

**Model selection:**
- Maintain agent: `Maintain Agent Model` from `config.md` (default: `haiku`)
- Read-only agents (session-start, recall, query, dump): `Readonly Agent Model` from `config.md` (default: `haiku`)
- Pass the appropriate `model` parameter when dispatching any agent

---

## Config Schema

`memory/config.md` controls all PMM behaviour. Skills read it before operating. Agents read it but never modify it.

| Section | Field | Default | Controls |
|---------|-------|---------|---------|
| `## Save Cadence` | `Mode:` | `every-milestone` | When maintain triggers: `every-milestone`, `every-N-messages`, `on-request` |
| `## Commit Behaviour` | `Mode:` | `auto-commit` | When to commit: `auto-commit`, `session-end`, `manual` |
| `## Push Behaviour` | `Auto-push:` | `off` | Whether to push after commit: `on`, `off` |
| `## Sliding Window Size` | `Timeline max:` | `50` | Max entries in `timeline.md` before trimming |
| `## Sliding Window Size` | `Summaries max:` | `10` | Max entries in `summaries.md` before trimming |
| `## Verbosity` | `Mode:` | `summary` | How updates are communicated: `silent`, `summary`, `verbose` |
| `## Repository Visibility` | `Visibility:` | `public` | PII handling: `public` (handles only, no emails, no verbatim sensitive quotes), `private` (full fidelity) |
| `## Maintain Agent Model` | `Model:` | `haiku` | Model for maintain agents |
| `## Readonly Agent Model` | `Readonly model:` / `Model:` | `haiku` | Model for read-only agents (session-start, recall, query, dump) |
| `## Session Start` | `Mode:` | `lazy` | Session-start behaviour: `lazy` (skip agent if bootstrap_wired), `eager` (always dispatch) |
| `## Session Start` | `bootstrap_wired:` | `true` | Whether `@memory/BOOTSTRAP.md` is wired into `CLAUDE.md`; enables lazy skip |
| `## Maintain Strategy` | `Strategy:` | `single` | Dispatch strategy: `single` (one agent, all files) or `tiered` (three concurrent agents by dependency tier) |
| `## Recall Beyond Window` | `Mode:` | `prompt` | Whether to search git history for trimmed entries: `prompt` (ask first), `auto` (silent search) |
| `## Context Tiers` | `Mode:` | `tiered` | Loading mode: `tiered` (Tier 1 in CLAUDE.md, Tier 2 on demand) or `all-in-context` |
| `## Memory Priority` | `Mode:` | `pmm-first` | How PMM interacts with Claude auto-memory: `pmm-first`, `deduplicate`, `coexist` |
| `## Active Files` | `<file>: active/inactive` | all active | Which memory files are created and maintained |
| `## Protected Files` | `secrets.md: protected` | always | Marks `secrets.md` as gitignored/never-touch |
| `## Protected Files` | `bootstrap_wired:` | `true`/`false` | Cache flag for Bootstrap Check — skip CLAUDE.md reads once wired |
| `## Protected Files` | `bootstrap_reminder:` | `on`/`off` | Whether to surface missing-wiring prompts |

Skills must not modify `config.md` except for `pmm:settings` (which is the dedicated config management skill) and the bootstrap wiring cache write.

---

## Universal Rules

These apply across all PMM skill operations:

1. **Never hallucinate past context.** If it's not in the memory files, say so. Do not infer or fabricate history.

2. **Never bleed content between files.** Each file has one job. `decisions.md` is not `lessons.md`. `memory.md` is not `timeline.md`.

3. **Respect the active files list.** Only read, write, and reference files marked active in `config.md`. Skip deactivated files silently.

4. **`secrets.md` is out of scope.** Never read, write, reference, or echo its contents. If a secret value appears in conversation context, do not write it to any memory file.

5. **`standinginstructions.md` wins.** When there is a conflict between a standing instruction and a session-level instruction, the standing instruction takes precedence.

6. **Attribution tagging.** Tag entries with source actor using `[namespace:name]` format:
   - `[user:name]` — user explicitly stated or decided this
   - `[agent:name]` — agent inferred or synthesized this
   - `[system:process]` — generated by automated process
   - `[system:hydrate]` — populated by Phase 5 hydration
   Place the tag at the end of the entry header line. Applies to: `decisions.md`, `timeline.md`, `lessons.md`, `standinginstructions.md`, `last.md`. Omit if source is unclear — do not guess.

7. **PMM-first memory priority.** When `Memory Priority: pmm-first`, Claude auto-memory (in `.claude/projects/.../memory/`) stores only skill references and feedback — not facts, decisions, or timeline events that PMM already tracks. If storing a pointer, make it tier-aware: Tier 1 content is already in context; Tier 2 requires a Read tool call.

8. **PII handling follows repository visibility.** When `Visibility: public`: never write personal email addresses or phone numbers, use handles or first names only (not full legal names), write decision conclusions and rationale summaries — omit verbatim quotes of sensitive internal discussion. When `Visibility: private`: no restrictions. In either case: never write API keys, tokens, passwords, or credentials to any memory file (`secrets.md` only).

9. **Memory commits go directly to main.** Memory saves are an intentional exception to the project's PR workflow — automated memory saves cannot wait for review. All other code changes follow branch → PR → merge.

10. **`config.md` is read by agents, never written by them.** Only `pmm:settings` modifies config. Exception: the bootstrap wiring cache write (`bootstrap_wired: true`) may be set by any skill that performs a Bootstrap Check.
