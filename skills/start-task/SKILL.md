---
name: start-task
description: Use when user wants to start a long-running task that should survive context window exhaustion and rate limit resets. Creates TASK.md to activate persistent task mode.
---

# Start Persistent Task

Creates `TASK.md` in the project root to register a task with the task-persist system.

## When to use

User says things like:
- "persist this task"
- "continue even if context runs out"
- "don't stop when tokens run out"
- "make this survive a rate limit reset"

## Procedure

1. Ask the user (if not obvious): what is the full objective of this task?
2. Write `TASK.md` to the project root:

```markdown
# Persistent Task

_Started: YYYY-MM-DD_
_Directory: /absolute/path/to/project_

## Objective
<one paragraph: what outcome are we driving toward>

## Resume Prompt
Read TASK.md and HANDOFF.md. Continue the persistent task from Next Steps step 1. The objective is: <objective summary>.

## Notes
<any constraints, preferences, or context the continuation agent needs>
```

3. Confirm to the user: "Persistent task registered. If context hits 90%, I'll write HANDOFF.md and schedule a continuation agent automatically. Statusline shows ⚡ when a task is active."

## What happens at 90% context

The `task-persist` hook fires and instructs Claude to:
1. Write `HANDOFF.md` (full session state)
2. Schedule a new claude session using the resume prompt from `TASK.md`
3. The new session starts after the rate limit resets, reads both files, and continues

## To cancel a persistent task

Delete `TASK.md`. The hook will no longer fire.
