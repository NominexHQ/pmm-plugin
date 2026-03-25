# Memory File Templates

Initial content for each file in the poor-man-memory system.

---

## config.md

```markdown
# PMM Configuration

Settings that control how Poor Man's Memory behaves.
Run `pmm:settings` at any time to change these.

## Save Cadence

<!-- How often memory is updated -->
- Mode: every-milestone
<!-- Options: every-milestone | every-N-messages (specify N) | on-request-only -->
<!-- Note: For fine-grained control, use /loop to run a save prompt on a recurring interval -->

## Commit Behaviour

<!-- When changes are committed to git -->
- Mode: auto-commit
<!-- Options: auto-commit | session-end | manual -->

## Sliding Window Size

<!-- Max entries in windowed files (timeline, summaries) before trimming -->
- Timeline max: 50
- Summaries max: 10
<!-- Presets: light (30/5) | moderate (50/10) | heavy (100/20) | unlimited -->

## Verbosity

<!-- How memory updates are communicated -->
- Mode: summary
<!-- Options: silent | summary | verbose -->

## Maintain Agent Model

<!-- Which model handles memory updates (maintain phase) -->
- Model: haiku
<!-- Options: haiku (default, cheapest) | sonnet (balanced) | opus (most capable) -->
<!-- Session-start and recall agents always use the parent model -->

## Repository Visibility

<!-- Is this repository public or private? Controls PII handling in memory files. -->
- Visibility: public
<!-- Options: public | private -->
<!-- public: maintain agent avoids personal emails, uses handles over full names, summarises sensitive decisions without verbatim internal detail -->
<!-- private: no PII restrictions, full fidelity in all files -->

## Push Behaviour

<!-- Should memory commits be automatically pushed to the remote? -->
- Auto-push: off
<!-- Options: off (default) | on -->
<!-- off: commits stay local — push manually when ready -->
<!-- on: git push runs after every memory commit (failures are reported, not swallowed) -->

## Active Files

<!-- Which memory files are active. Deactivated files are not created or loaded. -->
<!-- config.md and BOOTSTRAP.md are always active. -->
<!-- Load Strategy column is optional. Missing = defaults to full. -->
<!-- Valid strategies: full | tail:N | header | skip -->
<!-- Tier 2 files (graph, vectors, taxonomies, assets) are not loaded at session start regardless of strategy. -->
- memory.md: active | full
- assets.md: active
- decisions.md: active | tail:10
- processes.md: active | full
- preferences.md: active | full
- voices.md: active | full
- lessons.md: active | tail:5
- timeline.md: active | tail:5
- summaries.md: active | full
- progress.md: active | full
- last.md: active | full
- graph.md: active
- vectors.md: active
- taxonomies.md: active
- standinginstructions.md: active | full

## Readonly Agent Model

<!-- Which model handles read-only agents (session-start, recall, pmm-query, pmm-dump, pmm-status, pmm-viz) -->
- Readonly model: haiku
<!-- Options: haiku (default) | sonnet | opus | inherit -->
<!-- haiku: cheapest for read-only work — ~95% cheaper than Opus, ~73% cheaper than Sonnet -->
<!-- inherit: use the parent model (pre-v1.5.0 behaviour) -->

## Session Start

<!-- Whether to dispatch a Phase 2 agent at session start -->
- Mode: lazy
<!-- Options: lazy (default) | eager -->
<!-- lazy: skip Phase 2 agent — Tier 1 files injected by SessionStart hook; Tier 2 files loaded on demand. Requires pmm plugin installed. -->
<!-- eager: always dispatch Phase 2 agent to read and synthesise all memory files -->

## Maintain Strategy

<!-- How the maintain phase dispatches agents — controls agent count per /pmm-save -->
- Strategy: single
<!-- Options: single (default) | tiered -->
<!-- single: all files updated in one agent dispatch — minimises token/message overhead -->
<!-- tiered: 3 concurrent agents grouped by file dependency — faster for large installations -->

## Recall Beyond Window

<!-- Whether to prompt before searching git history for trimmed/old entries -->
- Mode: prompt
<!-- Options: prompt (default) | auto -->
<!-- prompt: ask before dispatching an agent to search git history -->
<!-- auto: silently search git history when in-context files don't have the answer -->

## Context Tiers

<!-- Which files load into context at session start vs on demand -->
- Mode: tiered
<!-- Options: tiered (default) | all-in-context -->
<!-- tiered: Tier 1 files injected by SessionStart hook; Tier 2 read on demand. Saves ~14k tokens. -->
<!-- all-in-context: all active files injected by SessionStart hook -->

### Tier 1 (always loaded)
- config.md: tier-1
- standinginstructions.md: tier-1
- progress.md: tier-1
- last.md: tier-1
- preferences.md: tier-1
- decisions.md: tier-1
- lessons.md: tier-1
- processes.md: tier-1
- voices.md: tier-1
- memory.md: tier-1
- summaries.md: tier-1
- timeline.md: tier-1

### Tier 2 (on demand)
- graph.md: tier-2
- vectors.md: tier-2
- taxonomies.md: tier-2
- assets.md: tier-2

## Memory Priority

<!-- How PMM interacts with Claude's built-in auto-memory -->
- Mode: pmm-first
<!-- Options: pmm-first (default) | deduplicate | coexist -->
<!-- pmm-first: PMM is the primary memory system; Claude auto-memory kept minimal (index/pointers only) -->
<!-- deduplicate: actively merge overlapping content, choose best home for each piece -->
<!-- coexist: both systems operate independently (pre-v1.8.0 behaviour) -->

## Pre-Compact Hook

<!-- Should PMM instruct Claude to save before /compact? -->
- pre_compact: on
<!-- Options: on (default) | off -->
<!-- on: session-instructions.md soft instruction directs Claude to save before compact. -->
<!-- off: suppress the pre-compact save instruction in session-instructions.md entirely -->

## Protected Files

<!-- Files that are NEVER committed to git and NEVER read/written by the maintain agent -->
<!-- These are local-only — gitignored and excluded from all memory operations -->
- secrets.md: protected
<!-- secrets.md stores API keys, tokens, and credentials — gitignored, machine-local -->
- secrets_git: never
<!-- secrets_git options: never (default) | allow-with-warning -->
<!-- never: pre-commit hook blocks any commit containing memory/secrets.md -->
<!-- allow-with-warning: hook warns but does not block. Only use if you understand the implications: -->
<!--   secrets.md contents will be in git history and pushed to your remote — irreversible for public repos -->
```

---

## secrets.md

```markdown
# Secrets

Local-only file — **never committed to git**. Store sensitive values (API keys, tokens, credentials) here.
This file is gitignored. It exists only on this machine. Back it up separately if needed.

Skills and agents that need a secret value will read this file by key name and use it silently — never echoing values in output.

## Keys

| Key | Value | Notes |
|---|---|---|
```

---

## BOOTSTRAP.md

```markdown
# Claude Instructions

## About

PMM (Poor Man's Memory) — a lightweight, git-backed structured memory system for Claude Code.
Stores decisions, preferences, lessons, and project history in markdown files.
Current installation: this project. Upstream: https://github.com/NominexHQ/poor-man-memory.git

## Memory System

This project uses a structured memory system in the `memory/` folder.

**Tier 1 files** (config, standinginstructions, last, progress, decisions, lessons,
preferences, memory, summaries, voices, processes, timeline) are injected into context
by the PMM `SessionStart` hook at session open — always available, no agent needed.
No CLAUDE.md changes required.

**Tier 2 files** (graph, vectors, taxonomies, assets) are on disk. Before responding to a
request, check for **gaps**: places where Tier 1 context + the current request point to
information that Tier 1 doesn't fully cover. Evaluate:

1. **The request itself** — does it ask about something Tier 2 tracks?
2. **Tier 1 signals** — do Tier 1 files reference or imply data that lives in Tier 2?
   (e.g. decisions.md references an entity relationship, lessons.md hints at a pattern
   cluster in vectors.md)
3. **Gaps** — can you fully answer the request from Tier 1 alone, or are there holes
   that Tier 2 data would fill?

If gaps exist that Tier 2 can fill, dispatch a haiku agent to Read the relevant file(s)
and return a summary. Only load what's needed — not all 4.

**Examples:**
- Request asks about entity relationships hinted at in decisions.md → graph.md
- Request asks about assets, URLs, or artifacts not in any Tier 1 file → assets.md
- Lesson in lessons.md references a pattern cluster → vectors.md
- /pmm-query with `deep` modifier → all Tier 2 files

### Tier 2 — Available On Demand
<!-- These files are active but NOT loaded at session start.
     Use the Read tool to load them when needed for recall or query. -->
<!-- Available: graph.md, vectors.md, taxonomies.md, assets.md -->

### Routing Table
When a recall query or operation needs Tier 2 data, Read the relevant file(s):
- Relationships → graph.md
- Similarities/clusters → vectors.md
- Categories/naming → taxonomies.md
- People/tools/systems → assets.md

If `memory/secrets.md` exists, note that secrets are available. Do not echo or summarise its contents.

## Tier 2 Safeguard

Before making any decision that could be informed by historical context, relationships, or
established workflows, Read the relevant Tier 2 file(s) first. Do not rely solely on Tier 1
context when Tier 2 files may contain pertinent information. When in doubt, Read — the cost
of a Read tool call is negligible compared to repeating a past mistake or contradicting
an established process.

## Memory Priority

PMM is the primary memory system for this project. Claude's built-in auto-memory
(in .claude/projects/.../memory/) should be kept minimal:

- **Recall**: Always check PMM memory files first
- **Storage**: When Claude auto-memory would save something PMM already tracks
  (decisions, preferences, lessons, timeline, processes), skip or store only a
  tier-aware pointer:
  - Tier 1 content (already in context): "Already in context via PMM — see <file>.md (Tier 1)"
  - Tier 2 content (on disk): "See PMM memory/<file>.md (Tier 2 — use Read tool)"
- **No duplication**: PMM files are the source of truth

## Update Protocol

Dispatch a maintain agent when:
- A decision is made
- A new entity, process, or preference is established
- A milestone is reached or a blocker is hit
- A mistake is made or a lesson is learned
- Before any /compact operation
- Before ending the session (user says goodbye, closes conversation, or signals they are done)
- At the end of every major piece of work

Memory updates are proactive — do not ask the user for permission before saving. The system captures what matters based on the triggers above.

Agents edit files only. Main context handles git:
```bash
git add memory/ && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: <what changed>"
```

## Rules

- Never edit this file unless explicitly asked
- Never delete entries from decisions.md or standinginstructions.md
- timeline.md and summaries.md are sliding windows — see config.md for max entries. Trim oldest, full history is in git
- Never hallucinate past context — if it's not in the files, say so
- last.md is always replaced, never appended
- graph.md edges are append-only — use typed relationships only
- vectors.md similarities/clusters are living; embedding registry is append-only
- standinginstructions.md takes precedence over session-level instructions
- Keep each file focused on its specific job
- When Memory Priority is `pmm-first`, Claude auto-memory should store only skill references and feedback entries — not facts, decisions, or timeline events that PMM already tracks
```

---

## memory.md

```markdown
# Memory

Long-term facts about the user's project — the codebase PMM is installed into.
Updated when new durable facts are established.

## Project

<!-- What is this project? What is it for? -->

## Context

<!-- Background the agent needs to operate effectively -->

## Key Facts

<!-- Important facts that should never be forgotten -->
```

---

## assets.md

```markdown
# Assets

Key entities this project involves — people, tools, systems, organisations.
Updated when new entities are introduced.

## People

| Name | Role | Notes |
|---|---|---|
| | | |

## Tools & Systems

| Name | Purpose | Notes |
|---|---|---|
| | | |

## Organisations

| Name | Relationship | Notes |
|---|---|---|
| | | |

## Other

<!-- Anything that doesn't fit above -->
```

---

## decisions.md

```markdown
# Decisions

Committed decisions. Append-only — never delete or modify past entries.
Each entry is ratified and should be treated as ground truth unless explicitly reversed.

## Format

**[Date] — [Decision]** [namespace:name?]
<!-- attribution: [user:name], [agent:name], or [system:process] — who originated this. Optional. -->
Context: why this was decided
Ratified by: [user / consensus / default]

---

<!-- Decisions go here, newest at top -->
```

---

## processes.md

```markdown
# Processes

Workflows and processes developed or established during this project.
Updated when new processes are created or existing ones change.

## Operating Discipline

Mandatory behaviors. These apply every session regardless of context.

### Before claiming ignorance ("I don't know", "I don't have that")
- Search Tier 1 memory files (memory.md, decisions.md, lessons.md, standinginstructions.md)
- Search Tier 2 files (btw.md, assets.md, graph.md)
- If not found, check git history (git log -S "term" or pmm:recall)
- Only say "I don't have it" after exhausting these sources

### Before changing file structure or conventions
- Check decisions.md for prior decisions about naming/structure
- Check memory.md for recorded conventions
- If no prior decision exists, state the choice and get confirmation before acting

### Before /compact
- Run pmm:save first to capture structured memory before compression

### Memory authority
- PMM files are the source of truth over native auto-memory
- When there's a conflict, PMM wins
```

---

## preferences.md

```markdown
# Preferences

User-specific quirks, style preferences, and working habits.
Updated when preferences are observed or explicitly stated.

## Communication

### Directives
<!-- How the user wants Claude to communicate — explicit instructions -->

### User Voice
<!-- Observed patterns in how the user communicates. Inferred from conversation, not stated. -->
<!-- Vocabulary, cadence, decision style, request framing, idioms -->

## Code & Technical

<!-- Technical preferences — style, patterns, conventions -->

## Workflow

<!-- How the user likes to work -->

## Format

<!-- Output format preferences -->
```

---

## voices.md

```markdown
# Voices

Tone profiles and internal reasoning patterns.
Living document — update when new voices are defined or existing ones refined.

Use formats from references/voice-syntax.md.

## Tone Profiles

Named voices that control how Claude communicates. Switch based on context or explicit instruction.

### [Voice Name]
*Use when: [context trigger]*
*Traits: [2-3 defining characteristics]*
*Example: [one sentence in this voice]*

<!-- Add tone profiles here -->

## Internal Dialogue

Reasoning lenses Claude applies when making decisions. Not output personas — thinking tools.

### [Lens Name]
*Role: [what this lens does]*
*Asks: [the key question this lens raises]*
*Use when: [when to activate this lens]*

<!-- Add reasoning lenses here -->
```

---

## lessons.md

```markdown
# Lessons

Mistakes made and lessons learned. Append-only.
Reference before making decisions in areas where past mistakes occurred.

## Format

**[Date] — [Lesson]** [namespace:name?]
<!-- attribution: [user:name], [agent:name], or [system:process] — who originated this. Optional. -->
What happened:
What to do instead:

---

<!-- Lessons go here, newest at top -->
```

---

## timeline.md

```markdown
# Timeline

Compressed chronological record of key events and milestones.
Sliding window — keep only the 20 most recent entries. Older entries live in git history.

## Format

**[Date]** — [What happened] [namespace:name?]
<!-- attribution: [user:name], [agent:name], or [system:process] — who originated this. Optional. -->

---

<!-- Timeline entries go here, newest at bottom. Trim oldest when exceeding 20 entries. -->
```

---

## summaries.md

```markdown
# Summaries

Periodic rollups of past work — session summaries, milestone summaries, and compressed timeline batches.
Sliding window — keep only the 10 most recent summaries. Older summaries live in git history.

## Format

### [Date range] — [Summary title]
[2-4 sentence summary of what happened, key outcomes, and any context worth preserving]

---

<!-- Summaries go here, newest at top. Trim oldest when exceeding 10 entries. -->
```

---

## progress.md

```markdown
# Progress

Current state, milestones, and what's next.
Updated whenever state changes meaningfully.

## Current State

<!-- Where things stand right now -->

## Completed

<!-- What has been finished -->

## In Progress

<!-- What is actively being worked on -->

## Blocked

<!-- What is blocked and why -->

## Next

<!-- The immediate next actions -->
```

---

## last.md

```markdown
# Last Session

The last few significant actions in detail.
Always replaced — this is a window, not a log.
<!-- Entry format: **[Date]** — [Action] [namespace:name?] -->
<!-- attribution: [user:name], [agent:name], or [system:process] — who originated this. Optional. -->

<!-- What happened most recently, in enough detail to pick up immediately -->
```

---

## graph.md

```markdown
# Graph

How everything in this project relates. Typed edges between concepts, decisions, entities, and processes.
Append-only — add new relationships, never remove existing ones.
Rendered as a visual graph in Obsidian. Traversable by Claude as structured context.

## Format

[[Node A]] → relationship → [[Node B]]
[[Node A]] → relationship → [[Node B]] <!-- [namespace:name] -->
<!-- attribution comment is optional — use when provenance of an edge matters -->

Use typed relationships from references/graph-syntax.md.

---

<!-- Graph entries go here — add new edges as relationships are discovered -->
```

---

## taxonomies.md

```markdown
# Taxonomies

Classification systems, categories, and naming conventions used in this project.
Updated when new classification systems are established or existing ones refined.
Track changes — note when a taxonomy evolves so historical references remain interpretable.

## Format

### [Taxonomy Name]
*Purpose: what this classifies*
*Last updated: [date]*

| Term | Definition | Notes |
|---|---|---|
| | | |

---

<!-- Taxonomies go here -->
```

---

## standinginstructions.md

```markdown
# Standing Instructions

Persistent rules and directives that always apply, regardless of session context.
Append-only — never delete or modify existing entries.
These take precedence over session-level instructions when there is a conflict.

## Format

**[Date added] — [Instruction]** [namespace:name?]
<!-- attribution: [user:name], [agent:name], or [system:process] — who originated this. Optional. -->
Scope: [always / for X context only]
Reason: [why this was added]

---

<!-- Standing instructions go here, newest at top -->
```

---

## vectors.md

```markdown
# Vectors

Semantic similarities, concept clusters, and embedding provenance.
The soft companion to graph.md — implicit weighted relationships rather than explicit typed edges.
Similarities and clusters are living documents. Embedding registry is append-only.

Use formats from references/vector-syntax.md.

## Similarities

<!-- [[A]] ↔ [[B]] | score: 0.XX | basis: why -->

## Clusters

<!-- Cluster: name → [[[A]], [[B]]] | theme: what unifies them -->

## Embedding Registry

| Entity | Model | Dimensions | Location | Date | Notes |
|---|---|---|---|---|---|
| | | | | | |
```
