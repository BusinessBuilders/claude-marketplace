#!/usr/bin/env bash
#
# stop-hook.sh - Stop hook
#
# Validates task completion before allowing Claude to stop
# Checks for:
#   - Unresolved failures from session state
#   - Incomplete work patterns (TODO, FIXME, errors)
#   - Minimum progress made
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
# CHECK SESSION STATE - Are there unresolved failures?
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

    echo "{\"decision\": \"block\", \"reason\": \"Unresolved $FAIL_TYPE error from $FAIL_TOOL\", \"systemMessage\": \"⛔ INCOMPLETE: There are unresolved errors. Please address the $FAIL_TYPE issue with $FAIL_TOOL before stopping, or explicitly acknowledge if it cannot be resolved.\"}"
    exit 0
  fi

  # Block if very few actions taken (might be incomplete)
  if [[ "$TOOLS_USED" -lt 2 && -z "$STOP_REASON" ]]; then
    echo '{"decision": "block", "reason": "Very few actions taken", "systemMessage": "⛔ INCOMPLETE: Very few actions were taken. Verify the task is truly complete before stopping, or explain why no further action is needed."}'
    exit 0
  fi
fi

# ============================================================================
# CHECK TRANSCRIPT - Smart pattern detection
# ============================================================================

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  # Get last ~3000 characters with AGGRESSIVE filtering:
  # - Remove tool-advisor self-references
  # - Remove grep/search output (lines with file:line: patterns)
  # - Remove TodoWrite status lines
  # - Remove discussion about errors (sentences with "the error", "this error")
  LAST_CONTENT=$(tail -c 3000 "$TRANSCRIPT_PATH" 2>/dev/null | \
    grep -viE '(tool-advisor|stop-hook|post-tool-hook|pre-tool-hook|user-prompt-hook|hooks\.json)' | \
    grep -vE '^[^:]+\.(ts|js|py|sh|json|md):[0-9]+:' | \
    grep -viE '(\[completed\]|\[in_progress\]|\[pending\])' | \
    grep -viE '(the error|this error|that error|discussing|talked about|mentioned)' || echo "")

  # Skip checks if nothing meaningful left
  [[ -z "$LAST_CONTENT" || "$LAST_CONTENT" == "empty" ]] && LAST_CONTENT=""

  if [[ -n "$LAST_CONTENT" ]]; then
    # Check for ACTUAL tool output errors (not discussions)
    # Only match errors that look like real tool failures
    if echo "$LAST_CONTENT" | grep -qE '(ENOENT|EACCES|ECONNREFUSED|exit code [1-9]|Command failed|npm ERR!|error TS[0-9]+:)'; then
      # But allow if we see resolution indicators
      if ! echo "$LAST_CONTENT" | grep -qiE '(fixed|resolved|✅|succeeded|working now|no longer)'; then
        echo '{"decision": "block", "reason": "Unresolved tool error", "systemMessage": "⚠️ Tool error detected. Address or acknowledge before stopping."}'
        exit 0
      fi
    fi

    # Check for test failures - only actual test runner output
    if echo "$LAST_CONTENT" | grep -qE '(FAIL\s+[a-zA-Z]|Tests:\s+[0-9]+\s+failed|[0-9]+\s+failing)'; then
      if ! echo "$LAST_CONTENT" | grep -qE '(PASS|Tests:\s+[0-9]+\s+passed|all passing)'; then
        echo '{"decision": "block", "reason": "Test failures in output", "systemMessage": "⚠️ Test failures detected. Fix or acknowledge before stopping."}'
        exit 0
      fi
    fi

    # Check for build failures - only actual build output
    if echo "$LAST_CONTENT" | grep -qE '(error TS[0-9]+:|Build failed|Compilation failed|ERROR in)'; then
      if ! echo "$LAST_CONTENT" | grep -qE '(Build succeeded|Compiled successfully|webpack.*compiled)'; then
        echo '{"decision": "block", "reason": "Build failure in output", "systemMessage": "⚠️ Build failed. Fix or acknowledge before stopping."}'
        exit 0
      fi
    fi
  fi

  # USER INPUT CHECK: If asking for clarification, allow stop
  if echo "$LAST_CONTENT" | grep -qiE '(which.*prefer|what.*should|need.*clarification|waiting.*input|your.*decision|please.*choose|would you like)'; then
    echo '{"decision": "approve", "reason": "Waiting for user input"}'
    exit 0
  fi

  # RIGHT TOOL SUGGESTION (non-blocking)
  if [[ -f "$CACHE_FILE" ]] && echo "$LAST_CONTENT" | grep -qiE '(stuck|not sure|help)'; then
    POTENTIAL_TOOLS=$(jq -r '.capabilities[] | select(.type == "agent") | .id' "$CACHE_FILE" 2>/dev/null | head -3 | tr '\n' ', ')
    if [[ -n "$POTENTIAL_TOOLS" ]]; then
      echo "{\"systemMessage\": \"💡 Specialized agents available: $POTENTIAL_TOOLS\"}"
    fi
  fi
fi

# ============================================================================
# CLEANUP AND APPROVE
# ============================================================================

# Clean up session state on approved stop
if [[ -f "$STATE_FILE" ]]; then
  jq "del(.sessions[\"$SESSION_ID\"])" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

# All checks passed - allow stop
echo '{"decision": "approve", "reason": "Task appears complete"}'
exit 0
