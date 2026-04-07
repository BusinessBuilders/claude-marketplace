#!/usr/bin/env bash
#
# post-tool-hook.sh - PostToolUse hook
#
# Implements CASCADE BEHAVIOR - the key feature users want!
# After each tool execution:
#   1. Detect failures and suggest alternatives
#   2. On success, determine and push toward next logical step
#   3. Keep the workflow moving without waiting
#
# This creates the "cascade" effect where Claude continues working
#

set -euo pipefail

CACHE_FILE="$HOME/.claude/tool-advisor-cache.json"
STATE_FILE="$HOME/.claude/tool-advisor-state.json"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)

[[ -z "$TOOL_RESULT" ]] && exit 0

# Initialize state file if needed
[[ ! -f "$STATE_FILE" ]] && echo '{"sessions":{}}' > "$STATE_FILE"

# ============================================================================
# FAILURE DETECTION - Check for errors and suggest alternatives
# ============================================================================

FAILED=false
FAILURE_TYPE=""

if echo "$TOOL_RESULT" | grep -qiE '(error|failed|failure|exception|denied|refused|not found|permission|timeout|rejected|ENOENT|EACCES|ECONNREFUSED|command not found)'; then
  FAILED=true

  # Categorize failure type
  if echo "$TOOL_RESULT" | grep -qiE '(permission|denied|refused|access|EACCES|forbidden|401|403)'; then
    FAILURE_TYPE="permission"
  elif echo "$TOOL_RESULT" | grep -qiE '(not found|no such|missing|does not exist|ENOENT|404|cannot find)'; then
    FAILURE_TYPE="not_found"
  elif echo "$TOOL_RESULT" | grep -qiE '(timeout|timed out|deadline|ETIMEDOUT)'; then
    FAILURE_TYPE="timeout"
  elif echo "$TOOL_RESULT" | grep -qiE '(syntax|parse|invalid|malformed|unexpected token|SyntaxError)'; then
    FAILURE_TYPE="syntax"
  elif echo "$TOOL_RESULT" | grep -qiE '(connection|network|unreachable|ECONNREFUSED|ENETUNREACH)'; then
    FAILURE_TYPE="network"
  elif echo "$TOOL_RESULT" | grep -qiE '(type.*error|TypeError|cannot read|undefined is not)'; then
    FAILURE_TYPE="type_error"
  else
    FAILURE_TYPE="general"
  fi
fi

# Handle failures - log and suggest recovery
if [[ "$FAILED" == "true" ]]; then
  # Log failure to state for Stop hook to check
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq --arg sid "$SESSION_ID" --arg tool "$TOOL_NAME" --arg type "$FAILURE_TYPE" --arg ts "$TS" \
     '.sessions[$sid] = (.sessions[$sid] // {failures:[], tools_used:[], steps_completed:0}) | .sessions[$sid].failures += [{tool:$tool,type:$type,ts:$ts}]' \
     "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"

  # Suggest recovery based on failure type
  case "$FAILURE_TYPE" in
    permission)
      echo '{"systemMessage": "⚠️ PERMISSION ERROR - Try: check file permissions, use sudo if appropriate, or try alternative approach. ➡️ CONTINUE with recovery."}'
      ;;
    not_found)
      echo '{"systemMessage": "⚠️ NOT FOUND - Resource missing. ➡️ CONTINUE: search for correct path/name, or create the resource if needed."}'
      ;;
    timeout)
      echo '{"systemMessage": "⚠️ TIMEOUT - Operation took too long. ➡️ CONTINUE: break into smaller steps, retry with longer timeout, or try alternative."}'
      ;;
    syntax)
      echo '{"systemMessage": "⚠️ SYNTAX ERROR - Check input format. ➡️ CONTINUE: review and fix the syntax, then retry."}'
      ;;
    network)
      echo '{"systemMessage": "⚠️ NETWORK ERROR - Connection issue. ➡️ CONTINUE: check connectivity, try offline alternative, or retry."}'
      ;;
    type_error)
      echo '{"systemMessage": "⚠️ TYPE ERROR - Type mismatch in code. ➡️ CONTINUE: fix the type issue and retry."}'
      ;;
    *)
      if [[ -f "$CACHE_FILE" ]]; then
        echo '{"systemMessage": "⚠️ TOOL ERROR - Check tool-advisor cache for alternatives. ➡️ CONTINUE with different approach."}'
      else
        echo '{"systemMessage": "⚠️ TOOL ERROR - Try alternative approach. ➡️ CONTINUE."}'
      fi
      ;;
  esac
  exit 0
fi

# ============================================================================
# SUCCESS - Track and CASCADE to next logical step
# ============================================================================

# Track successful tool use
jq --arg sid "$SESSION_ID" --arg tool "$TOOL_NAME" \
   '.sessions[$sid] = (.sessions[$sid] // {failures:[], tools_used:[], steps_completed:0}) | .sessions[$sid].tools_used += [$tool] | .sessions[$sid].steps_completed += 1' \
   "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"

# Clear failures on success (they were resolved)
jq --arg sid "$SESSION_ID" \
   '.sessions[$sid].failures = []' \
   "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"

# ============================================================================
# CASCADE LOGIC - Push toward next logical step based on what just completed
# ============================================================================

case "$TOOL_NAME" in
  Edit|Write)
    # File was modified - what's next?
    if echo "$TOOL_RESULT" | grep -qiE '\.(ts|tsx|js|jsx)$'; then
      echo '{"systemMessage": "✅ File updated. ➡️ CASCADE: Run type-check (npx tsc --noEmit) or tests to verify changes."}'
    elif echo "$TOOL_RESULT" | grep -qiE '\.(py)$'; then
      echo '{"systemMessage": "✅ Python file updated. ➡️ CASCADE: Run linter (ruff/flake8) or tests (pytest) to verify."}'
    elif echo "$TOOL_RESULT" | grep -qiE '\.(css|scss|less)$'; then
      echo '{"systemMessage": "✅ Styles updated. ➡️ CASCADE: Check visual rendering or run style linter."}'
    elif echo "$TOOL_RESULT" | grep -qiE '(schema\.prisma)'; then
      echo '{"systemMessage": "✅ Schema updated. ➡️ CASCADE: Run prisma generate and prisma db push to apply changes."}'
    elif echo "$TOOL_RESULT" | grep -qiE '\.(json|yaml|yml|toml)$'; then
      echo '{"systemMessage": "✅ Config updated. ➡️ CASCADE: Validate config and restart relevant services if needed."}'
    else
      echo '{"systemMessage": "✅ File updated. ➡️ CASCADE: Verify changes work as expected."}'
    fi
    ;;

  Bash)
    # Command executed - analyze result for next step
    if echo "$TOOL_RESULT" | grep -qiE '(test|spec).*(passed|success|ok)|(\d+\s+pass)'; then
      echo '{"systemMessage": "✅ Tests passed! ➡️ CASCADE: Commit changes or proceed to next task."}'
    elif echo "$TOOL_RESULT" | grep -qiE '(build|compile).*(success|complete|done)'; then
      echo '{"systemMessage": "✅ Build succeeded! ➡️ CASCADE: Run tests or deploy if ready."}'
    elif echo "$TOOL_RESULT" | grep -qiE '(npm|yarn|pnpm)\s+install.*success|added.*packages'; then
      echo '{"systemMessage": "✅ Dependencies installed. ➡️ CASCADE: Continue with development or run build."}'
    elif echo "$TOOL_RESULT" | grep -qiE 'prisma.*generate|Generated Prisma'; then
      echo '{"systemMessage": "✅ Prisma client generated. ➡️ CASCADE: Update code to use new schema types."}'
    elif echo "$TOOL_RESULT" | grep -qiE 'migration.*applied|database.*synced'; then
      echo '{"systemMessage": "✅ Database migrated. ➡️ CASCADE: Verify data integrity and update application code."}'
    elif echo "$TOOL_RESULT" | grep -qiE 'commit|pushed|merged'; then
      echo '{"systemMessage": "✅ Git operation complete. ➡️ CASCADE: Continue with next feature or task."}'
    fi
    ;;

  Task)
    # Agent task completed
    echo '{"systemMessage": "✅ Agent task complete. ➡️ CASCADE: Review results and continue with main workflow."}'
    ;;

  Glob|Grep|Read)
    # Search/read completed
    echo '{"systemMessage": "✅ Information gathered. ➡️ CASCADE: Use this information to proceed with the task."}'
    ;;

  WebFetch|WebSearch)
    # Web operation completed
    echo '{"systemMessage": "✅ Web data retrieved. ➡️ CASCADE: Process the information and continue."}'
    ;;

  mcp__*)
    # MCP tool completed
    echo '{"systemMessage": "✅ MCP operation complete. ➡️ CASCADE: Continue with workflow using the results."}'
    ;;

esac

exit 0
