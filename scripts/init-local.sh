#!/usr/bin/env bash
# init-local.sh — Symlink local skill variants into a project's .claude/skills/.
# Generic: works for any plugin that ships a local/ directory.
#
# Usage: init-local.sh [--force] <plugin-root> <target-skills-dir>
#
#   plugin-root       Path to the plugin installation (must contain local/)
#   target-skills-dir Path to .claude/skills/ in the project
#   --force           Overwrite standalone copies / wrong-target symlinks

set -euo pipefail

# --- Parse args ---
FORCE=0
POSITIONAL=()

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

if [ "${#POSITIONAL[@]}" -lt 2 ]; then
  echo "Usage: init-local.sh [--force] <plugin-root> <target-skills-dir>" >&2
  exit 1
fi

PLUGIN_ROOT="${POSITIONAL[0]}"
TARGET_DIR="${POSITIONAL[1]}"

# --- Validate ---
LOCAL_DIR="$PLUGIN_ROOT/local"

if [ ! -d "$LOCAL_DIR" ]; then
  echo "No local/ directory found at $PLUGIN_ROOT. Nothing to do."
  exit 0
fi

# --- Collect skills ---
SKILLS=()
for dir in "$LOCAL_DIR"/*/; do
  [ -f "${dir}SKILL.md" ] && SKILLS+=("$(basename "$dir")")
done

if [ ${#SKILLS[@]} -eq 0 ]; then
  echo "No skills with SKILL.md found in $LOCAL_DIR. Nothing to do."
  exit 0
fi

# --- Process each skill ---
LINKED=()
SKIPPED=()
OVERWRITTEN=()
WARNED=()

for skill in "${SKILLS[@]}"; do
  src_dir="$LOCAL_DIR/$skill"
  tgt_dir="$TARGET_DIR/$skill"

  # Collect all linkable items: SKILL.md + any asset dirs/files
  ITEMS=()
  [ -f "$src_dir/SKILL.md" ] && ITEMS+=("SKILL.md")
  for item in "$src_dir"/*/; do
    [ -d "$item" ] && ITEMS+=("$(basename "$item")")
  done
  # Also catch non-directory files other than SKILL.md
  for item in "$src_dir"/*; do
    [ -f "$item" ] && [ "$(basename "$item")" != "SKILL.md" ] && ITEMS+=("$(basename "$item")")
  done

  did_link=0
  did_skip=0
  did_overwrite=0
  did_warn=0

  for item in "${ITEMS[@]}"; do
    src_item="$src_dir/$item"
    tgt_item="$tgt_dir/$item"

    # Compute relative path from target to source
    rel_path=$(python3 -c "import os.path; print(os.path.relpath('$src_item', '$tgt_dir'))")

    if [ ! -e "$tgt_item" ] && [ ! -L "$tgt_item" ]; then
      # Case A: doesn't exist — link it
      mkdir -p "$tgt_dir"
      ln -s "$rel_path" "$tgt_item"
      did_link=1

    elif [ -L "$tgt_item" ]; then
      existing=$(readlink "$tgt_item")
      if [ "$existing" = "$rel_path" ]; then
        # Case B: correct symlink — skip
        did_skip=1
      else
        # Case D: wrong symlink
        if [ "$FORCE" -eq 1 ]; then
          rm "$tgt_item"
          ln -s "$rel_path" "$tgt_item"
          did_overwrite=1
        else
          did_warn=1
        fi
      fi

    else
      # Case C: standalone file/dir (not a symlink)
      if [ "$FORCE" -eq 1 ]; then
        rm -rf "$tgt_item"
        ln -s "$rel_path" "$tgt_item"
        did_overwrite=1
      else
        did_warn=1
      fi
    fi
  done

  # Categorise skill by worst-case item outcome
  if [ "$did_warn" -eq 1 ]; then
    WARNED+=("$skill")
  elif [ "$did_overwrite" -eq 1 ]; then
    OVERWRITTEN+=("$skill")
  elif [ "$did_link" -eq 1 ]; then
    LINKED+=("$skill")
  else
    SKIPPED+=("$skill")
  fi
done

# --- Report ---
echo "init-local — done"
echo ""

join_arr() { local out="$1"; shift; for x in "$@"; do out="$out, $x"; done; echo "$out"; }

[ ${#LINKED[@]} -gt 0 ]      && echo "  linked:               $(join_arr "${LINKED[@]}")"
[ ${#SKIPPED[@]} -gt 0 ]     && echo "  already linked:       $(join_arr "${SKIPPED[@]}")"
[ ${#OVERWRITTEN[@]} -gt 0 ] && echo "  overwritten:          $(join_arr "${OVERWRITTEN[@]}")"
[ ${#WARNED[@]} -gt 0 ]      && echo "  skipped (standalone): $(join_arr "${WARNED[@]}") (use --force)"

TOTAL=$(( ${#LINKED[@]} + ${#SKIPPED[@]} + ${#OVERWRITTEN[@]} + ${#WARNED[@]} ))
echo ""
echo "  Total: $TOTAL skills processed"
