#!/usr/bin/env bash
# R-005: Pre-commit identity check hook
# Blocks commits where author or committer email doesn't match *noreply* pattern.
# 5 identity leaks across 42 sessions — this makes it mechanical.
#
# Install:
#   ln -sf ../../hooks/pre-commit-identity-check.sh .git/hooks/pre-commit
#   — or chain from an existing pre-commit hook by sourcing this script.
#
# Works on macOS and Linux. No external dependencies.

set -euo pipefail

ERRORS=0

# ── Resolve author email ────────────────────────────────────────────────────
# Priority: GIT_AUTHOR_EMAIL env var > git config user.email
# When --author="Name <email>" is used, git sets GIT_AUTHOR_EMAIL before hooks fire.

AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-$(git config user.email 2>/dev/null || echo "")}"
COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$(git config user.email 2>/dev/null || echo "")}"

# ── Check author email ──────────────────────────────────────────────────────

if [ -z "$AUTHOR_EMAIL" ]; then
  echo "BLOCKED: No author email configured."
  echo "   Set a noreply email: git config user.email \"<id>+<user>@users.noreply.github.com\""
  ERRORS=$((ERRORS + 1))
elif [[ "$AUTHOR_EMAIL" != *noreply* ]]; then
  echo "BLOCKED: Author email is not a noreply address."
  echo "   Got:    $AUTHOR_EMAIL"
  echo "   Fix:    git commit --author=\"Name <ID+user@users.noreply.github.com>\""
  echo "   Or set: git config user.email \"<id>+<user>@users.noreply.github.com\""
  ERRORS=$((ERRORS + 1))
fi

# ── Check committer email ───────────────────────────────────────────────────

if [ -z "$COMMITTER_EMAIL" ]; then
  echo "BLOCKED: No committer email configured."
  echo "   Set a noreply email: git config user.email \"<id>+<user>@users.noreply.github.com\""
  ERRORS=$((ERRORS + 1))
elif [[ "$COMMITTER_EMAIL" != *noreply* ]]; then
  echo "BLOCKED: Committer email is not a noreply address."
  echo "   Got:    $COMMITTER_EMAIL"
  echo "   Fix:    GIT_COMMITTER_EMAIL=\"<id>+<user>@users.noreply.github.com\" git commit ..."
  echo "   Or set: git config user.email \"<id>+<user>@users.noreply.github.com\""
  ERRORS=$((ERRORS + 1))
fi

# ── Result ───────────────────────────────────────────────────────────────────

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "Commit blocked by identity check (R-005). All commits must use noreply emails."
  echo "To bypass (not recommended): git commit --no-verify"
  exit 1
fi

exit 0
