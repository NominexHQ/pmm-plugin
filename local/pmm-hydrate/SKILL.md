---
name: pmm-hydrate
description: >
  Populate empty or thin memory files from current session context. Supports single file,
  batch, and force re-hydration. Trigger on: "pmm-hydrate", "/pmm-hydrate", "hydrate memory",
  "populate memory", "fill in memory files", "hydrate files", "backfill memory", or any request
  to populate empty or thin memory files from existing context.
---
# pmm-hydrate

Populate empty or thin memory files from existing session context and loaded memory. Use when:
- A new memory file was added (via `pmm-update`) but the `memory/` directory already has populated files
- A previously deactivated file is re-activated via `pmm-settings`
- A file exists but contains only template boilerplate — no real content

**This is not a greenfield operation.** If memory files are already populated, they contain history that should inform every new file. Hydrate before the first maintain cycle runs on a new file. An empty file that gets maintained stays shallow. A hydrated file starts with the full context the system already has.

---

## Argument Parsing

Parse `$ARGUMENTS`:

| Argument | Mode |
|----------|------|
| _(no args)_ | Show usage hint |
| `--all` or `all` | Batch mode — hydrate all template-only files |
| `<filename>` | Single file mode — hydrate one named file |
| `<filename> --force` or `--force <filename>` | Force mode — re-hydrate even if file has content |
| `--all --force` | Force batch mode — re-hydrate all active files |

Read `memory/config.md` to determine which files are active. Only operate on active files.

---

## No-Args: Usage Hint

If `$ARGUMENTS` is empty, output usage and list active files:

```
pmm-hydrate — populate memory files from existing context

Usage:
  pmm-hydrate --all            hydrate all empty/stub files
  pmm-hydrate <file>           hydrate one file (e.g. voices.md)
  pmm-hydrate <file> --force   re-hydrate even if already populated
  pmm-hydrate --all --force    re-hydrate all active files

Active files (from memory/config.md):
  [list active files with status: populated / template-only / empty]
```

Read each active file. A file is "template-only" if, after stripping blank lines, comment lines (`<!--`), and heading lines (`#`), it has fewer than 3 lines of content.

---

## Template-Only Detection

Before dispatching any agent, read each candidate file and classify:

```
Read memory/<file>
Strip: blank lines, comment lines (<!-- ... -->), heading lines (# ...)
Count remaining content lines
If count < 3 → template-only (candidate for hydration)
If count ≥ 3 → populated (skip unless --force)
```

Apply this check in main context — no agent needed for detection.

---

## Single File Mode

One file specified, no `--force`.

1. Check if the file is template-only. If populated (≥ 3 content lines), output:
   ```
   memory/<file> already has content. Use --force to re-hydrate.
   ```
   Stop.

2. If template-only (or `--force`), dispatch a **single foreground agent** (not background — agents need Edit/Write permissions):

   > Hydrate a memory file from existing memory. This is a WRITE task — edit the target file only. Do NOT run git commands.
   >
   > **Target file:** `memory/<filename>`
   > **Purpose:** `<what this file captures — infer from filename and core.md>`
   > **Template structure:** Read `${CLAUDE_PLUGIN_ROOT}/references/templates.md` for the correct format for this file type before writing.
   >
   > **Instructions:**
   > 1. Read `${CLAUDE_PLUGIN_ROOT}/references/templates.md` and locate the template for `<filename>`. Use it as the structural skeleton for your output — follow its format exactly.
   > 2. Read ALL populated memory files to build context:
   >    - `memory/timeline.md`, `memory/summaries.md` — what happened over time
   >    - `memory/decisions.md` — what was decided and why
   >    - `memory/lessons.md` — what went wrong and what to do instead
   >    - `memory/preferences.md` — how the user works
   >    - `memory/processes.md` — established workflows
   >    - `memory/standinginstructions.md` — persistent rules
   >    - `memory/memory.md` — long-term facts
   >    - `memory/assets.md` — people, tools, systems
   >    - `memory/graph.md`, `memory/vectors.md` — relationships and similarities
   >    - `memory/last.md`, `memory/progress.md` — recent context
   >    Skip any file that doesn't exist or is template-only — no useful signal there.
   > 3. Infer content for `memory/<filename>` based on what the existing files reveal.
   >    - Do not copy content verbatim — synthesise. Each file has one job.
   >    - Only add entries you can justify from the existing memory. Never hallucinate.
   >    - Use `[system:hydrate]` as the attribution tag for all hydrated entries (applies to decisions.md, timeline.md, lessons.md, standinginstructions.md, last.md).
   > 4. Write the inferred content to `memory/<filename>`.
   > 5. Return a brief summary: what was inferred and which source files informed it.

   Use `Maintain Agent Model` from `memory/config.md` as the agent model. Default: haiku.

3. After the agent returns, main context commits:
   ```bash
   git add memory/<filename> && git commit -m "memory: hydrate <filename> from existing memory"
   ```

4. Report what was hydrated.

---

## Batch Mode (`--all`)

Two or more files need hydrating. Use a **single agent** — reads context once, writes all targets. More efficient than one agent per file.

1. Scan all active files (from `memory/config.md`). Classify each as template-only or populated (see detection logic above).

2. If `--force` is NOT set: collect only template-only files as targets. If no template-only files found:
   ```
   All active files are already populated. Use --force to re-hydrate.
   ```
   Stop.

3. If `--force` IS set: all active files are targets (excluding `secrets.md` — always excluded, never touched).

4. Report targets before dispatching:
   ```
   Hydrating <N> files: <file1>, <file2>, ...
   ```

5. Dispatch a **single foreground agent**:

   > Hydrate multiple memory files from existing memory. This is a WRITE task — edit the target files only. Do NOT run git commands.
   >
   > **Target files:** `<comma-separated list>`
   > **References directory:** `${CLAUDE_PLUGIN_ROOT}/references/`
   >
   > **Instructions:**
   > 1. Read `${CLAUDE_PLUGIN_ROOT}/references/templates.md`. For each target file, locate its template section and use it as the structural skeleton.
   > 2. Read ALL populated memory files to build context:
   >    - `memory/timeline.md`, `memory/summaries.md` — what happened over time
   >    - `memory/decisions.md` — what was decided and why
   >    - `memory/lessons.md` — what went wrong and what to do instead
   >    - `memory/preferences.md` — how the user works
   >    - `memory/processes.md` — established workflows
   >    - `memory/standinginstructions.md` — persistent rules
   >    - `memory/memory.md` — long-term facts
   >    - `memory/assets.md` — people, tools, systems
   >    - `memory/graph.md`, `memory/vectors.md` — relationships and similarities
   >    - `memory/last.md`, `memory/progress.md` — recent context
   >    Skip non-existent or template-only files — no useful signal there.
   > 3. For EACH target file, infer appropriate content from the existing files.
   >    - Do not copy content verbatim — synthesise. Each file has one job.
   >    - Use the correct format from templates.md for each file type.
   >    - Only add entries you can justify from existing memory. Never hallucinate.
   >    - Use `[system:hydrate]` as the attribution tag for all hydrated entries (applies to decisions.md, timeline.md, lessons.md, standinginstructions.md, last.md).
   >    - Special rules per file:
   >      - `graph.md` edges are append-only — write new edges only, never modify existing entries
   >      - `vectors.md` embedding registry is append-only — clusters/similarities are living
   >      - `decisions.md`, `lessons.md`, `standinginstructions.md` are append-only — write new entries only
   >      - `last.md` is always replaced entirely — write the full current-state window
   > 4. Write inferred content to each target file.
   > 5. Return a brief summary per file: what was inferred and which source files contributed.

   Use `Maintain Agent Model` from `memory/config.md`. Default: haiku.

6. After the agent returns, main context commits:
   ```bash
   git add memory/ && git reset HEAD memory/secrets.md 2>/dev/null; git commit -m "memory: hydrate <file1>, <file2>, ... from existing memory"
   ```

7. Report the summary per file.

---

## Force Mode

`--force` with a single file: skip the template-only check, always dispatch the agent. Useful when a file has content but it's stale or thin.

`--force` with `--all`: re-hydrate every active file, whether populated or not.

In force mode, the agent prompt is identical — the distinction is only in whether the detection gate fires.

---

## Rules

- `secrets.md` is never touched — excluded from all hydration operations, batch or single
- `config.md` is never a hydration target — it controls the system, not records history
- Agents edit files only — main context handles all git commits
- Background agents (`run_in_background: true`) do not inherit Edit/Write permissions — always dispatch as foreground agents
- For batch mode, dispatch ONE agent for all targets — do not dispatch one agent per file (reads context once, writes all targets)
- Only hydrate files marked active in `memory/config.md`
- If a file does not exist yet, create it from the template in `${CLAUDE_PLUGIN_ROOT}/references/templates.md` before dispatching the hydration agent
- Hydrate before the first maintain cycle touches a new file — empty files that get maintained stay shallow

---

## After Hydration

After hydration, the new file will be picked up automatically by the SessionStart hook if it's listed as active in config.md. No CLAUDE.md changes needed — hooks handle loading.
