---
name: pmm:update
description: "Check for and apply updates to Poor Man's Memory system files from upstream. Compares local version to latest upstream, shows what changed, and applies updates to system files only — never touches memory/ or user data. Use when the user runs /pmm:update or asks to update PMM."
argument-hint: ""
---

# PMM Update

Check the upstream Poor Man's Memory repository for updates and apply them safely. System files (skills, templates, artifacts) are updated; user data (memory/) is never touched.

> **Note on update channels:** The Claude Code Plugin Marketplace handles binary plugin file replacement automatically. `pmm:update` handles *semantic* migration instructions — version-specific steps that go beyond file replacement, such as "v2.1 adds taxonomies.md, run pmm:hydrate after update" or config schema changes that require user action. Run `pmm:update` after a marketplace auto-update to apply any migration steps for the new version.

## Invocation

- `/pmm:update` — check for updates and apply if available

## Behaviour

### Phase 1 — Version check (subagent)

Dispatch a `general-purpose` agent with this prompt. Replace `<project-root>` with the actual project root path.

> Check for PMM updates. This is a READ-ONLY task with one exception: you may clone the upstream repo to /tmp.
>
> **Project root:** `<project-root>`
>
> ### Step 1 — Read local version
>
> Read `<project-root>/pmm/version.json`.
> - If exists: extract `version` string and `files.system` array
> - If missing: treat as version `0.0.0` with empty `files.system` array
>
> ### Step 2 — Clone upstream
>
> ```bash
> git clone --depth 1 https://github.com/NominexHQ/poor-man-memory.git /tmp/pmm-upstream-$$
> ```
>
> If this fails, return: `ERROR: Could not reach the upstream PMM repository. Check your network connection.`
>
> ### Step 3 — Compare versions
>
> Read `/tmp/pmm-upstream-$$/pmm/version.json`. Extract upstream `version` string.
>
> If versions match, clean up temp dir and return: `PMM is up to date (v{version})`
>
> ### Step 4 — Build change report
>
> For each file in upstream `files.system` array:
> - Exists locally AND differs → **M** (modified)
> - Does not exist locally → **A** (added)
> - Exists locally AND identical → unchanged (skip)
>
> For each file in local `files.system` NOT in upstream list → **D** (deleted)
>
> For merge files (`.claude/settings.json`): read both, count new permission entries in upstream.
>
> Return a structured report in this exact format:
> ```
> UPDATE_AVAILABLE
> LOCAL_VERSION: {version}
> UPSTREAM_VERSION: {version}
> TEMP_DIR: /tmp/pmm-upstream-{pid}
> ---
> M  .claude/plugins/pmm/skills/viz/SKILL.md
> A  .claude/plugins/pmm/skills/update/SKILL.md
> D  .claude/plugins/pmm/skills/old-skill/SKILL.md
> ~  .claude/settings.json (+2 permissions)
> =  8 unchanged
> ```
>
> Do NOT clean up the temp directory — it will be needed if the user approves.

### Phase 2 — Show report and confirm (main context)

If the agent returns "up to date" or "ERROR", output that message and stop.

If the agent returns `UPDATE_AVAILABLE`, parse the report and present it to the user:

```
PMM Update Available: v{local} → v{upstream}
══════════════════════════════════════════════

Changed files:
  M  .claude/plugins/pmm/skills/viz/SKILL.md
  A  .claude/plugins/pmm/skills/update/SKILL.md
  D  .claude/plugins/pmm/skills/old-skill/SKILL.md

Merge (additive only):
  ~  .claude/settings.json  (+2 permissions)

Unchanged: 8 files
Memory files: untouched (as always)
```

Ask the user using `AskUserQuestion`:
- **yes** — apply all changes
- **no** — cancel (clean up temp dir)
- **show diffs** — display diffs, then ask again

### Phase 3 — Apply updates (subagent)

If user approves, dispatch a `general-purpose` agent:

> Apply PMM upstream updates. This is a WRITE task. Do NOT run any git commands.
>
> **Upstream source:** `{temp_dir from phase 1 report}`
> **Project root:** `<project-root>`
>
> **System files to OVERWRITE** (copy from upstream, replacing local):
> [list each M and A file path]
>
> **System files to DELETE** (removed in upstream):
> [list each D file path]
>
> **Merge files** (additive only):
> - `.claude/settings.json`: Read both, merge `permissions.allow` entries and `hooks` object additively. Add missing entries/events, do NOT remove existing ones.
>
> **NEVER touch:**
> - Any file in `memory/`
> - `pmm/viz-cache.html`
> - `.claude/settings.local.json`
>
> **Instructions:**
> 1. For each OVERWRITE file: read upstream version, write to project path. Create parent dirs if needed.
> 2. For each DELETE file: delete it. Remove empty parent directories.
> 3. For merge file: read both, merge permissions additively, write back.
> 4. Return a summary of actions taken.

### Phase 4 — Post-update (main context)

1. **Check for new memory file types**: Compare upstream `${CLAUDE_PLUGIN_ROOT}/references/templates.md` to local. If new templates exist and user has `memory/` directory, create new files and trigger Phase 5 (Hydrate) per `${CLAUDE_PLUGIN_ROOT}/references/core.md`.

2. **Reinstall the pre-commit hook** (in case `pmm/hooks/pre-commit` was updated):
   ```bash
   cp pmm/hooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
   ```

3. **Commit**:
   ```bash
   git add .claude/plugins/ pmm/ README.md .gitignore .claude/settings.json
   git commit -m "pmm: update to v{new_version}"
   ```

4. **Clean up**:
   ```bash
   rm -rf {temp_dir}
   rm -f pmm/viz-cache.html
   ```

5. **Report** summary of what changed.

## Notes

- **Never touch `memory/`** — except to add new file types introduced by the update
- **Merge, don't replace** `settings.json` — the user may have custom permissions
- **File moves/renames** manifest as DELETE + ADD via the `files.system` array in `version.json`
- **Self-update**: This skill's SKILL.md gets overwritten. Takes effect next invocation.
- **Pre-versioning installs**: No `pmm/version.json` → treated as v0.0.0, full sync offered.
- **Viz cache**: Always deleted after update so `/pmm:viz` regenerates with latest template.
- **Marketplace vs pmm:update**: Marketplace auto-update handles binary file replacement. `pmm:update` handles migration steps (new memory file types, config schema changes, post-update hydration). Run both after a major version bump.
