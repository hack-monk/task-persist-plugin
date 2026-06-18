#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="bash \"$PLUGIN_DIR/hooks/task-persist.sh\""

echo "Uninstalling task-persist plugin..."

if [ ! -f "$SETTINGS" ]; then
  echo "No settings file found, nothing to do."
  exit 0
fi

# Restore delegate statusline if saved
delegate=$(jq -r '.env.CLAUDE_STATUSLINE_DELEGATE // empty' "$SETTINGS")
tmp=$(mktemp)
if [ -n "$delegate" ]; then
  echo "Restoring previous statusLine: $delegate"
  jq --arg cmd "$delegate" '
    .statusLine.command = $cmd |
    del(.env.CLAUDE_STATUSLINE_DELEGATE)
  ' "$SETTINGS" > "$tmp"
else
  echo "Removing statusLine config."
  jq 'del(.statusLine)' "$SETTINGS" > "$tmp"
fi
mv "$tmp" "$SETTINGS"

# Remove hook entry
tmp=$(mktemp)
jq --arg cmd "$HOOK_CMD" '
  if .hooks.UserPromptSubmit then
    .hooks.UserPromptSubmit = [
      .hooks.UserPromptSubmit[]
      | .hooks = [.hooks[] | select(.command != $cmd)]
      | select(.hooks | length > 0)
    ]
    | if (.hooks.UserPromptSubmit | length) == 0 then del(.hooks.UserPromptSubmit) else . end
  else . end
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

rm -f /tmp/claude-context-pct /tmp/claude-reset-at

echo ""
echo "✓ task-persist uninstalled."
echo "Reload Claude Code (open /hooks or restart) for changes to take effect."
