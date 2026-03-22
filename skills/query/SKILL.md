---
name: pmm:query
description: Query memory — context-first recall with deep traversal across vectors, graph, and taxonomy when needed.
argument-hint: <question or search term>
---

# pmm:query

Explicit memory recall. Context-first — answers from already-loaded files before any agent dispatch. Supports free-text questions, attribution filters, date ranges, file scoping, deep traversal, and prose or dump output.

**Query:** $ARGUMENTS

If `$ARGUMENTS` is empty, ask the user what to search for before proceeding.

---

## Routing Table

Map question type to target file(s):

| Question type | Target file(s) |
|---|---|
| Decisions / decided / ratified | `decisions.md` |
| Preferences / style / how user works | `preferences.md` |
| Tone / voice / reasoning / lens | `voices.md` |
| Recent work / latest / just shipped | `last.md`, `progress.md` |
| Relationships / how things connect | `graph.md`, `vectors.md` |
| History / arc / timeline | `timeline.md` |
| Rules / directives / standing instructions | `standinginstructions.md` |
| People / tools / systems | `assets.md` |
| Facts / long-term / background | `memory.md` |
| Processes / workflows | `processes.md` |
| Mistakes / lessons / errors | `lessons.md` |
| Categories / naming / taxonomy | `taxonomies.md` |
| Ambiguous / broad | all active files |

---

## Execution

### Step 1 — Parse Query

Extract from `$ARGUMENTS`:

- **Keyword / question** — everything that is not a filter or modifier
- **Attribution filter** — `by namespace:name` (e.g. `by user:raffi`, `by agent:leith`)
- **Date filter** — `since YYYY-MM-DD` or `before YYYY-MM-DD`
- **File scope** — `in <filename>` (e.g. `in decisions`, `in lessons`) — search only that file
- **Deep flag** — presence of the word `deep` → set deep=true, remove from keyword
- **Dump flag** — presence of the word `dump` → set dump=true, remove from keyword

### Step 2 — Context-First Routing

**Read `memory/config.md` for `Session Start` mode.**

**If `Mode: lazy`** — memory files are already in context (injected by the SessionStart hook). Execute Steps 3–6 directly in the main context window without dispatching any agent. Tier 1 files are in-context. For Tier 2 files (graph.md, vectors.md, taxonomies.md, assets.md), use the Read tool to load the relevant file before searching — do not load all four, only what the routing table requires.

**If `Mode: eager`** — fall through to Agent Dispatch at the end of this document.

### Step 3 — Search

For each target file (respecting routing table and any `in <file>` scope):

1. Check or Read the file (Tier 1 = already in context; Tier 2 = Read on demand)
2. Match entries containing the keyword (case-insensitive)
3. Apply attribution filter: only include entries where the line or nearby heading contains `[namespace:name]` matching the filter
4. Apply date filter: only include entries whose date prefix (`YYYY-MM-DD`) satisfies `≥ since` or `≤ before`
5. Collect all matches with their source file

Read `memory/config.md` to confirm which files are active. Skip deactivated files.

### Step 4 — Deep Traversal

**Skip if deep=false.**

Expand the result set using similarity, graph, and taxonomy data. Run regardless of whether Step 3 found results.

**4a — Vector cluster expansion (`vectors.md`):**
1. Read (or use in-context) `vectors.md`
2. Find clusters whose name or member list contains the keyword
3. Collect all member concepts from matched clusters
4. Find similarity lines (`[[A]] ↔ [[B]] | score: ...`) where A or B matches — collect the paired concept if score ≥ 0.6
5. Search all active files for each expanded concept. Tag new matches `[via vectors]`

**4b — Graph edge traversal (`graph.md`):**
1. Read (or use in-context) `graph.md`
2. Find edges where the keyword appears in either node (`[[keyword]]`)
3. Collect neighbour nodes (one hop only)
4. Search all active files for each neighbour. Tag new matches `[via graph]`

**4c — Taxonomy broadening (`taxonomies.md`):**
1. Read (or use in-context) `taxonomies.md`
2. Find categories or classifications containing the keyword
3. Collect sibling terms in those categories
4. Search all active files for each sibling. Tag new matches `[via taxonomy]`

Deduplicate — results already found in Step 3 should not be listed again.

### Step 5 — Beyond-Window Gate

**Only if Steps 3 and 4 together returned no results.**

Check `memory/config.md` for `## Recall Beyond Window` → `Mode`:

**If `Mode: prompt`** — present `AskUserQuestion` with three options:

- **Yes, search git history** — dispatch a minimal git-history agent (no file reads; memory is in context):
  ```
  Run: git log --all --grep="<keyword>" --oneline
  For each matching commit: git show <hash> -- memory/
  Return the relevant lines and which commit they came from.
  ```
  Use the `Readonly Agent Model` from config (default: `haiku`). Incorporate results into Step 7 output tagged `(from git history, commit <hash>)`.

- **Yes, and don't ask me again** — same dispatch, then update `memory/config.md`: replace `- Mode: prompt` under `## Recall Beyond Window` with `- Mode: auto`

- **No** — return: `No record found in the current memory window.`

**If `Mode: auto`** — silently dispatch the minimal git-history agent (no file reads; same prompt as above).

### Step 6 — Cross-Reference Enrichment

**Skip if deep=true** (graph.md was already traversed in Step 4b).

Otherwise: if results mention a named entity (person, tool, system, concept) that also appears in `graph.md` or `assets.md`:
- Read those files if not already in context
- Append a `Related context:` note (1–2 lines) if it genuinely enriches the result
- Do not bloat — only include if it adds something the main results don't already say

### Step 7 — Format Output

**Branch A — Prose mode (default, dump=false):**

Synthesize a narrative answer from all collected results.

Rules:
- Write in concise, direct prose — answer the question, don't describe what files say
- Weave evidence from multiple source files into a coherent response
- Cite sources inline as parentheticals: `(decisions.md)`, `(timeline.md, 2026-03-17)`
- Preserve attribution tags inline where relevant: `[user:raffi]`
- For deep-mode results, note provenance naturally: "A related concept, X (via graph), also shows..."
- For git history results: "(from git history, commit abc1234)"
- End with a single `Sources:` footer line listing all files that contributed
- If no results after all fallbacks: `No record found in the memory files.`
- No header block, no match counts — start directly with the narrative

```
<synthesized narrative answering the user's question, citing sources inline>

Sources: decisions.md, timeline.md, graph.md
```

**Branch B — Dump mode (dump=true):**

```
PMM Query Results
=================
Query: <original query>
Filters: <attribution filter> | <date filter> | <file scope> (or "none" if no filters)
Mode: <deep+dump | dump>
Found: N result(s) in M file(s)

--- <filename>.md ---
<verbatim matching entry, including attribution tag if present>

--- <filename>.md [via vectors] ---
<entry found through vector cluster/similarity expansion>

--- <filename>.md [via graph] ---
<entry found through graph edge traversal>

--- <filename>.md [via taxonomy] ---
<entry found through taxonomy broadening>

[Related context]
<brief enrichment from graph.md/assets.md, if applicable>
```

- Group results by source file
- Show the full entry (heading + body), not just the matching line
- Preserve attribution tags verbatim
- Tag deep traversal results with provenance
- Git history fallback: `--- git history (commit abc1234) ---`
- If no results: `No record found in the memory files.`
- No preamble — start directly with `PMM Query Results`

---

## Agent Dispatch (eager mode)

**Used only when `Mode: eager`.**

Dispatch a `general-purpose` agent using the `Readonly Agent Model` from `memory/config.md` (default: `haiku`). Replace `<project-root>` with the actual project root path and `<user-query>` with `$ARGUMENTS`.

> Query PMM memory files. This is a READ-ONLY task — do not edit any files.
>
> **Project root:** `<project-root>`
> **User query:** `<user-query>`
>
> ### Step 1 — Parse Query
>
> Extract from the user query:
> - **Keyword / question** — core search term
> - **Attribution filter** — `by namespace:name`
> - **Date filter** — `since YYYY-MM-DD` or `before YYYY-MM-DD`
> - **File scope** — `in <filename>`
> - **Deep flag** — word `deep` present
> - **Dump flag** — word `dump` present
>
> ### Step 2 — Route to Relevant Files
>
> If file scope is set, search only that file. Otherwise use the routing table:
> - Decisions / ratified → `decisions.md`
> - Preferences / style → `preferences.md`
> - Tone / voice / lens → `voices.md`
> - Recent work / latest → `last.md`, `progress.md`
> - Relationships → `graph.md`, `vectors.md`
> - History / timeline → `timeline.md`
> - Rules / standing → `standinginstructions.md`
> - People / tools → `assets.md`
> - Facts / background → `memory.md`
> - Processes / workflows → `processes.md`
> - Mistakes / lessons → `lessons.md`
> - Categories / naming → `taxonomies.md`
> - Ambiguous / broad → all active files
>
> Read `<project-root>/memory/config.md` to confirm active files. Skip deactivated files.
>
> ### Step 3 — Search
>
> For each target file:
> 1. Read the file
> 2. Match entries containing the keyword (case-insensitive)
> 3. Apply attribution filter if set
> 4. Apply date filter if set
> 5. Collect matches with source file noted
>
> ### Step 4 — Deep Traversal (deep=true only)
>
> **4a — vectors.md:** Find clusters/similarities containing keyword (score ≥ 0.6). Tag results `[via vectors]`.
>
> **4b — graph.md:** Find edges containing keyword, collect one-hop neighbours. Tag results `[via graph]`.
>
> **4c — taxonomies.md:** Find categories containing keyword, collect siblings. Tag results `[via taxonomy]`.
>
> Deduplicate against Step 3 results.
>
> ### Step 5 — Fallback Chain
>
> If Steps 3+4 return no results:
> 1. Check `timeline.md` and `last.md`
> 2. Run: `git log --all --grep="<keyword>" --oneline`
> 3. For matching commits: `git show <hash> -- memory/` — extract relevant lines
> 4. If still nothing: return `No record found in the memory files.`
>
> Never hallucinate past context.
>
> ### Step 6 — Cross-Reference Enrichment
>
> Skip if deep=true. Otherwise: if results mention a named entity in `graph.md` or `assets.md`, append a brief `Related context:` note (1–2 lines max) if it adds meaningful information.
>
> ### Step 7 — Format Output
>
> Prose mode (dump=false): synthesized narrative with inline citations and `Sources:` footer.
>
> Dump mode (dump=true): structured `PMM Query Results` block with verbatim entries grouped by file, provenance tags on deep-traversal results.
>
> Return the formatted output as a string. Do not write to any file.

Output the agent's return value verbatim.

---

## Notes

- Context-first path is the default when `session_start: lazy` (hook-loaded sessions). This eliminates agent dispatch for in-window queries.
- Agent dispatch is the fallback for eager mode or unwired sessions — file reads happen inside the agent.
- Phase 4 Recall in the main session handles implicit recall mid-conversation. This skill is the explicit, filterable version.
- Model selection follows `Readonly Agent Model` in `memory/config.md` (default: `haiku`). No reasoning required for read-only traversal.
- Attribution tags (`[user:name]`, `[agent:name]`, `[system:process]`) identify who originated each piece of information. Always preserve and surface them.
- For the full memory file reference, see `references/core.md`.
