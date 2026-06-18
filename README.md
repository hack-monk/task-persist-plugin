# task-persist

Claude Code plugin for long-running tasks that survive context window exhaustion and rate limit resets.

## What it does

1. You register a task with `TASK.md` (via the `start-task` skill)
2. Claude works normally — statusline shows ⚡ when a task is active
3. At 90% context:
   - Claude writes `HANDOFF.md` (full session state)
   - Reads the resume prompt from `TASK.md`
   - Schedules a continuation agent to start after the rate limit resets
4. New session starts automatically, reads both files, continues where it left off

## Difference from auto-handoff

| | [auto-handoff](https://github.com/hack-monk/auto-handoff-plugin) | task-persist |
|---|---|---|
| Triggers | Always at 90% | Only when `TASK.md` exists |
| Writes HANDOFF.md | Yes | Yes |
| Schedules continuation | No | Yes |
| Use case | General context saving | Long-running autonomous tasks |

Both can be installed together — hooks are independent.

## Install

```bash
git clone https://github.com/hack-monk/task-persist-plugin
cd task-persist-plugin
bash install.sh
```

Reload Claude Code (open `/hooks` or restart).

### Existing statusline

`install.sh` detects existing `statusLine.command` and saves it as `CLAUDE_STATUSLINE_DELEGATE`. Display is delegated — no features lost. Compatible with auto-handoff-plugin.

## Usage

### Start a persistent task

Tell Claude: *"persist this task"* or *"use the start-task skill"*

Claude creates `TASK.md`:

```markdown
# Persistent Task

_Started: 2026-06-17_
_Directory: /your/project_

## Objective
Refactor the auth module to use JWT across all services.

## Resume Prompt
Read TASK.md and HANDOFF.md. Continue the persistent task from Next Steps step 1.
The objective is: refactor auth module to use JWT across all services.

## Notes
- Use existing test suite as success bar
- Don't touch the legacy SSO path
```

### What happens at 90%

Hook fires → Claude:
1. Writes `HANDOFF.md`
2. Schedules continuation via `schedule` skill / `CronCreate` / `at`
3. Notifies you with manual resume command as fallback

### Cancel a task

```bash
rm TASK.md
```

Hook checks for `TASK.md` on every message — deletion is instant.

### Manual resume (any time)

```bash
claude "Read TASK.md and HANDOFF.md and continue the task"
```

## Architecture

```
UserPromptSubmit (every message)
  └── hooks/task-persist.sh
        ├── TASK.md exists? → proceed
        ├── context % >= 90? → proceed  (reads /tmp/claude-context-pct)
        └── inject additionalContext:
              write HANDOFF.md + schedule continuation at reset time

statusline.sh (every response)
  ├── writes /tmp/claude-context-pct  (context %)
  ├── writes /tmp/claude-reset-at     (rate limit reset epoch)
  └── shows ⚡ indicator when TASK.md active
```

**Why the temp file side-channel?** `UserPromptSubmit` hook stdin JSON contains no `context_window` data — only `session_id`, `cwd`, `prompt`. The statusline receives full context data and writes it to temp files for the hook to read.

## Files

```
task-persist-plugin/
  .claude-plugin/marketplace.json
  statusline.sh                    # display + writes /tmp/claude-{context-pct,reset-at}
  hooks/task-persist.sh            # UserPromptSubmit hook
  skills/
    start-task/SKILL.md            # create TASK.md to register a task
    task-persist/SKILL.md          # what Claude does at 90%
  install.sh
  uninstall.sh
```

## Uninstall

```bash
bash uninstall.sh
```
