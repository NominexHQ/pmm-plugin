---
name: pmm:init-local-skills
description: >
  Install local skill variants for Cowork compatibility. Creates symlinks from
  .claude/skills/pmm-* to pre-built cached local skills shipped with the plugin.
  Run once per project. Idempotent.
argument-hint: "[--force to overwrite existing]"
---

# pmm:init-local-skills

Symlinks pre-built local skill variants into `.claude/skills/` so PMM skills work in Cowork (no private marketplace plugin support there).

**When to run:** Once per project. Safe to re-run — idempotent.

---

## Instructions

1. Resolve the plugin root. This skill file lives at `<plugin-root>/skills/init-local-skills/SKILL.md` — the plugin root is two directories up.

2. Resolve the project's `.claude/skills/` directory (the project root that contains `.claude/`).

3. Run the init-local script:

```bash
"<plugin-root>/scripts/init-local.sh" <plugin-root> <project-root>/.claude/skills
```

If the user passed `--force` in `$ARGUMENTS`, include the flag:

```bash
"<plugin-root>/scripts/init-local.sh" --force <plugin-root> <project-root>/.claude/skills
```

4. Report the script output to the user.

---

## Rules

- Relative symlinks only. The script handles this.
- Never modify files in `local/`. Read-only source.
- Never modify existing plugin skills in `skills/`.
- Idempotent. Running twice with no changes produces all skips.
- `--force` only affects standalone copies and wrong-target symlinks. Correct symlinks are always skipped.
