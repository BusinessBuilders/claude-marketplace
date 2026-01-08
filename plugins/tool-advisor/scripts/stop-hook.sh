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
# CHECK TRANSCRIPT - Look for incomplete work patterns
# ============================================================================

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  # Get last ~3000 characters of transcript for recent context
  LAST_CONTENT=$(tail -c 3000 "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

  # Check for TODO/FIXME markers indicating incomplete work
  if echo "$LAST_CONTENT" | grep -qiE '(TODO|FIXME|XXX|HACK|WIP)[:[:space:]]'; then
    echo '{"decision": "block", "reason": "Incomplete work markers found", "systemMessage": "⛔ INCOMPLETE: Found TODO/FIXME/WIP markers in recent work. Please complete these items before stopping."}'
    exit 0
  fi

  # Check for unhandled errors (error mentioned but not fixed/resolved)
  if echo "$LAST_CONTENT" | grep -qiE '(error|failed|exception|crash)' && \
     ! echo "$LAST_CONTENT" | grep -qiE '(fixed|resolved|handled|addressed|corrected)'; then
    echo '{"decision": "block", "reason": "Potential unhandled errors", "systemMessage": "⛔ INCOMPLETE: Recent errors may not be resolved. Verify all issues are addressed before stopping."}'
    exit 0
  fi

  # Check for "will do later" patterns
  if echo "$LAST_CONTENT" | grep -qiE '(will.*later|coming.*soon|not.*implemented.*yet|placeholder|stub)'; then
    echo '{"decision": "block", "reason": "Deferred work detected", "systemMessage": "⛔ INCOMPLETE: Found deferred work (\"will do later\" patterns). Complete or acknowledge these items before stopping."}'
    exit 0
  fi

  # Check for test failures
  if echo "$LAST_CONTENT" | grep -qiE '(\d+\s+fail|\d+\s+error|tests?\s+failed|FAIL)' && \
     ! echo "$LAST_CONTENT" | grep -qiE '(all.*pass|tests?\s+pass|0\s+fail)'; then
    echo '{"decision": "block", "reason": "Test failures detected", "systemMessage": "⛔ INCOMPLETE: Test failures were detected. Fix failing tests before stopping."}'
    exit 0
  fi

  # Check for build failures
  if echo "$LAST_CONTENT" | grep -qiE '(build.*fail|compile.*error|tsc.*error)' && \
     ! echo "$LAST_CONTENT" | grep -qiE '(build.*success|compile.*success)'; then
    echo '{"decision": "block", "reason": "Build failures detected", "systemMessage": "⛔ INCOMPLETE: Build failures were detected. Fix build errors before stopping."}'
    exit 0
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
