# Poor Man's Memory

Structured, git-backed memory for Claude Code. Memory that compounds, not rots.

If you have ever had AI hallucinate and make things up (and gaslight you, even): it's because summaries do not preserve nuance.

Each `/compact` cycle summarises and compresses. Decisions lose their rationale. Lessons lose their context. By Monday, you're re-explaining choices you made on Thursday. That's context rot.

PMM fixes that. Every session, Claude loads what it already knows, then adds to it.

Markdown files, git-backed. No database, no setup. Decisions tracked with rationale — not just what, but why. git log is your memory audit trail. Memory that compounds, not rots.

PMM is the zero-infrastructure open-source entry point for the Nominex memory layer. Structured markdown and git — no external services, no API keys, no setup beyond `pmm:init`.

## Status

Active development. Current version: 2.5.4.

## Quick Start

1. Install: `claude plugin marketplace add anthropics/claude-plugins-official && claude plugin install pmm@claude-plugins-official`
2. Run `pmm:init` — answers a few setup questions, creates `memory/` in your project
3. **Existing project?** Run `pmm:hydrate --all` — populates memory files from your current session context
4. Start working — memory saves automatically at milestones

See [BUILD.md](BUILD.md) for detailed setup and development workflow.

## What It Does

- **Structured memory**: 16 files with distinct jobs — decisions, lessons, preferences, timeline, graph, vectors, and more
- **Auto-loads at session start**: SessionStart hook injects Tier 1 files (12 essential files) directly into context
- **Auto-saves**: Stop hook monitors save cadence based on config. Blocks exit until save completes when threshold is reached
- **Decision history**: Every decision committed to git with context. `git log` is your memory audit trail
- **Context-switching recall**: `pmm:recall` synthesizes focused briefings across all memory files
- **Configurable**: model selection (haiku by default), sliding window size, verbosity, repository visibility, PII handling

## Skills

| Skill | Description |
|-------|-------------|
| `pmm:init` | Scaffold `memory/` directory via 9-question preference wizard |
| `pmm:save` | Synthesize session changes, dispatch maintain agent, commit to git |
| `pmm:query` | Search memory with filtering, attribution, and deep traversal |
| `pmm:recall` | Focused briefing synthesis for context-switching and resume |
| `pmm:hydrate` | Bootstrap memory files from existing session context |
| `pmm:settings` | View and modify PMM configuration |
| `pmm:status` | Diagnostic scan of memory system health |
| `pmm:viz` | Interactive D3.js force-directed graph visualization |
| `pmm:dump` | Terminal-only memory visualization (status, summary, detailed) |
| `pmm:update` | Check upstream for new version, apply updates to system files only |
| `pmm:init-local-skills` | Symlink local skill variants for Cowork compatibility |

## Who It's For

Developers and teams using Claude Code who want persistent, structured memory across
sessions. Anyone tired of re-explaining decisions, losing context after `/compact`, or
fighting context rot from lossy summarization.

## Documentation

- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Build](BUILD.md)
- [Testing](TESTING.md)
- [Pipeline](PIPELINE.md)
- [Development](DEVELOPMENT.md)
- [Privacy](PRIVACY.md)

## Install

### Official marketplace

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install pmm@claude-plugins-official
```

### Community mirror

```bash
claude plugin marketplace add anthropics/claude-plugins-community
claude plugin install pmm@claude-community
```

## Memory File Tiers

### Tier 1 — always loaded (12 files)

| File | Purpose |
|------|---------|
| `config.md` | PMM configuration |
| `standinginstructions.md` | Persistent rules (append-only) |
| `last.md` | Last 3-5 significant actions |
| `progress.md` | Current milestones, blockers, what's next |
| `decisions.md` | Committed decisions with rationale |
| `lessons.md` | Mistakes made and lessons learned |
| `preferences.md` | User style, quirks, working habits |
| `memory.md` | Long-term durable facts |
| `summaries.md` | Session rollups (sliding window) |
| `voices.md` | Tone profiles and reasoning lenses |
| `processes.md` | Workflows and repeatable procedures |
| `timeline.md` | Compressed chronological record |

### Tier 2 — on demand (4 files)

| File | Purpose |
|------|---------|
| `graph.md` | Typed edges between concepts |
| `vectors.md` | Semantic similarities and clusters |
| `taxonomies.md` | Classification systems and naming conventions |
| `assets.md` | People, tools, systems, organizations |

## Hooks

- **SessionStart** (`session-start.sh`): Loads active Tier 1 files into context at session start. Per-file load strategies: `full`, `tail:N`, `header`, `skip`.
- **Stop** (`should-save.sh`): Monitors save cadence. Blocks exit until save completes when threshold is reached. Zero token cost — pure bash counter.
- **SessionEnd** (soft instruction): Prompts Claude to save before closing. Best-effort.

## Patterns and Anti-Patterns

### Do this

- Save at milestones, not on a timer
- Hydrate before you maintain new files
- Let the tiers work (Tier 2 loads on demand)
- Use recall to context-switch, query to search
- Use query filters instead of grep
- Commit auto, push manual
- Run `pmm:save` before `/compact`

### Avoid this

- Saving after every message (noise, not signal)
- Skipping hydration on new files (thin entries compound)
- Using opus for maintenance (haiku handles mechanical work at 10x less cost)
- Manually editing memory files during a session
- Ignoring template-only warnings from `pmm:status`
- Treating memory as documentation (memory tracks what happened, not what should happen)

## Platform

- **macOS / Linux**: Supported natively
- **Windows**: Works via Git Bash. Developer Mode required for symlink creation.
- **Git**: 2.5+
- **Claude Code**: Latest version with plugin support

## License

MIT. Built by [NominexHQ](https://github.com/NominexHQ).
