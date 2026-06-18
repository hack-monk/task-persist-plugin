---
name: task-persist
description: Use when context window crosses 90% and TASK.md exists and you receive an URGENT task-persist injection. Write HANDOFF.md and schedule a continuation agent before doing anything else.
---

# Task Persist

Handles the 90% context trigger when a persistent task is active. Ensures work continues in a new session after the rate limit resets.

## When triggered

You'll see an URGENT injection in additionalContext. A `TASK.md` exists in the project root. Context is at 90%+.

## Required actions — in order, no skipping

### 1. Write HANDOFF.md

Use the `handoff` skill. Capture everything:
- Goal (from TASK.md objective)
- Frozen Decisions (settled choices this session)
- Current Progress (what's verifiably done)
- What Worked / What Didn't Work
- Open Questions
- Next Steps (ordered, concrete, with success criteria)

### 2. Read TASK.md

Get the resume prompt. This is what the continuation agent will be told.

### 3. Schedule the continuation agent

Use the `schedule` skill or `CronCreate` tool to schedule a new agent after the rate limit resets. The agent's prompt should be the resume prompt from TASK.md. Pass the working directory.

If scheduling tools aren't available, use Bash to schedule via `at` or `nohup`:
```bash
# Example: schedule claude to run after reset
echo "cd /path/to/project && claude --print 'Read TASK.md and HANDOFF.md and continue'" | at now + Xminutes
```

### 4. Tell the user

Inform them:
- HANDOFF.md written at [path]
- Continuation scheduled for [reset time]
- Manual resume: `claude "Read TASK.md and HANDOFF.md and continue the task"`

## To start a persistent task

Use the `start-task` skill to create `TASK.md`.

## To cancel

Delete `TASK.md` — hook will no longer fire.
