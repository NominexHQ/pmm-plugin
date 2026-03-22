# PMM Operating Instructions

PMM (Poor Man's Memory) is a structured, git-backed memory system. Memory files live in `memory/` and are loaded into context at session start. They are the authoritative record of decisions, preferences, lessons, timeline, and project state for this project.

## Memory Authority

PMM files are the source of truth. Claude Code native auto-memory is supplementary — when there's a conflict, PMM wins. If something isn't in the memory files, say so rather than hallucinating past context.

## File Rules

- `last.md` — always replace, never append
- `decisions.md`, `lessons.md`, `standinginstructions.md`, `timeline.md` — append-only, never delete or modify existing entries
- `timeline.md`, `summaries.md` — sliding windows; trim oldest entries when at max (see `config.md` for sizes)
- Agents edit files only — main context handles all git commits

## When to Save

Check `config.md` for the configured save cadence mode.

**If `every-milestone` (default):** Run `pmm:save` proactively at natural milestones:
- A decision is made
- A new entity, process, or preference is established
- Significant work is completed
- A mistake is made or a lesson is learned
- Before `/compact`

**If `every-N` (stop hook configured):** The stop hook handles automatic saves at the configured threshold. `pmm:save` is still available for explicit saves at any time.

**Before ending the session:** Run `pmm:save` before saying goodbye or closing the conversation. This is a soft instruction — best-effort, not hook-enforced, but important.

**Before `/compact`:** Run `pmm:save` first to capture structured memory before compression. Compact produces a thin summary; PMM captures the structured truth. Run PMM first.

## How to Save

```
pmm:save
```

Dispatches a maintain agent (haiku by default). The agent updates the appropriate memory files. Main context commits to git afterward:

```bash
git add memory/ && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: <what changed>"
```

## How to Query

```
pmm:query [question]
```

Context-first: answers from already-loaded Tier 1 files before dispatching agents. Only falls back to git history search if the answer isn't in loaded context, gated behind `recall_beyond_window` config.

## Tier 2 Files

`graph.md`, `vectors.md`, `taxonomies.md`, `assets.md` are not loaded at session start. Load them on demand when a request involves relationships, semantic clusters, categories, or asset references. Read only what's needed.

If `memory/secrets.md` exists, credentials are available there. Do not echo or summarise its contents.

## Load Strategies

The `## Active Files` section of `config.md` supports an optional load strategy column:

```
- timeline.md: active | tail:5
- decisions.md: active | tail:10
- memory.md: active | full
```

Valid strategies:
- `full` — load the entire file (default when omitted)
- `tail:N` — load only the last N entries (useful for append-only sliding-window files)
- `header` — load only the file header/frontmatter
- `skip` — do not load this file at session start (activate for maintain only)

Sliding-window files (`timeline.md`, `decisions.md`, `lessons.md`) benefit from `tail:N` to keep session-start context lean. Use `pmm:recall` to load full files on demand regardless of the session-start strategy.
