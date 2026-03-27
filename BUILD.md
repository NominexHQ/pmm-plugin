# Build

## Prerequisites

- Git 2.5+
- GNU Make
- Bash 4+
- Claude Code with plugin support

## Clone and Setup

```bash
git clone git@github.com:NominexHQ/pmm-plugin.git
cd pmm-plugin
```

No submodules. No external dependencies beyond the tools listed above.

## Dependencies

The plugin is self-contained. Skills are defined as SKILL.md files in `skills/`.
Local variants are generated from those files by the Makefile transform. No package
manager or dependency installation step.

## Build

```bash
make local
```

This reads every SKILL.md in `skills/` (excluding `init-local-skills`), transforms
colon-namespaced references (`pmm:save`) to hyphenated local variants (`pmm-save`),
and writes the results to `local/`. The output should list the number of skills
generated:

```
Generating local skill variants...
Done. 10 skills generated in local/
```

### Other targets

| Target | Purpose |
|--------|---------|
| `make local` | Generate local skill variants in `local/` |
| `make clean` | Remove `local/` directory |

## Local Development

After cloning, the plugin skills in `skills/` are the source of truth. Edit those
directly. Run `make local` to regenerate local variants after any edit.

To use the plugin in a project:

1. Install via `claude plugin install pmm` from the marketplace, or
2. Symlink local skills into a project's `.claude/skills/` using `pmm:init-local-skills`

For development iteration: edit a SKILL.md, run `make local`, test in a target project.

See [DEVELOPMENT.md](DEVELOPMENT.md) for transform rules and symlink installation details.

## Troubleshooting

- **`make local` fails with "transform.sh: not found"**: Ensure you are running from the repo root. The Makefile expects `scripts/transform.sh` to exist relative to `$(pwd)`.
- **Skills not appearing in Claude Code**: Verify symlinks in the target project's `.claude/skills/` point to valid paths. Run `pmm:init-local-skills` to refresh.
- **Windows**: Symlinks require Developer Mode enabled. If unavailable, install via `claude plugin install pmm` from the marketplace.
- **Hook failures at session start**: Check that `hooks/session-start.sh` is executable and that the target project has a `memory/config.md` file.
