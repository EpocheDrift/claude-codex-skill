#!/usr/bin/env bash
#
# sync-to-skill-repo.sh — Push local skill improvements to claude-codex-skill on GitHub.
#
# Usage:
#   bash .claude/skills/orchestrate/scripts/sync-to-skill-repo.sh "skill: what changed"
#
# Run from your project root (where .claude/ and .agents/ live).
# Clones the skill repo, copies updated skill files, commits, pushes, cleans up.
# Does NOT sync performance_log.jsonl or improvement_history.md (those are project-specific).

set -euo pipefail

MSG="${1:?Usage: sync-to-skill-repo.sh \"commit message\"}"
SKILL_REPO="git@github.com:EpocheDrift/claude-codex-skill.git"
TMP="/tmp/skill-sync-$$"

# Resolve skill root relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_ROOT="$(cd "$(pwd)/.agents/skills/claude-orchestrated" 2>/dev/null && pwd || true)"

echo "=== Syncing skill to GitHub ==="
echo "  Source:      $SKILL_ROOT"
echo "  Destination: $SKILL_REPO"
echo ""

# Clone skill repo
echo "Cloning claude-codex-skill..."
git clone -q "$SKILL_REPO" "$TMP"

# Copy skill files (exclude project-specific: performance_log, improvement_history)
cp "$SKILL_ROOT/SKILL.md"                          "$TMP/.claude/skills/orchestrate/"
cp "$SKILL_ROOT/scripts/validate-contract.sh"      "$TMP/.claude/skills/orchestrate/scripts/"
cp "$SKILL_ROOT/scripts/measure-tokens.sh"         "$TMP/.claude/skills/orchestrate/scripts/"
cp "$SCRIPT_DIR/sync-to-skill-repo.sh"             "$TMP/.claude/skills/orchestrate/scripts/"
cp "$SKILL_ROOT/assets/api_contract_template.md"   "$TMP/.claude/skills/orchestrate/assets/"
cp "$SKILL_ROOT/references/workflow.md"            "$TMP/.claude/skills/orchestrate/references/"

if [ -n "$AGENTS_ROOT" ] && [ -f "$AGENTS_ROOT/SKILL.md" ]; then
  cp "$AGENTS_ROOT/SKILL.md" "$TMP/.agents/skills/claude-orchestrated/"
fi

# Stage everything, then show what changed
cd "$TMP"
git add .

echo "=== Changes ==="
git diff --cached --stat

# Check if anything actually changed
if git diff --cached --quiet; then
  echo ""
  echo "No changes detected — skill repo is already up to date."
  rm -rf "$TMP"
  exit 0
fi
git commit -m "$MSG

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push

echo ""
echo "✓ Pushed to $SKILL_REPO"
echo "✓ Cleaned up $TMP"
rm -rf "$TMP"
