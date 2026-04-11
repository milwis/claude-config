#!/bin/bash
# Sync local agents and skills to the marketplace repo
# Usage: bash scripts/sync-from-local.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_DIR="$REPO_DIR/plugins/milwis-coding-toolkit"

echo "Syncing agents from ~/.claude/agents/ ..."
cp ~/.claude/agents/*.md "$PLUGIN_DIR/agents/" 2>/dev/null
echo "  Copied $(ls "$PLUGIN_DIR/agents/"*.md 2>/dev/null | wc -l) agents"

echo "Syncing skills from ~/.claude/skills/lang-guidelines/ ..."
cp -r ~/.claude/skills/lang-guidelines "$PLUGIN_DIR/skills/" 2>/dev/null
echo "  Done"

echo ""
echo "Review changes with: git diff"
echo "Then commit:         git add -A && git commit -m 'Update agents' && git push"
