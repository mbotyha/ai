#!/usr/bin/env bash
# Claude Code SessionStart hook: warns when the session folder (or its git root) has no .claude/settings.json with the merge rule.
# Project permissions (the agent's merge rule among them) load only from the folder the session
# starts in, so a session in ~ or in a workspace without settings runs without them.
#   workspace-check --hook   reads the session JSON on stdin; prints nothing when the folder has settings
set -uo pipefail

cwd=$(jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || exit 0
real=$(cd "$cwd" 2>/dev/null && pwd -P) || exit 0
root=$(git -C "$real" rev-parse --show-toplevel 2>/dev/null || echo "$real")
# ~/.claude/settings.json is the user's own file, never a workspace's; a workspace counts only with the merge rule
if [ "$real" != "$(cd "$HOME" && pwd -P)" ]; then
  for d in "$real" "$root"; do
    grep -qsF 'gh pr merge' "$d/.claude/settings.json" "$d/.claude/settings.local.json" && exit 0
  done
fi
link="$(cd "$(dirname "$(readlink -f "$0")")/../../.." && pwd)/os/scripts/link-project-settings.mjs"
# the fix is the owner's: the model only learns the rule is missing, the commands go to the user's screen only
jq -n --arg m "Agent permissions (the merge rule) are not loaded: $real has no .claude/settings.json with them. Reopen the chat with: ai c --w <workspace> --name <chat name>. To give $real its own: node $link $real" \
  --arg c "This session has no workspace agent permissions: merges and other gated actions need the owner's explicit OK in chat." \
  '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
