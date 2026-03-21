---
name: pmm:dump
description: "Dump PMM memory state as ASCII art in the terminal. Three depth levels: status (heatmap only), summary (heatmap + clusters + timeline), detailed (full ASCII). Runs as a subagent. Use when the user runs /pmm:dump or asks for a text-based memory overview."
argument-hint: "[status|summary|detailed]"
---

# PMM Dump

Render PMM memory state as inline ASCII visualizations. Runs as a subagent to keep the main context clean.

**Depth level:** $ARGUMENTS (default: `status` if empty or not provided)

## Invocation

- `/pmm:dump` or `/pmm:dump status` — heatmap only (status level)
- `/pmm:dump summary` — heatmap + cluster list + last 5 timeline entries
- `/pmm:dump detailed` — full ASCII: graph map + heatmap + similarity matrix + clusters

## Behaviour

Dispatch a `general-purpose` agent using the `Readonly Agent Model` from `memory/config.md` (default: `haiku`) with the prompt below. Replace `<level>` with the depth level (`status`, `summary`, or `detailed`). Replace `<project-root>` with the actual project root path.

Output the agent's returned string verbatim — it contains the fully formatted ASCII visualization.

### Agent Prompt

> Render PMM memory state as ASCII visualizations. This is a READ-ONLY task — do not edit any files. You may run git commands for timestamps.
>
> **Project root:** `<project-root>`
> **Depth level:** `<level>`
>
> ### Depth Levels
>
> - `status` — Heatmap only
> - `summary` — Heatmap + cluster list + last 5 timeline entries
> - `detailed` — Full ASCII: graph map + heatmap + similarity matrix + clusters
>
> ### Visualization 1: Heatmap — File Activity (all levels)
>
> 1. Read `<project-root>/memory/config.md` to get the list of active files
> 2. For each active file, run: `git log -1 --format="%ar|%at" -- memory/<filename>`
> 3. Map the unix timestamp to a heat level:
>    - `████` = modified < 5 minutes ago
>    - `███░` = modified < 30 minutes ago
>    - `██░░` = modified < 2 hours ago
>    - `█░░░` = modified < 24 hours ago
>    - `░░░░` = modified > 24 hours ago or never
> 4. Check if file is empty/template-only (only has comments and headers, no real content)
> 5. Sort by recency (most recent first)
> 6. Render as aligned table with legend
>
> ### Token Burn Estimate (all levels)
>
> After the heatmap, show a token burn estimate:
>
> 1. Count total characters across all `.md` files in `memory/`: `cat memory/*.md | wc -c`
> 2. Estimate read tokens: `total_chars / 4`
> 3. Get last memory diff stats: `git diff HEAD~1 --stat -- memory/ | tail -1` (extract insertions + deletions)
> 4. Estimate write tokens: `(insertions + deletions) * 20 / 4`
> 5. Render:
> ```
> Token Burn (per save)
>   Read:  ~12,400 tok    Write: ~850 tok    Total: ~13,250 tok
> ```
>
> Use compact single-line format for dump. Round to nearest 50. Comma-separate thousands.
>
> ### Visualization 2: Clusters + Timeline (summary and detailed only)
>
> If level is `summary`:
> 1. Read `<project-root>/memory/vectors.md`
> 2. Parse cluster lines: `Cluster: name → [members] | theme: ...`
> 3. Render cluster names with member count
> 4. Read `<project-root>/memory/timeline.md`
> 5. Show last 5 timeline entries
>
> ### Visualization 3: Graph Map (detailed only)
>
> If level is `detailed`:
> 1. Read `<project-root>/memory/graph.md`
> 2. Parse all `[[A]] → relationship → [[B]]` lines
> 3. Group edges by `##` section headers
> 4. Render each group as an ASCII subgraph:
>    - Nodes boxed: `┌──────┐ │ name │ └──────┘`
>    - Edges: `───relationship──▶`
>    - Group under section name
>    - If >15 edges, show top-level structure only (collapse leaf nodes)
>    - If empty/template: "No relationships recorded yet."
>
> ### Visualization 4: Similarity Matrix (detailed only)
>
> If level is `detailed`:
> 1. Read `<project-root>/memory/vectors.md`
> 2. Parse similarity lines: `[[A]] ↔ [[B]] | score: X.XX | basis: ...`
> 3. Parse cluster lines: `Cluster: name → [members] | theme: ...`
> 4. Build sparse similarity matrix
> 5. Render as aligned ASCII table (abbreviate names to 6 chars, `·` for no data)
> 6. Render clusters as tree with `┌├└` chars
>
> ### Output Format
>
> Return the fully formatted ASCII output. Keep it compact. No preamble — start directly with the visualization.

## Notes

- The agent does all file reads and git commands — main context stays clean
- Output the agent's return value verbatim (it's the formatted ASCII visualization)
