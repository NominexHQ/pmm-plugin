# Testing

## QA Process

This repo follows the Build & Release Dispatch Flow (D-010):

1. Task briefs define intent and constraints
2. QA designs acceptance criteria and test plans from the brief
3. Engineering builds against the brief and QA criteria
4. QA runs acceptance tests and reports pass/fail

Acceptance criteria exist before the build starts. QA defines "done."

## Test Architecture

- Framework: Bash test runners (`tests/test-hook-loading.sh`, `tests/test-load-strategies.sh`)
- Test directory: `tests/`
- Naming convention: `test-*.sh`
- Categories: hook loading validation, load strategy verification

The test suite validates that the SessionStart hook correctly loads memory files
according to configured load strategies (`full`, `tail:N`, `header`, `skip`).

## Running Tests

```bash
# Hook loading tests
bash tests/test-hook-loading.sh

# Load strategy tests
bash tests/test-load-strategies.sh
```

A passing run outputs individual test results followed by a summary line with the
pass/fail count.

Failures are reported inline with the test name and expected vs actual values.

## Coverage

Target: all hook behaviors and load strategies validated. No code coverage percentage
applies since this is a skill plugin (markdown + bash), not a compiled codebase.

Coverage scope:
- SessionStart hook loading for each configured file
- Load strategy correctness (`full`, `tail:N`, `header`, `skip`)
- Config parsing from `memory/config.md`

## Writing Tests

- New tests go in `tests/`
- Test files follow the pattern `test-*.sh`
- Each new hook behavior or load strategy must have a corresponding test
- All code PRs must include corresponding test files (R-003)

## Acceptance Testing

- Acceptance criteria are authored by QA per the D-010 flow before engineering begins
- Criteria documents are maintained in the sprint coordination repo, not in this repo
- Results are reported as pass/fail per criterion in the PR description
- Structural tests are a pre-flight check, not a substitute for acceptance testing
