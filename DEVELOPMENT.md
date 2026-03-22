# Development

## Build local skill variants

Plugin skills are canonical (colon-prefixed: `pmm:save`). Local variants
(dash-prefixed: `pmm-save`, with trigger phrases) are generated for Cowork
compatibility.

    make local        # generate local/ from skills/
    make clean        # remove local/

`make local` runs `scripts/transform.sh` on each skill directory in `skills/`
(excluding `init-local-skills`), outputting to `local/pmm-<name>/`.

## Transform rules

`scripts/transform.sh <source> <dest> <dash-name> <short-name>`:

- `pmm:` to `pmm-` in name, description, and body
- `argument-hint` replaced with `trigger-phrase` description (mapped per skill)
- `description` gets trigger phrase list appended
- Asset directories (`assets/`) copied as-is

## Symlink installation

`scripts/init-local.sh [--force] <plugin-root> <target-skills-dir>`:

- Creates relative symlinks from `.claude/skills/pmm-*` to `local/pmm-*`
- Idempotent: skips correct symlinks, warns on standalone copies
- `--force` overwrites standalone copies and wrong-target symlinks
- Generic: works for any plugin with a `local/` directory

Both `vera:init-local-skills` and `pmm:init-local-skills` invoke this script.

## Release workflow

1. Edit plugin skills in `skills/`
2. `make local`
3. Verify `local/` output
4. Commit both `skills/` and `local/`
5. Push to NominexHQ/pmm-plugin
6. Bump SHA in nominex-marketplace
