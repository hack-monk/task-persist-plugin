#!/usr/bin/env bash
# task-persist plugin statusline
# Writes context % to /tmp/claude-context-pct
# Writes rate limit reset epoch to /tmp/claude-reset-at
# Delegates display to CLAUDE_STATUSLINE_DELEGATE if set, else renders built-in.

input=$(cat)

# Write side-channel files for hooks
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
[ -n "$used_pct" ] && printf "%.0f" "$used_pct" > /tmp/claude-context-pct

reset_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
[ -n "$reset_at" ] && echo "$reset_at" > /tmp/claude-reset-at

# Delegate display if another statusline is configured
if [ -n "$CLAUDE_STATUSLINE_DELEGATE" ] && [ -f "$CLAUDE_STATUSLINE_DELEGATE" ]; then
  echo "$input" | bash "$CLAUDE_STATUSLINE_DELEGATE"
  exit 0
fi

# Built-in display
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

build_bar() {
  local pct="$1" width=20
  local filled=$(printf "%.0f" "$(echo "$pct * $width / 100" | bc -l 2>/dev/null || echo 0)")
  local empty=$((width - filled))
  local bar="" i
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++)); do bar="${bar}░"; done
  echo "$bar"
}

build_reset_countdown() {
  [ -z "$reset_at" ] && return
  local now diff hours mins
  now=$(date +%s)
  diff=$(( reset_at - now ))
  [ "$diff" -le 0 ] && return
  hours=$(( diff / 3600 ))
  mins=$(( (diff % 3600) / 60 ))
  [ "$hours" -gt 0 ] && printf "↻ %dh%02dm" "$hours" "$mins" || printf "↻ %dm" "$mins"
}

reset_str=$(build_reset_countdown)

if [ -n "$used_pct" ]; then
  bar=$(build_bar "$used_pct")
  used_int=$(printf "%.0f" "$used_pct")
  if   [ "$used_int" -ge 80 ]; then color="\033[31m"
  elif [ "$used_int" -ge 50 ]; then color="\033[33m"
  else                               color="\033[32m"
  fi
  reset_color="\033[0m"
  suffix=""
  [ -n "$reset_str" ] && suffix="  $reset_str"
  # Show persistent task indicator if TASK.md exists in cwd
  task_indicator=""
  [ -f "$PWD/TASK.md" ] && task_indicator=" ⚡"
  printf "${color}%s${task_indicator}${reset_color}  [%s] %s%%%s" "$model" "$bar" "$used_int" "$suffix"
else
  suffix=""
  [ -n "$reset_str" ] && suffix="  $reset_str"
  task_indicator=""
  [ -f "$PWD/TASK.md" ] && task_indicator=" ⚡"
  printf "%s%s  [····················] --%s" "$model" "$task_indicator" "$suffix"
fi
