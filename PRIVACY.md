# Privacy Policy

PMM (Poor Man's Memory) is a local-first plugin. Your data stays on your machine.

## Data Storage

- All memory files live in `memory/` inside your project directory. Plain markdown. You can read, edit, or delete any of them.
- No data is transmitted to external servers. The plugin has no backend, no API, no cloud sync.

## No Telemetry

- No analytics. No tracking. No usage metrics. No phone-home. Zero network calls during normal operation.

## Git

- Git commits are local. PMM never pushes to a remote unless you do it yourself.
- Auto-push is off by default. Your memory stays in your local repo until you explicitly push.

## Secrets

- `secrets.md` is gitignored by default. It is never committed to version control unless you deliberately change this setting.

## Network

- The only network operation is `pmm:update`, which clones the upstream repo to check for new versions. This is user-initiated — it never runs automatically.

## File Access

- PMM does not access, read, or modify files outside the `memory/` directory and its own plugin files.
- The plugin runs within Claude Code's permission model. All file operations require permissions you have explicitly granted.

## Ownership

- Your memory files are yours. They are plain text in a directory you control. There is no lock-in, no proprietary format, no export step. Delete the `memory/` folder and the data is gone.
