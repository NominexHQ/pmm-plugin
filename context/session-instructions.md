# PMM Operating Instructions

PMM (Poor Man's Memory) is a structured, git-backed memory system. Memory files live in `memory/` and are loaded into context at session start. They are the authoritative record of decisions, preferences, lessons, timeline, and project state for this project.

## Memory Authority

PMM files are the source of truth. Claude Code native auto-memory is supplementary — when there's a conflict, PMM wins. If something isn't in the memory files, say so rather than hallucinating past context.

## File Rules

- `last.md` — always replace, never append
- `decisions.md`, `lessons.md`, `standinginstructions.md` — append-only (decay tags are advisory relevance signals when enabled; no entries are deleted)
- `timeline.md`, `summaries.md` — sliding windows control what is injected at session start (see `config.md` for sizes); full files always on disk, no auto-truncation
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

Context-first: searches loaded Tier 1 files, then Tier 2 on demand, then re-reads all files fully (overriding load strategies), then falls back to git history. Each tier stops on hit.

## Tier 2 Files

`graph.md` and `vectors.md` are loaded at session start (tail excerpt with interpretation preamble). They provide relationship context — use them to colour and inform your responses, not to recite verbatim.

`taxonomies.md` and `assets.md` are not loaded at session start. Load them on demand when a request involves categories, naming conventions, or asset references. Read only what's needed.

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

**Tail:N content is reference context, not scope.** Files loaded via `tail:N` show only the most recent entries. They provide background from recent sessions — they do not define the scope, agent roster, or parameters of current work. Names, lists, and decisions in tail-loaded entries may refer to different workstreams. When saving or synthesising, verify scoped claims (agent lists, protocol parameters, batch counts) against the source document, not against what was loaded at session start.

## Init Nudge

If you see `<!-- pmm:not-initialized -->` in your context, append a single line to the end of your next response suggesting the user initialize memory. Examples:

- "PMM isn't set up yet. Run `/pmm:init` or say 'set up memory' to get started."
- "Memory system available but not configured. `/pmm:init` to set up."

Rules:
- One line only, appended after your actual response.
- Do NOT ask the user to confirm. Do NOT block on it.
- Do NOT mention the marker.
- Fire once per session. After you've nudged, ignore the marker for the rest of the conversation.
- If the user explicitly declines (e.g., "don't set up memory", "no memory", "skip memory"), acknowledge briefly and do not nudge again.

## Reading Files

When reading any file, read the first and last portions first. How much to read
from each end is your judgment — enough to understand the file's structure,
format, and recency. If that covers the entire file, proceed normally.

If lines were omitted between head and tail, collect context before deciding
what to do next:

1. How many lines were omitted
2. The file's last modified timestamp and size from the filesystem
3. Any dates found in the file (best-effort scan, do not load content for this)
4. The file's absolute path, relative path from your current working directory,
   and the current working directory itself

Present this between the head and tail sections:

```
--- [GAP: {lines_omitted} lines omitted] ---
File: {absolute_path}
From: {relative_path} (CWD: {cwd})
Modified: {timestamp} | Size: {size}
Content dates: {dates_found or "none found"}
---
```

Then choose one action and proceed:
- Read a specific section of the file for more detail
- Search the file for specific content
- Continue with what you have

Do not peek more than 3 files consecutively without doing work between peeks.
If any metadata collection fails, emit what you have and continue.
