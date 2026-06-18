#!/usr/bin/env bash
# task-persist hook — fires on UserPromptSubmit
# Only acts if TASK.md exists in current working directory.
# At >= 90% context: injects instructions to write HANDOFF.md + schedule continuation.

# Read cwd from hook JSON stdin
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"

# Only act if a persistent task is active
[ ! -f "$cwd/TASK.md" ] && exit 0

# Read context %
[ ! -f /tmp/claude-context-pct ] && exit 0
used_int=$(cat /tmp/claude-context-pct)
[ -z "$used_int" ] && exit 0

[ "$used_int" -lt 90 ] && exit 0

# Read reset time
reset_seconds=""
if [ -f /tmp/claude-reset-at ]; then
  reset_at=$(cat /tmp/claude-reset-at)
  now=$(date +%s)
  diff=$(( reset_at - now ))
  [ "$diff" -gt 0 ] && reset_seconds="$diff"
fi

# Build reset info string for the injection
if [ -n "$reset_seconds" ]; then
  hours=$(( reset_seconds / 3600 ))
  mins=$(( (reset_seconds % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    reset_info="Rate limit resets in approximately ${hours}h${mins}m (${reset_seconds} seconds)."
  else
    reset_info="Rate limit resets in approximately ${mins} minutes (${reset_seconds} seconds)."
  fi
else
  reset_info="Rate limit reset time unknown — schedule continuation for ~5 hours from now."
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "URGENT: Context window at 90%+. A persistent task is active (TASK.md exists at $cwd). You MUST do ALL of the following before responding:\n\n1. Write HANDOFF.md at $cwd capturing full session context (Goal, Frozen Decisions, Current Progress, What Worked, What Didn't Work, Open Questions, Next Steps).\n\n2. Read TASK.md to get the resume prompt.\n\n3. Schedule a continuation agent: $reset_info Use the schedule skill or CronCreate to launch a new claude session after the reset that runs the resume prompt from TASK.md. The agent must start in directory: $cwd\n\n4. Tell the user: context saved to HANDOFF.md, continuation scheduled, they can also resume manually with: claude \\\"Read TASK.md and HANDOFF.md and continue the task\\\"\n\nDo not skip any of these steps."
  }
}
EOF
