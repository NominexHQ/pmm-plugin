# PMM Plugin Reference

_Loaded with plugin cache. This is the single reference document for the PMM plugin._
_All skills in this plugin can reference this document._

---

## 1. Core

### Memory File Inventory

| File | Tier | Behavior | Purpose |
|------|------|----------|---------|
| `config.md` | 1 | Read-only by agents | Controls all PMM behaviour |
| `standinginstructions.md` | 1 | Append-only | Persistent rules, take precedence over session instructions |
| `last.md` | 1 | Replace on every save | Last 3-5 significant actions in detail |
| `progress.md` | 1 | Living | Current milestones, state, next actions |
| `decisions.md` | 1 | Append-only | Committed decisions, newest at top |
| `lessons.md` | 1 | Append-only | Mistakes and lessons learned |
| `preferences.md` | 1 | Living | User quirks, style, working habits |
| `memory.md` | 1 | Living | Long-term project facts |
| `summaries.md` | 1 | Sliding window (max 10) | Periodic rollups |
| `voices.md` | 1 | Living | Tone profiles, reasoning lenses |
| `processes.md` | 1 | Living | Workflows and processes |
| `timeline.md` | 1 | Sliding window (max 50) | Compressed chronological record |
| `graph.md` | 2 | Append-only edges | Typed relationships between concepts |
| `vectors.md` | 2 | Living clusters, append-only registry | Semantic similarities, embeddings |
| `taxonomies.md` | 2 | Living | Classification systems, naming conventions |
| `assets.md` | 2 | Living | People, tools, systems, organisations |
| `secrets.md` | Protected | Never committed, never read by agents | Local-only credentials |

### Tier System

- **Tier 1** (12 files): injected at session start by `SessionStart` hook. Always in context.
- **Tier 2** (4 files): on disk, loaded on demand. Route: relationships -> graph.md,
  similarities -> vectors.md, categories -> taxonomies.md, entities -> assets.md.
- **Tier 3**: custom files via `pmm:memory`. Tracked in `registry.md`.

### Update Protocol

Trigger a maintain agent when:
- Decision made, entity/process/preference established, milestone reached
- Mistake made or lesson noted
- Before `/compact`, before session exit
- Explicit `/pmm:save`

Memory saves are proactive -- no user permission needed.

### Agent Permission Model

Agents edit files only. Main context handles all git:
```bash
git add memory/ && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: <description>"
```

Background agents (`run_in_background: true`) do not inherit Edit/Write permissions.
Dispatch as foreground for write operations.

Model selection:
- Maintain agent: `Maintain Agent Model` from config (default: haiku)
- Read-only agents: `Readonly Agent Model` from config (default: haiku)

### Commit Rules

- Always exclude `secrets.md` from commits
- Memory commits go directly to main (intentional exception to PR workflow)
- `config.md` read by agents, written only by `pmm:settings`

### Universal Rules

1. Never hallucinate past context
2. Never bleed content between files
3. Respect active files list in config
4. `secrets.md` is out of scope -- never read, write, or reference
5. `standinginstructions.md` wins over session instructions
6. Attribution tagging: `[user:name]`, `[agent:name]`, `[system:process]`, `[system:hydrate]`
7. PMM-first memory priority: Claude auto-memory stores only pointers
8. PII handling follows repository visibility setting
9. Memory commits go directly to main
10. `config.md` is read-only for agents

---

## 2. Templates

### Config Defaults

| Setting | Default | Options |
|---------|---------|---------|
| Save Cadence | every-milestone | every-milestone, every-N-messages, on-request |
| Commit Behaviour | auto-commit | auto-commit, session-end, manual |
| Push Behaviour | off | on, off |
| Timeline max | 50 | light(30), moderate(50), heavy(100), unlimited |
| Summaries max | 10 | light(5), moderate(10), heavy(20), unlimited |
| Verbosity | summary | silent, summary, verbose |
| Visibility | public | public, private |
| Maintain Agent Model | haiku | haiku, sonnet, opus |
| Readonly Agent Model | haiku | haiku, sonnet, opus, inherit |
| Session Start | lazy | lazy (hook handles), eager (dispatch agent) |
| Maintain Strategy | single | single, tiered (3 concurrent agents) |
| Recall Beyond Window | prompt | prompt, auto |
| Context Tiers | tiered | tiered, all-in-context |
| Memory Priority | pmm-first | pmm-first, deduplicate, coexist |
| Pre-Compact Hook | on | on, off |

### File Headers

Each memory file has a standard header template. Key patterns:
- Append-only files: header explains format, entries go newest-at-top (decisions, lessons,
  standinginstructions) or newest-at-bottom (timeline)
- Sliding windows: header specifies max entries loaded at session start; full file always on disk, no truncation
- Living documents: header describes scope, updated in place
- `last.md`: always replaced entirely, never appended

### Tier 1 / Tier 2 Loading

- Tier 1: 12 core files loaded by `SessionStart` hook. No CLAUDE.md changes needed.
- Tier 2: 4 relational files on disk. Loaded via haiku agent when a gap is detected.
  Only load what the request requires, not all four.
- Load strategies per file in config Active Files section: `full` (default), `tail:N`,
  `header`, `skip`

### Syntax References

- **Graph edges**: `[[Node A]] -> relationship-type -> [[Node B]]`. Always typed.
  Types: structural (is-a, part-of, contains, extends, implements), causal (depends-on,
  blocks, enables, triggers, fixes), semantic (related, similar-to, contrasts-with,
  replaces, inspired-by), epistemic (ratified-by, inferred-from, contradicts, supersedes),
  operational (uses, writes-to, reads-from, owned-by, status).

- **Vector similarities**: `[[A]] <-> [[B]] | score: 0.XX | basis: <why>`. Scores 0.0-1.0.
  Never record below 0.3. Basis is required.

- **Clusters**: `Cluster: <name> -> [[[A]], [[B]]] | theme: <what unifies them>`. Theme required.

- **Voices**: Tone profiles (`Use when`, `Traits`, `Example`) and internal dialogue lenses
  (`Role`, `Asks`, `Use when`). Orthogonal dimensions -- tone controls output, lenses
  control reasoning.

---

## 3. Memory Isolation

PMM is the foundation layer. Each agent's `memory/` directory is its own PMM instance.
Isolation is enforced at three levels: PMM, Crew, and Coordinator.

### Principle

No agent reads another agent's memory files. Each agent operates within its own memory
boundary. Cross-agent knowledge transfer happens through conversation (vera:hydrate,
vera:discuss), not through file reads.

### Why

- **Context integrity**: an agent's memory reflects what it experienced, not what it was
  told to remember from another agent's perspective
- **Eval validity**: if agents share memory, eval scores reflect shared context, not
  individual capability
- **Ownership clarity**: each memory file has exactly one agent responsible for its content

### Enforcement — Three Levels

#### Level 1: PMM (maintain agent boundary)

The maintain agent prompt includes `{working_directory}` scoping. Enforcement rule
(included in the maintain agent prompt):

> You MUST NOT read or write files outside `{working_directory}/memory/`. If a requested
> path resolves outside this directory, refuse the operation and report the violation.

This is prompt-level enforcement. No filesystem ACLs, no code gates. The maintain agent
is the only writer — constraining it constrains all PMM writes.

#### Level 2: Crew (section ownership)

Crew-owned files (`spec.md`, `eval-log.md`, etc.) use `<!-- owner: agent -->` and
`<!-- owner: coordinator -->` section markers. Before writing to a section, the writer
verifies the `<!-- owner: -->` marker matches its role:

- Agent maintain → writes only to `<!-- owner: agent -->` sections
- Coordinator (vera) → writes only to `<!-- owner: coordinator -->` sections

Schema version gating (`crew-schema-version: 1`) is already enforced — vera checks
the version before writing. Section ownership adds the per-block constraint.

#### Level 3: Coordinator (dispatch isolation)

Agents dispatched via `vera:task`, `vera:sprint`, or `vera:discuss` receive ONLY their
own memory context. The coordinator never injects Agent A's memory into Agent B's
dispatch prompt. Cross-agent knowledge flows through conversation, not context injection.

Vera reads any agent's files for coordination (roster, dispatch weights, eval planning).
Vera does not write to agent memory files — reads only.

### Exceptions

- **Vera** reads agent memory files for coordination (roster, hydration planning, eval).
  Vera does not write to agent memory files — reads only.
- **PMM status/dump** may read across agents for reporting. Read-only, no writes.

### Eval Memory Isolation (Cross-Reference)

A specific case of memory isolation: eval events are never written to any agent's PMM
memory files. See crew plugin reference, Eval Format section. `eval-log.md` and
`eval-summary.md` are the only eval artifacts.
