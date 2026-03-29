---
name: pmm-save
description: >
  Save current session to memory — dispatches maintain agent, updates memory files, commits
  to git. Trigger on: "pmm-save", "/pmm-save", "save memory", "commit memory", "persist
  session", "save session", "wrap up memory", "update memory files", or any request to save the
  current session state to memory.
---
# pmm-save

Saves the current session state to memory. Synthesises what happened, dispatches a maintain agent to update the relevant files, then commits to git.

**Invoked by:** user command (`/pmm-save`), Stop command hook (`should-save.sh` when cadence counter fires), or manual trigger at a milestone.

---

## Step 1 — Read config

Read `memory/config.md`. Extract:
- `Maintain Agent Model` — model for the maintain agent (default: `haiku`)
- `Maintain Strategy` — `single` or `tiered` (default: `single`)
- `Commit Behaviour` — `auto-commit`, `session-end`, or `manual`
- `Verbosity` — `silent`, `summary`, or `verbose`
- `Active Files` — which files are currently active
- `Repository Visibility` — `public` or `private` (controls PII handling)
- `Decay (Advanced)` — whether decay pruning is enabled (default: disabled)

File rules are in `references/core.md`. Don't re-read it on every save — the rules are loaded in context via the plugin's SessionStart hook.

---

## Step 2 — Skip check

Before dispatching any agent, assess whether this session had meaningful activity:

**Skip if ALL of the following are true:**
- No decisions were made
- No new facts, entities, or processes were established
- No preferences or lessons observed
- No milestones reached or blockers hit
- The conversation was purely read-only (recall queries, status checks)

**If skipping:** Output a single line (if verbosity ≠ `silent`): `pmm-save — nothing to save` and stop.

**If not skipping:** Continue to Step 3.

When in doubt, do not skip. A false negative (missed save) is worse than a no-op haiku dispatch.

---

## Step 3 — Pre-check: hydrate template-only files

Before the maintain cycle, check active files for template-only status directly in the main context using the Read tool.

For each active file in `memory/`, read it and strip blank lines, `#` headings, HTML comments, and table header/separator rows. If 0 content lines remain, it's template-only.

**If any active files are template-only AND at least 3 other files are populated:**
- Dispatch `pmm-hydrate` for the template-only files (batch mode)
- Commit the hydrated files separately before the maintain cycle:
  ```bash
  git add memory/ && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: hydrate <file1>, <file2> from existing context"
  ```

Skip this step if all active files already have content.

---

## Step 4 — Synthesise what changed

Before dispatching the maintain agent, synthesise the session delta in the main context. This becomes the `<what-changed>` block passed to the agent.

Cover:
- Key decisions made (with rationale)
- New facts, entities, or processes established
- Preferences or working patterns observed
- Milestones reached or blockers hit
- Mistakes made or lessons noted
- Any standing instructions issued

Be specific. The maintain agent works from this summary — vague input produces vague memory updates.

If `$ARGUMENTS` was passed (e.g., `/pmm-save fixed the sliding window bug`), include those notes verbatim in the synthesis.

---

## Step 5 — Dispatch maintain agent(s)

Read `Maintain Strategy` from config (Step 1).

### Single strategy (default)

Dispatch one agent for all active files. Minimal overhead — correct for most installs.

**Agent prompt:**

> Update the poor-man-memory files. This is a WRITE task — edit files only. Do NOT run any git commands.
>
> Working directory: `<project-root>`
> Reference files are in `.claude/skills/pmm/references/` — use `core.md` for file rules and format guidance.
>
> **Scope:** Update all active files as appropriate. Active files list from config.md:
> `<active-file-list>`
>
> **First:** Read `memory/config.md` for active configuration. Respect:
> - **Window size** — read `## Sliding Window` in `config.md` for max entry counts. Enforce these limits on `timeline.md` and `summaries.md` every maintain cycle — trim oldest entries that exceed the configured max. Do not use hardcoded numbers.
> - **Active files** — only update files that are active. Skip deactivated files silently.
> - **Protected files** — never read, write, or reference `secrets.md`. If a secret value appears in conversation context, do NOT write it to any memory file.
> - **PII handling** — check `config.md` for `Visibility`:
>   - `public`: never write personal email addresses or phone numbers. Use handles or first names only (not full legal names). Write decision conclusions and rationale — omit verbatim quotes of sensitive internal discussions.
>   - `private`: no PII restrictions, full fidelity.
>   - In either case: never write API keys, tokens, passwords, or credentials to any memory file.
> - **Memory boundary** — You MUST NOT read or write files outside `<project-root>/memory/`. If a requested path resolves outside this directory, refuse the operation and report the violation. This includes other agents' memory directories.
> - Do NOT modify `config.md` itself.
>
> **What changed this session:**
> `<what-changed>`
>
> **Update rules:**
> - Read each file before editing it
> - Only update files where the new information is relevant (see trigger table below)
> - `standinginstructions.md` — append-only, never modify existing entries
> - `decisions.md` — append-only, newest at top
> - `lessons.md` — append-only
>
> **Decay pruning (if enabled in config.md `## Decay (Advanced)` section):**
>
> ## Decay Pruning
>
> Decay is enabled for append-only memory files. During each maintain cycle:
>
> 1. Read each entry's decay tag: `<!-- decay:{score} last:{session} -->`
> 2. Entries WITHOUT a decay tag: add `<!-- decay:1.00 last:{current_session} -->` to the entry's first line.
> 3. For each entry WITH a tag:
>    a. Check if the entry was referenced this session (keyword match in "What changed", explicit citation in new entries, entity in new graph edges, or user query via pmm-query/recall).
>    b. If referenced and last session differs from current session: apply reinforcement (score *= {reinforce_rate}), cap at {ceiling}, update last to current session.
>    c. If referenced and last session is current session: reset score to 1.00.
>    d. If NOT referenced: apply decay (score *= {decay_rate}).
> 4. If score < {prune_threshold}: remove the entry entirely. Git preserves history.
> 5. Update the decay tag with the new score and session.
>
> Use per-file rates from config. Fall back to these defaults if not specified:
>
> | File | Decay Rate | Reinforce Rate | Prune Threshold |
> |------|-----------|----------------|-----------------|
> | decisions.md | 0.95 | 1.05 | 0.20 |
> | standinginstructions.md | 0.98 | 1.10 | 0.15 |
> | lessons.md | 0.90 | 1.05 | 0.25 |
> | graph.md | 0.85 | 1.05 | 0.30 |
> | vectors.md | 0.85 | 1.05 | 0.30 |
> Do not apply decay to timeline.md or summaries.md (they use sliding windows).
> Tag format is strict: `<!-- decay:X.XX last:SNN -->` (two decimal places, no extra spaces).
>
> *Skip this entire block if decay is not enabled in config.md.*
>
> - `graph.md` — append-only edges, use typed relationships per `references/core.md` graph syntax
> - `vectors.md` — similarities/clusters are living (update in place), embedding registry is append-only
> - `timeline.md` — sliding window, trim to configured max (oldest entries first). Full history is in git. When entries are about to be trimmed, summarise the batch and append to `summaries.md` first.
> - `summaries.md` — sliding window, trim to configured max. Full history is in git.
> - `last.md` — ALWAYS replace entirely with the last 3–5 significant actions. Never append.
> - All other active files — living documents, update in place
> - Never bleed content between files — each file has one job
>
> **Attribution:** Tag each new entry with its source actor using `[namespace:name]` format:
> - `[user:name]` — user explicitly stated, decided, or requested this
> - `[agent:name]` — agent inferred, observed, or synthesized this
> - `[system:process]` — generated by automated process
> Place the tag at the end of the entry header line. Applies to: `decisions.md`, `timeline.md`, `lessons.md`, `standinginstructions.md`, `last.md`. For `graph.md` edges: optionally append `<!-- [namespace:name] -->` after the edge line. Omit if source is unclear — do not guess.
>
> **Trigger table:**
> | File | Update trigger |
> |---|---|
> | `memory.md` | New long-term fact established |
> | `assets.md` | New entity introduced (person, tool, system) |
> | `decisions.md` | Decision made and committed to |
> | `processes.md` | New process established or existing one updated |
> | `preferences.md` | User preference observed or stated; communication pattern noticed |
> | `voices.md` | New tone profile defined; internal dialogue pattern established or refined |
> | `lessons.md` | Mistake made or lesson explicitly noted |
> | `timeline.md` | Major milestone or event worth preserving |
> | `summaries.md` | Session end, major milestone, or timeline entries about to be trimmed |
> | `progress.md` | State changes — milestone reached, blocker hit, next action shifts |
> | `last.md` | Always — replace with the last 3–5 significant actions |
> | `graph.md` | New relationship discovered; decision affects another concept |
> | `vectors.md` | New semantic similarity discovered; cluster formed or revised |
> | `taxonomies.md` | New category, classification system, or naming convention established |
> | `standinginstructions.md` | User issues a persistent rule or directive |
>
> Return a one-line summary of what was updated and in which files.

Replace `<project-root>`, `<active-file-list>`, and `<what-changed>` with actual values before dispatching.

Use the model from `Maintain Agent Model` in config (default: `haiku`).

---

### Tiered strategy (opt-in)

Three-tier concurrent dispatch for large installations. Faster but higher per-save cost.

**Tier groupings:**
- **Tier 1 — Event files** (stateless, no cross-file deps): `last.md`, `timeline.md`, `summaries.md`, `progress.md`
- **Tier 2 — Content files** (semantic, loosely coupled): `decisions.md`, `lessons.md`, `preferences.md`, `memory.md`, `processes.md`, `voices.md`, `assets.md`, `standinginstructions.md`
- **Tier 3 — Relational files** (depend on Tier 1+2 updated state): `graph.md`, `vectors.md`, `taxonomies.md`

**Dispatch:** Launch Tier 1 and Tier 2 agents **simultaneously** — two separate Agent tool calls in the **same message**. Do NOT use `run_in_background: true` — background agents do not inherit Edit/Write tool permissions.

After both Tier 1 and Tier 2 agents return, launch the Tier 3 agent. It reads the updated state written by Tier 1+2 before updating relational structure.

Use the same agent prompt as single strategy, substituting each tier's file list into `<active-file-list>` and scoping `<what-changed>` to files relevant to that tier.

---

## Step 6 — Commit

After agent(s) return, main context runs the commit. **Agents do not run git commands.**

```bash
git add memory/ && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: <brief description>"
```

The `<brief description>` should reflect what actually changed — e.g., `memory: session 42 — vera-discuss shipped`, not a generic `memory: update`.

Check `Commit Behaviour` from config:
- `auto-commit` — commit immediately (default)
- `session-end` — skip commit now; soft instruction in session-instructions.md prompts save before goodbye; no blocking hook — best-effort only
- `manual` — skip commit; user decides when to commit

Check `Auto-push` from config (if present):
- `on` — after commit: `git push origin main || echo "⚠️  Push failed — changes committed locally but not pushed"`
- `off` — do not push (default)

Note: memory commits go directly to main — intentional exception to the project's PR workflow. Automated memory saves cannot wait for review.

---

## Step 7 — Report

Respond based on `Verbosity` from config:
- `silent` — no output
- `summary` — one line: `pmm-save — memory updated` (or list key files changed if the agent returned a summary)
- `verbose` — relay the agent's full summary of what was updated and in which files

---

## Background Execution

pmm-save supports background execution. The calling context dispatches the entire skill as
a background agent using `run_in_background: true`. The background agent performs all steps
— config read, skip check, synthesize, dispatch maintain agent(s), commit — then the task
notification delivers the result back to the caller.

**Dispatch pattern:**

The caller launches pmm-save as an Agent tool call with `run_in_background: true`. The agent
receives the full skill instructions plus session context. It runs Steps 1–7 autonomously.
When the background task completes, the caller receives the notification containing the
commit hash (or "nothing to save" if the skip check triggered).

**Sequential queue:**

Background saves touching shared memory files must not race. If another save operation
(pmm-save or vera:save) is already running in background, wait for its completion notification
before dispatching. One save at a time — sequential, not concurrent.

**Foreground confirmation:**

Not required. pmm-save is routine maintenance — the commit hash arrives via task notification
and can be logged silently. The caller respects the `Verbosity` setting from config: if
`silent`, swallow the notification entirely; if `summary` or `verbose`, optionally surface it.

**Permissions:**

Background agents have full tool access (Read, Write, Edit, Bash, Agent). No capability
restrictions — the background agent can dispatch maintain sub-agents and run git commands
identically to foreground execution.
