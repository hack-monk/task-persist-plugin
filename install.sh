#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"
HOOK_CMD="bash \"$PLUGIN_DIR/hooks/task-persist.sh\""
STATUSLINE_CMD="bash \"$PLUGIN_DIR/statusline.sh\""

echo "Installing task-persist plugin from: $PLUGIN_DIR"

# Ensure settings file exists
if [ ! -f "$SETTINGS" ]; then
  mkdir -p "$(dirname "$SETTINGS")"
  echo '{}' > "$SETTINGS"
fi

# Validate JSON
if ! jq empty "$SETTINGS" 2>/dev/null; then
  echo "ERROR: $SETTINGS is not valid JSON. Fix it before installing." >&2
  exit 1
fi

chmod +x "$PLUGIN_DIR/statusline.sh"
chmod +x "$PLUGIN_DIR/hooks/task-persist.sh"

# Detect existing statusLine — save as delegate if present and not already ours
existing_statusline=$(jq -r '.statusLine.command // empty' "$SETTINGS")
if [ -n "$existing_statusline" ] && [ "$existing_statusline" != "$STATUSLINE_CMD" ]; then
  echo "Existing statusLine detected: $existing_statusline"
  echo "Saving as CLAUDE_STATUSLINE_DELEGATE."
  tmp=$(mktemp)
  jq --arg cmd "$existing_statusline" '.env.CLAUDE_STATUSLINE_DELEGATE = $cmd' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
fi

# Set statusLine
tmp=$(mktemp)
jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

# Add UserPromptSubmit hook (skip if already present)
already=$(jq -r --arg cmd "$HOOK_CMD" '
  .hooks.UserPromptSubmit[]?.hooks[]?
  | select(.type == "command" and .command == $cmd)
  | "found"
' "$SETTINGS" 2>/dev/null || true)

if [ "$already" = "found" ]; then
  echo "Hook already installed, skipping."
else
  tmp=$(mktemp)
  jq --arg cmd "$HOOK_CMD" '
    .hooks.UserPromptSubmit = ([
      {
        "hooks": [
          {
            "type": "command",
            "command": $cmd,
            "timeout": 5,
            "statusMessage": "Checking task state..."
          }
        ]
      }
    ] + (.hooks.UserPromptSubmit // []))
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
fi

echo ""
echo "✓ task-persist installed."
echo "  Statusline : $STATUSLINE_CMD"
echo "  Hook       : $HOOK_CMD"
echo ""
echo "Start a persistent task: tell Claude to use the start-task skill."
echo "Reload Claude Code (open /hooks or restart) for changes to take effect."
