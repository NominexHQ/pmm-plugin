---
name: pmm:status
description: "Quick PMM health dashboard. Shows initialization state, last save time, recent commits, file health, and warnings. Runs as a subagent. Use when the user runs /pmm:status or asks if memory is saving, working, or healthy."
argument-hint: ""
---

# PMM Status

Quick health dashboard for Poor Man's Memory. Runs as a subagent to keep the main context clean.

## Invocation

- `/pmm:status` — show full status dashboard

## Behaviour

Dispatch a `general-purpose` agent using the `Readonly Agent Model` from `memory/config.md` (default: `haiku`) with the prompt below. Replace `<project-root>` with the actual project root path.

Output the agent's returned string verbatim — it contains the fully formatted dashboard.

### Agent Prompt

> Generate a PMM health dashboard. This is a READ-ONLY task — do not edit any files.
>
> **Project root:** `<project-root>`
>
> ### Step 1 — Check initialization
>
> Check if `<project-root>/memory/` directory exists and count `.md` files.
>
> If no memory directory exists, return:
> ```
> PMM Status
> ══════════
>
> Initialized: No
> Run "init memory" to get started.
> ```
>
> ### Step 2 — Read config
>
> Read `<project-root>/memory/config.md` to get:
> - Save cadence (the Mode value under `## Save Cadence`)
> - Commit behaviour (the Mode value under `## Commit Behaviour`)
> - Maintain agent model (the Model value under `## Maintain Agent Model`)
>
> ### Step 3 — Get last save time
>
> Run: `git log -1 --format="%ar|%ai" -- memory/`
>
> ### Step 4 — Get recent memory commits
>
> Run: `git log --oneline -5 -- memory/`
>
> ### Step 5 — Build file health table
>
> For each `.md` file in `<project-root>/memory/`:
>
> 1. Get last modified time: `git log -1 --format="%ar" -- memory/<file>`
> 2. Count lines: `wc -l < memory/<file>`
> 3. Determine status:
>    - **Template-only detection:** Read the file. Strip blank lines, lines starting with `#`, lines that are only `---`, HTML comments (`<!-- ... -->`), table header rows (`| --- |`), and introductory/description text (first paragraph after a heading that describes the file's purpose). If 0 content lines remain → `⚠ template-only`.
>    - Otherwise → `✓ populated`
>
> Sort by last modified (most recent first).
>
> ### Step 6 — Token burn estimate
>
> Estimate the token cost of PMM operations:
>
> **Read cost (per save cycle):** The maintain agent reads all active memory files.
> - Count total characters across all `.md` files in `memory/`: `cat memory/*.md | wc -c`
> - Estimate tokens: `total_chars / 4` (rough average for English markdown)
> - This is the input token cost each time the maintain agent runs
>
> **Write cost (per save cycle):** The maintain agent edits files.
> - Get the size of the last memory commit's diff: `git diff HEAD~1 --stat -- memory/ | tail -1` (extract insertions + deletions)
> - If no prior commit, use 0
> - Estimate tokens: `(insertions + deletions) * 20` chars average per line / 4 chars per token
> - This is the approximate output token cost per save
>
> **Format as:**
> ```
> Token Burn (per save)
>   Read:   ~12,400 tokens (memory files loaded by maintain agent)
>   Write:  ~850 tokens (estimated from last diff: +34 -8 lines)
>   Total:  ~13,250 tokens/save
> ```
>
> Use comma-separated numbers for readability. Round to nearest 50.
>
> ### Step 7 — Generate warnings
>
> Check for:
> - **Plugin not installed:** Check if `.claude/plugins/pmm/` exists in `<project-root>`. If it does not, add warning: `⚠ PMM plugin not detected — memory may not be auto-loaded at session start. Install the pmm plugin to enable SessionStart hook.`
> - **Template-only active files:** Any active file (per config.md) that is still template-only
> - **Stale files:** Any file not modified in >7 days (only warn if project has commits in the last 7 days)
> - **Stale last.md:** `last.md` not updated in the current session (last modified >2 hours ago)
> - **Large files:** Any file >200 lines (note size; no auto-truncation — files grow without limit by design)
>
> ### Step 8 — Format output
>
> Return the fully formatted dashboard:
>
> ```
> PMM Status
> ══════════
>
> Initialized: Yes (17 files)
> Last save:   2 minutes ago (2026-03-17 16:30:00)
> Save cadence: every-milestone
> Commit mode:  auto-commit
>
> Recent Saves
>   e6714a5  memory: major reconstruction from recovered transcripts
>   495ae34  memory: update session 2026-03-17
>   ...
>
> Files                        Last Modified    Lines  Status
>   config.md                  2 min ago          58   ✓ populated
>   taxonomies.md              3 hr ago           12   ⚠ template-only
>   ...
>
> Total: 847 lines across 17 files
>
> Token Burn (per save)
>   Read:   ~12,400 tokens (memory files loaded by maintain agent)
>   Write:  ~850 tokens (estimated from last diff: +34 -8 lines)
>   Total:  ~13,250 tokens/save
>
> Warnings
>   ⚠ taxonomies.md is still template-only
>   ⚠ last.md has not been updated this session
> ```
>
> If there are no warnings, show "No warnings" instead of the Warnings section.
> All times should be human-readable ("2 min ago", "3 hr ago").
> Keep the output compact and scannable.

## Notes

- The agent does all file reads and git commands — main context stays clean
- Output the agent's return value verbatim (it's the formatted dashboard)
- Plugin hooks handle session-start loading automatically — no Bootstrap Check needed
