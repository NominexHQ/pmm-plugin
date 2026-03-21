---
name: pmm:viz
description: "Interactive D3.js memory graph visualization with time slider. Parses all memory files across git history, builds a force-directed graph with temporal navigation, and opens it in the browser. Runs as a subagent. Use when the user runs /pmm:viz or asks to visualize their memory as an interactive graph."
argument-hint: "[graph|clusters|timeline]"
---

# PMM Viz — Interactive Memory Graph

Generates an interactive D3.js force-directed graph from all memory files and opens it in the browser. Includes a time slider that lets you scrub through git history to watch the graph evolve. Runs entirely as a subagent to keep the main context clean.

**Scope:** $ARGUMENTS (default: `full` if empty or not provided — shows everything)

## Invocation

- `/pmm:viz` — full graph (all memory files)
- `/pmm:viz graph` — relationships from graph.md only
- `/pmm:viz clusters` — cluster members + similarity edges only
- `/pmm:viz timeline` — event nodes + decision nodes + temporal edges

## Behaviour

When invoked, dispatch a `general-purpose` agent using the `Readonly Agent Model` from `memory/config.md` (default: `haiku`) with the prompt below. Replace `<scope>` with the subcommand (`full`, `graph`, `clusters`, or `timeline`). Replace `<project-root>` with the actual project root path.

### Agent Prompt

> Generate an interactive PMM memory graph with time-travel support. This is a READ + WRITE task. You may run git read-only commands (rev-parse, log, show). Do NOT run git write commands.
>
> **Scope:** `<scope>`
>
> ### Step 1 — Cache Check
>
> Run: `git rev-parse HEAD:memory 2>/dev/null`
>
> If the file `<project-root>/pmm/viz-cache.html` exists, read its first line. It should contain `<!-- pmm-cache: HASH SCOPE -->`. If both the hash and scope match, just run `open <project-root>/pmm/viz-cache.html` and return "Opened cached visualization."
>
> ### Step 2 — Read All Memory Files (HEAD)
>
> Read every `.md` file in `<project-root>/memory/`. The full list:
> - graph.md, vectors.md, assets.md, timeline.md, decisions.md, processes.md
> - lessons.md, memory.md, config.md, standinginstructions.md, preferences.md, voices.md
> - progress.md, last.md, summaries.md, taxonomies.md
>
> Skip files that don't exist or are empty.
>
> ### Step 2.5 — Reconstruct History
>
> Build temporal data so the time slider can show how the graph evolved over git commits.
>
> 1. Run: `git log --format="%H %at %s" -- memory/` to get all commits that touched `memory/`.
> 2. Sort oldest-first. If there are more than 100 commits, sample: take every Nth commit to reduce to ~50, always keeping the first and last commits.
> 3. For each commit hash, extract node IDs and edge keys using a **lightweight parse**:
>    - Run `git show <hash>:memory/graph.md 2>/dev/null` and extract all `[[...]]` names and edge lines (`[[A]] → rel → [[B]]`)
>    - Run `git show <hash>:memory/vectors.md 2>/dev/null` and extract `[[...]]` names from similarity/cluster lines
>    - Run `git show <hash>:memory/assets.md 2>/dev/null` and extract first-column entries from People/Tools/Organisations tables
>    - Run `git show <hash>:memory/decisions.md 2>/dev/null` and extract `##` headings or list items
>    - Run `git show <hash>:memory/processes.md 2>/dev/null` and extract `##` headings
>    - Run `git show <hash>:memory/timeline.md 2>/dev/null` and extract event entries
>    - Run `git show <hash>:memory/lessons.md 2>/dev/null` and extract lesson entries
>    - Run `git show <hash>:memory/standinginstructions.md 2>/dev/null` and extract instruction entries
>    - Ignore errors (file may not exist at early commits)
>    - You do NOT need full metadata from historical commits — just the set of node IDs and edge keys present at each commit
> 4. For each node: `firstSeen` = timestamp of earliest commit where the node ID appeared. `lastSeen` = timestamp of latest commit where the node ID appeared.
> 5. For each edge: same logic. Edge key = `source|target|label` for stable identity across commits.
> 6. Build a `timeline` array (oldest-first):
>    ```json
>    [{"hash": "abc123", "timestamp": 1773650133, "message": "memory: initialise", "nodeCount": 5, "edgeCount": 3}]
>    ```
>    Where `nodeCount` and `edgeCount` are the counts at that specific commit.
>
> **Performance note:** Process commits in batches. For each commit, run multiple `git show` commands in a single bash call where possible (e.g. separated by `; echo "---SEPARATOR---"; `). Only extract what's needed — node IDs and edge keys — not full content.
>
> ### Step 3 — Parse Nodes and Edges (HEAD)
>
> Parse each file using these rules:
>
> **graph.md:**
> - Lines matching `[[A]] → relationship → [[B]]` become directed edges
> - `##` headings become edge sections (store in edge `section` field)
> - Both A and B become nodes
>
> **vectors.md:**
> - Lines matching `[[A]] ↔ [[B]] | score: X.XX | basis: ...` become similarity edges (undirected, type=similarity, weight=score)
> - Lines matching `Cluster: name → [[[A]], [[B]], ...] | theme: ...` define clusters
> - Cluster members become nodes
>
> **assets.md:**
> - Parse markdown tables under People, Tools, Organisations headings
> - First column entries become nodes
> - People → type=person, Tools → type=tool, Organisations → type=tool
>
> **timeline.md:**
> - Lines matching `**[Date]** — [Event description]` → Event nodes (type=event, label=description)
>
> **decisions.md:**
> - Each decision entry (## heading or list item with decision text) → Concept node (type=concept)
>
> **processes.md:**
> - Each `##` heading → Process node (type=process)
>
> **lessons.md:**
> - Each lesson entry → Concept node (type=concept)
>
> **standinginstructions.md:**
> - Each instruction entry → Concept node (type=concept)
>
> ### Step 4 — Assign Node Types (Priority Order)
>
> If a node name appears in multiple files, assign type by priority:
> 1. In assets.md People table → `person`
> 2. In assets.md Tools/Organisations table → `tool`
> 3. Ends in `.md` → `file`
> 4. In decisions.md → `concept`
> 5. In processes.md heading → `process`
> 6. From timeline.md → `event`
> 7. Otherwise → `concept`
>
> ### Step 5 — Deduplicate
>
> Deduplicate nodes by canonical name (the text inside `[[ ]]`, trimmed, case-preserved). Merge metadata from all sources.
>
> ### Step 6 — Apply Scope Filter
>
> - `full` → include everything
> - `graph` → only edges from graph.md, only nodes referenced by those edges
> - `clusters` → only cluster member nodes + similarity edges from vectors.md
> - `timeline` → only event nodes (from timeline.md) + concept nodes (from decisions.md) + any edges connecting them
>
> ### Step 7 — Build JSON
>
> Build a JSON object matching this schema:
> ```json
> {
>   "nodes": [{"id": "str", "type": "file|person|concept|tool|process|event", "label": "str", "metadata": {}, "clusters": [], "firstSeen": 1773650133, "lastSeen": 1773736182}],
>   "edges": [{"source": "str", "target": "str", "label": "str", "section": "str", "weight": 0.0, "type": "relationship|similarity", "firstSeen": 1773650133, "lastSeen": 1773736182}],
>   "clusters": [{"name": "str", "members": [], "theme": "str"}],
>   "timeline": [{"hash": "str", "timestamp": 0, "message": "str", "nodeCount": 0, "edgeCount": 0}],
>   "metadata": {"generated": "ISO date", "treeHash": "HASH", "scope": "<scope>", "nodeCount": 0, "edgeCount": 0}
> }
> ```
>
> Node `id` = canonical name. Edge `weight` defaults to 0.5 for relationship edges. Cluster `members` = array of node IDs. `firstSeen`/`lastSeen` are Unix timestamps from Step 2.5. If no history data is available (single commit or no history), omit `firstSeen`/`lastSeen` — the template handles missing values gracefully.
>
> ### Step 8 — Assemble HTML
>
> 1. Read the template: `<project-root>/pmm/pmm-viz-template.html`
> 2. Read D3.js: `<project-root>/pmm/d3.v7.min.js`
> 3. In the template:
>    - Replace `/*D3_PLACEHOLDER*/` with the full D3.js source code
>    - Replace `/*PMM_DATA_PLACEHOLDER*/{"nodes":[],"edges":[],"clusters":[],"timeline":[],"metadata":{}}/*END_PLACEHOLDER*/` with the actual JSON data
>    - Replace the first line `<!-- pmm-cache: HASH SCOPE -->` with `<!-- pmm-cache: <actual-hash> <scope> -->`
> 4. Write the assembled HTML to `<project-root>/pmm/viz-cache.html`
>
> ### Step 9 — Open
>
> Detect platform and open:
> - macOS: `open <project-root>/pmm/viz-cache.html`
> - Linux: `xdg-open <project-root>/pmm/viz-cache.html`
> - WSL: `wslview <project-root>/pmm/viz-cache.html` or `cmd.exe /c start <project-root>/pmm/viz-cache.html`
>
> Return a summary: "Generated PMM graph: X nodes, Y edges, Z commits in timeline. Opened in browser."

## Notes

- The template and D3.js live in `pmm/` at the project root (not in `.claude/`)
- `pmm/viz-cache.html` is gitignored — it's a generated artifact
- The agent reads ALL memory files regardless of config.md active list — the graph should be greedy
- If memory/ has no content (all files template-only), generate an empty graph with a message in the HTML
- The agent must not modify any memory files — read-only for memory/, write-only for pmm/viz-cache.html
- Git read permissions (rev-parse, log, show) are pre-approved in `.claude/settings.json`
- The time slider only appears when there are 2+ commits in the timeline — single-commit projects get the graph without the slider
- Clusters reflect HEAD state only — they don't change as you scrub the timeline
