#!/usr/bin/env bash
#
# stop-hook.sh - Combined Nudge + Quality Gate Stop Hook
#
# Implements the best patterns from research:
#   1. Quality Gates - Block on unresolved errors, test/build failures
#   2. Todo Completion - Block if todos are incomplete
#   3. Smart Nudge - Guide Claude to next logical step
#   4. User Input Detection - Allow stop when waiting for user
#
# Returns decision: approve (allow stop) or block (continue working)
#

set -euo pipefail

STATE_FILE="$HOME/.claude/tool-advisor-state.json"
CACHE_FILE="$HOME/.claude/tool-advisor-cache.json"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // empty' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# ============================================================================
# PHASE 1: CHECK FOR INCOMPLETE TODOS (Ralph Wiggum Pattern)
# ============================================================================

# Check Claude's internal todo list from transcript
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  # Look for recent TodoWrite with incomplete items
  RECENT_TODOS=$(tail -c 10000 "$TRANSCRIPT_PATH" 2>/dev/null | \
    grep -oE '"status"\s*:\s*"(in_progress|pending)"' | wc -l || echo "0")

  COMPLETED_TODOS=$(tail -c 10000 "$TRANSCRIPT_PATH" 2>/dev/null | \
    grep -oE '"status"\s*:\s*"completed"' | wc -l || echo "0")

  # If there are pending/in_progress todos and not many completed, nudge to continue
  if [[ "$RECENT_TODOS" -gt 0 && "$COMPLETED_TODOS" -lt "$RECENT_TODOS" ]]; then
    echo '{"decision": "block", "reason": "📋 There are incomplete tasks in the todo list. Continue working through each task, marking them complete as you finish. Use TodoWrite to update status.", "systemMessage": "⏳ Incomplete todos detected - continue working"}'
    exit 0
  fi
fi

# ============================================================================
# PHASE 2: CHECK SESSION STATE - Unresolved Failures
# ============================================================================

if [[ -f "$STATE_FILE" ]]; then
  FAILURES=$(jq -r ".sessions[\"$SESSION_ID\"].failures // [] | length" "$STATE_FILE" 2>/dev/null || echo "0")
  TOOLS_USED=$(jq -r ".sessions[\"$SESSION_ID\"].tools_used // [] | length" "$STATE_FILE" 2>/dev/null || echo "0")
  STEPS_COMPLETED=$(jq -r ".sessions[\"$SESSION_ID\"].steps_completed // 0" "$STATE_FILE" 2>/dev/null || echo "0")

  # Block if there are unresolved failures
  if [[ "$FAILURES" -gt 0 ]]; then
    LAST_FAILURE=$(jq -r ".sessions[\"$SESSION_ID\"].failures[-1]" "$STATE_FILE" 2>/dev/null || echo "{}")
    FAIL_TOOL=$(echo "$LAST_FAILURE" | jq -r '.tool // "unknown"')
    FAIL_TYPE=$(echo "$LAST_FAILURE" | jq -r '.type // "unknown"')

    echo "{\"decision\": \"block\", \"reason\": \"⚠️ Unresolved $FAIL_TYPE error from $FAIL_TOOL. Either fix the issue, try an alternative approach, or explicitly acknowledge why it cannot be resolved.\", \"systemMessage\": \"⛔ Unresolved error - address before stopping\"}"
    exit 0
  fi

  # Block if very few actions taken (might be incomplete)
  if [[ "$TOOLS_USED" -lt 2 && -z "$STOP_REASON" ]]; then
    echo '{"decision": "block", "reason": "🤔 Very few actions were taken. Verify the task is truly complete. If more work is needed, continue. If done, explain why no further action is required.", "systemMessage": "⚠️ Minimal progress - verify completion"}'
    exit 0
  fi
fi

# ============================================================================
# PHASE 3: CHECK TRANSCRIPT - Quality Gates
# ============================================================================

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  # Get last ~3000 characters with AGGRESSIVE filtering
  LAST_CONTENT=$(tail -c 3000 "$TRANSCRIPT_PATH" 2>/dev/null | \
    grep -viE '(tool-advisor|stop-hook|post-tool-hook|pre-tool-hook|user-prompt-hook|hooks\.json)' | \
    grep -vE '^[^:]+\.(ts|js|py|sh|json|md):[0-9]+:' | \
    grep -viE '(\[completed\]|\[in_progress\]|\[pending\])' | \
    grep -viE '(the error|this error|that error|discussing|talked about|mentioned)' || echo "")

  [[ -z "$LAST_CONTENT" || "$LAST_CONTENT" == "empty" ]] && LAST_CONTENT=""

  if [[ -n "$LAST_CONTENT" ]]; then

    # USER INPUT CHECK FIRST: If asking for clarification, allow stop
    if echo "$LAST_CONTENT" | grep -qiE '(which.*prefer|what.*should|need.*clarification|waiting.*input|your.*decision|please.*choose|would you like|AskUserQuestion)'; then
      echo '{"decision": "approve", "reason": "Waiting for user input"}'
      exit 0
    fi

    # Check for ACTUAL tool output errors
    if echo "$LAST_CONTENT" | grep -qE '(ENOENT|EACCES|ECONNREFUSED|exit code [1-9]|Command failed|npm ERR!|error TS[0-9]+:)'; then
      if ! echo "$LAST_CONTENT" | grep -qiE '(fixed|resolved|✅|succeeded|working now|no longer)'; then
        echo '{"decision": "block", "reason": "🔧 Tool error detected in output. Please investigate and fix the error, or explain why it can be ignored.", "systemMessage": "⚠️ Unresolved tool error"}'
        exit 0
      fi
    fi

    # Check for test failures
    if echo "$LAST_CONTENT" | grep -qE '(FAIL\s+[a-zA-Z]|Tests:\s+[0-9]+\s+failed|[0-9]+\s+failing)'; then
      if ! echo "$LAST_CONTENT" | grep -qE '(PASS|Tests:\s+[0-9]+\s+passed|all passing)'; then
        echo '{"decision": "block", "reason": "🧪 Test failures detected. Please fix the failing tests or acknowledge if they are expected to fail.", "systemMessage": "⚠️ Test failures - fix before stopping"}'
        exit 0
      fi
    fi

    # Check for build failures
    if echo "$LAST_CONTENT" | grep -qE '(error TS[0-9]+:|Build failed|Compilation failed|ERROR in)'; then
      if ! echo "$LAST_CONTENT" | grep -qE '(Build succeeded|Compiled successfully|webpack.*compiled)'; then
        echo '{"decision": "block", "reason": "🏗️ Build failure detected. Please fix the build errors or explain why they can be deferred.", "systemMessage": "⚠️ Build failed - fix before stopping"}'
        exit 0
      fi
    fi

    # NUDGE PATTERN: If work was done but no verification, suggest next step
    if echo "$LAST_CONTENT" | grep -qiE '(Edit|Write|created|updated|modified|added|changed)'; then
      if ! echo "$LAST_CONTENT" | grep -qiE '(test|build|verify|check|confirmed|works|passing)'; then
        # Non-blocking nudge - just suggest
        echo '{"systemMessage": "💡 TIP: Consider running tests or build to verify your changes work correctly."}'
      fi
    fi

    # STUCK DETECTION: Suggest specialized agents
    if [[ -f "$CACHE_FILE" ]] && echo "$LAST_CONTENT" | grep -qiE '(stuck|not sure|help|difficult|struggling)'; then
      POTENTIAL_AGENTS=$(jq -r '.capabilities[] | select(.type == "agent") | .id' "$CACHE_FILE" 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')
      if [[ -n "$POTENTIAL_AGENTS" ]]; then
        echo "{\"systemMessage\": \"💡 Feeling stuck? Try specialized agents: $POTENTIAL_AGENTS\"}"
      fi
    fi
  fi
fi

# ============================================================================
# PHASE 4: CLEANUP AND APPROVE
# ============================================================================

# Clean up session state on approved stop
if [[ -f "$STATE_FILE" ]]; then
  jq "del(.sessions[\"$SESSION_ID\"])" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

# All checks passed - allow stop with positive message
echo '{"decision": "approve", "reason": "✅ Task appears complete. All quality gates passed."}'
exit 0
