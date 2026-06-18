#!/usr/bin/env bash
# task-persist hook — fires on UserPromptSubmit
# Only acts if TASK.md exists in current working directory.
# At >= 90% context: injects instructions to write HANDOFF.md + schedule continuation.

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

# Build reset info
reset_info="Rate limit reset time unknown — schedule continuation for ~5 hours from now."
if [ -f /tmp/claude-reset-at ]; then
  reset_at=$(cat /tmp/claude-reset-at)
  now=$(date +%s)
  diff=$(( reset_at - now ))
  if [ "$diff" -gt 0 ]; then
    hours=$(( diff / 3600 ))
    mins=$(( (diff % 3600) / 60 ))
    if [ "$hours" -gt 0 ]; then
      reset_info="Rate limit resets in approximately ${hours}h${mins}m (${diff} seconds)."
    else
      reset_info="Rate limit resets in approximately ${mins} minutes (${diff} seconds)."
    fi
  fi
fi

msg="URGENT: Context window at 90%+. A persistent task is active (TASK.md exists at ${cwd}). You MUST do ALL of the following before responding:

1. Write HANDOFF.md at ${cwd} capturing full session context (Goal, Frozen Decisions, Current Progress, What Worked, What Didn't Work, Open Questions, Next Steps).

2. Read TASK.md to get the resume prompt.

3. Schedule a continuation agent: ${reset_info} Use the schedule skill or CronCreate to launch a new claude session after the reset that runs the resume prompt from TASK.md. The agent must start in directory: ${cwd}

4. Tell the user: context saved to HANDOFF.md, continuation scheduled. Manual resume: claude 'Read TASK.md and HANDOFF.md and continue the task'

Do not skip any of these steps."

jq -n --arg ctx "$msg" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
