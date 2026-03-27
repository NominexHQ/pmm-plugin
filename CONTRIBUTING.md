# Contributing

## Branch Model

All changes to this repository go through pull requests. Direct commits to `main` are
not permitted (D-001). This applies to all change types including mechanical updates,
version bumps, and SHA reference changes.

- Branch from `main`
- Use branch naming convention: `feat/`, `fix/`, `chore/`, `docs/` prefixes
- Coordinator merges only — do not merge your own PRs

## Commit Conventions

- Commit messages: `type: description` (e.g., `feat: add pmm:viz skill`, `fix: hook loading`)
- All commits must use noreply email addresses (R-005)
- Agent-assisted commits include co-authorship attribution

## Pull Request Process

1. Create a branch from `main`
2. Make changes and commit
3. Run `make local` to regenerate local skill variants
4. Open a pull request
5. QA reviews against acceptance criteria
6. Coordinator merges after approval
7. If working from a local clone: stash, pull merged changes, unstash

Code PRs must include corresponding test files. Non-code PRs must include a
verification justification in the PR description (R-003).

### Post-merge

After a PR merges:
- Pull the updated `main` into your local clone
- If the plugin SHA changed, the skill-directory may need a bump (handled by the marketplace maintenance pipeline)

## What Constitutes a Contribution

- New or modified skills (SKILL.md files in `skills/`)
- Transform script changes (`scripts/`)
- Hook additions or updates (`hooks/`)
- Test additions or updates (`tests/`)
- Documentation updates
- Configuration changes

## External Contributions

This is a public repository. External contributions are welcome via fork and pull request.
All PRs are reviewed by the maintainer team before merge. External contributors should:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with a clear description of changes
4. Include test coverage for new functionality

## Code of Conduct

Be respectful, constructive, and focused on improving the project. Harassment,
discrimination, and bad-faith behavior are not tolerated.
