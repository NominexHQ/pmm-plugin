# Pipeline

## Status

This repo uses manual dispatch with automated enforcement hooks. No CI/CD platform
is currently configured. Automation candidates: PR creation (pre-git-pr bot),
PR review and merge (pre-git-review bot), release analysis (pre-release-maintainer bot),
`make check` as a required CI check on PRs.

## Stages

### 1. Task Brief

- **Trigger**: Strategic need, sprint plan, or ad-hoc request
- **Actor**: Coordinator (Vera)
- **Input**: Goal or direction, team state, prior decisions
- **Output**: Task brief (what, constraints, context)
- **Success criteria**: Brief is scoped, constraints stated, context references valid
- **Failure handling**: QA flags ambiguities during criteria design

### 2. Acceptance Criteria

- **Trigger**: Task brief delivered
- **Actor**: QA (Harlow)
- **Input**: Task brief
- **Output**: Acceptance criteria and test plan
- **Success criteria**: Criteria are testable, trace to brief requirements
- **Failure handling**: Escalate to coordinator for brief revision

### 3. Build

- **Trigger**: Acceptance criteria delivered
- **Actor**: Engineering (Leith) + pre-code-builder bot for delegated work
- **Input**: Task brief + acceptance criteria
- **Output**: Code changes on a build branch
- **Success criteria**: Code meets acceptance criteria. `make local` run.
- **Failure handling**: Engineering reports blockers to coordinator
- **Enforcement gates**: Gates 1-2 are candidates for this repo (same `skills/` to `local/` build pattern as vera-plugin) but not yet implemented

### 4. Acceptance Testing

- **Trigger**: Engineering signals build complete
- **Actor**: QA (Harlow)
- **Input**: Build branch + acceptance criteria
- **Output**: Test results (pass/fail per criterion)
- **Success criteria**: All criteria pass
- **Failure handling**: QA reports failure, engineering fixes, re-test

### 5. PR Submission

- **Trigger**: QA reports acceptance PASS
- **Actor**: pre-git-pr bot
- **Input**: Build branch, PR metadata
- **Output**: PR created on GitHub
- **Success criteria**: PR open, correctly targeted, properly labeled
- **Failure handling**: Bot reports failure, escalate to coordinator

### 6. PR Review and Merge

- **Trigger**: PR exists and ready for review
- **Actor**: pre-git-review bot
- **Input**: PR number, merge criteria
- **Output**: Merge result or blocked status
- **Success criteria**: PR merged to main, local clone synced
- **Failure handling**: CI failures escalate to engineering, conflict to engineering, permission issues to coordinator

## Bot Roles

### pre-git-pr
- **Function**: Raises a PR from a build branch
- **Invoked when**: QA passes acceptance tests
- **Reads**: Build branch, PR metadata from caller
- **Writes**: PR on GitHub (URL, number)
- **Scope boundary**: Creates PRs only. Does not merge, approve, or modify code.

### pre-git-review
- **Function**: Reviews open PRs, checks merge criteria, merges if met
- **Invoked when**: PR created or on-demand scan
- **Reads**: PR status (CI, reviews, conflicts)
- **Writes**: Merge action on GitHub
- **Scope boundary**: Checks and merges only. Does not approve or fix code.

### pre-code-builder
- **Function**: Builds or modifies code per task brief
- **Invoked when**: Build-request dispatch
- **Reads**: Build brief (what to create/modify)
- **Writes**: Code within scoped paths
- **Scope boundary**: Writes code only. Never commits to git.

### pre-release-maintainer
- **Function**: Analyzes commits since last release, recommends version bump
- **Invoked when**: Release-check dispatch
- **Reads**: Commit history, last release tag
- **Writes**: Release report (recommendation only)
- **Scope boundary**: Read-only. Never creates tags or pushes.

### pre-dev-release
- **Function**: Merges PRs, syncs clones, bumps SHA references
- **Invoked when**: Release-merge dispatch
- **Reads**: PR numbers, repo state
- **Writes**: Merge actions, SHA file edits
- **Scope boundary**: Executes git commands. Does not force-push or delete branches.

### pre-git-ship
- **Function**: Checks working tree ship-readiness
- **Invoked when**: Ship-check dispatch
- **Reads**: Repository state
- **Writes**: Ship Readiness Report
- **Scope boundary**: Read-only.

### pre-git-merge
- **Function**: Checks open PR merge-readiness
- **Invoked when**: Merge-check dispatch
- **Reads**: PR status (CI, reviews, conflicts)
- **Writes**: PR Status Report
- **Scope boundary**: Read-only.

### pre-docs-maintainer
- **Function**: Scans docs for staleness
- **Invoked when**: Docs-check dispatch
- **Reads**: Documentation files
- **Writes**: Docs Health Report
- **Scope boundary**: Read-only.

## Escalation

1. Bot failure (API error, permission) -> Coordinator (Vera) retries or resolves manually
2. CI check failure -> Engineering (Leith) fixes code
3. Merge conflict -> Engineering (Leith) resolves
4. Acceptance test failure -> Engineering fixes, QA re-tests
5. Brief ambiguity -> QA flags to Coordinator for revision

## Build Artifacts

- `local/` contains generated local skill variants. `make local` should run before
  commit and push. Stale `local/` means downstream `init-local-skills` symlinks
  point to old content.
- Gates 1-2 (pre-commit freshness and version consistency) are candidates for this
  repo but not yet implemented. The same `skills/` to `local/` build pattern applies.

## Releases

- Tagged by: Coordinator
- Format: `vX.Y.Z`
- CHANGELOG.md must be updated before tagging
- After release: skill-directory SHA bump triggers marketplace maintenance pipeline

For the full bot fleet contracts and escalation paths, see the
[S82 Pipeline Specification](https://github.com/NominexHQ/nominex-hq/blob/master/work/deliberations/S82-pipeline-spec.md).
