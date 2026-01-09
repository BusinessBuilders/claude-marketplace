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
# CHECK TRANSCRIPT - Smart pattern detection (ignore self-references)
# ============================================================================

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  # Get last ~3000 characters, EXCLUDE tool-advisor/hook references (self)
  LAST_CONTENT=$(tail -c 3000 "$TRANSCRIPT_PATH" 2>/dev/null | grep -viE '(tool-advisor|stop-hook|post-tool-hook|pre-tool-hook|user-prompt-hook|hooks\.json)' || echo "")

  # Skip if nothing left after filtering
  [[ -z "$LAST_CONTENT" ]] && LAST_CONTENT="empty"

  # Check for TODO/FIXME markers in CODE (not discussion)
  if echo "$LAST_CONTENT" | grep -qE '^\s*(//|#|/\*|\*)\s*(TODO|FIXME|XXX|HACK|WIP)'; then
    echo '{"decision": "block", "reason": "Code TODO markers found", "systemMessage": "⚠️ Found TODO/FIXME in code. Complete or acknowledge before stopping."}'
    exit 0
  fi

  # Check for ACTUAL errors: stack traces, exit codes, command failures
  # (not just the word "error" in discussion)
  if echo "$LAST_CONTENT" | grep -qE '(at\s+\S+:\d+:\d+|Error:|ENOENT|EACCES|exit code [1-9]|Command failed|npm ERR!|SyntaxError:|TypeError:|ReferenceError:)'; then
    # But allow if we see resolution indicators nearby
    if ! echo "$LAST_CONTENT" | grep -qiE '(fixed|resolved|✅|succeeded|passed|working now)'; then
      echo '{"decision": "block", "reason": "Unresolved stack trace or error", "systemMessage": "⚠️ Found actual error (stack trace/exit code). Verify resolved before stopping."}'
      exit 0
    fi
  fi

  # Check for test failures with actual numbers
  if echo "$LAST_CONTENT" | grep -qE '[1-9][0-9]*\s+(failed|failing|errors?)'; then
    if ! echo "$LAST_CONTENT" | grep -qE '(0\s+fail|all.*pass|✅.*test)'; then
      echo '{"decision": "block", "reason": "Test failures detected", "systemMessage": "⚠️ Test failures detected. Fix failing tests before stopping."}'
      exit 0
    fi
  fi

  # Check for build failures with actual indicators
  if echo "$LAST_CONTENT" | grep -qE '(Build failed|Compilation failed|tsc.*error\(s\)|webpack.*error)'; then
    if ! echo "$LAST_CONTENT" | grep -qE '(Build succeeded|Compiled successfully|✅.*build)'; then
      echo '{"decision": "block", "reason": "Build failures detected", "systemMessage": "⚠️ Build failed. Fix build errors before stopping."}'
      exit 0
    fi
  fi

  # RIGHT TOOL CHECK: If there are failures, suggest checking tool-advisor cache
  if [[ -f "$CACHE_FILE" ]] && echo "$LAST_CONTENT" | grep -qE '(failed|error|not working)'; then
    # Check if specialized tools might help
    POTENTIAL_TOOLS=$(jq -r '.capabilities[] | select(.type == "agent") | .id' "$CACHE_FILE" 2>/dev/null | head -3 | tr '\n' ', ')
    if [[ -n "$POTENTIAL_TOOLS" ]]; then
      echo "{\"systemMessage\": \"💡 If stuck, specialized agents may help: $POTENTIAL_TOOLS\"}"
      # Don't block, just suggest
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
