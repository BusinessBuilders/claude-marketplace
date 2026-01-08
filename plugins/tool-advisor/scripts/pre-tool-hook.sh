#!/usr/bin/env bash
#
# pre-tool-hook.sh - PreToolUse hook
#
# Checks if there's a more specialized tool before executing the current one
# Uses capability cache to find alternatives with higher specialization
#
# Outputs systemMessage suggesting alternatives (non-blocking)
#

set -euo pipefail

CACHE_FILE="$HOME/.claude/tool-advisor-cache.json"
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null || echo "{}")

[[ -z "$TOOL_NAME" ]] && exit 0
[[ ! -f "$CACHE_FILE" ]] && exit 0

# ============================================================================
# BASH COMMAND ANALYSIS - Check for specialized alternatives
# ============================================================================

if [[ "$TOOL_NAME" == "Bash" ]]; then
  COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null || echo "")

  # Git operations -> Suggest GitHub/GitLab MCP tools
  if echo "$COMMAND" | grep -qE '^git\s+(push|pull|pr|issue|merge|fetch|clone|status|log)'; then
    HAS_GIT_MCP=$(jq -e '.capabilities[] | select(.id | test("github|gitlab"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_GIT_MCP" ]]; then
      echo '{"systemMessage": "💡 GitHub/GitLab MCP tools available for advanced git operations with richer API access."}'
      exit 0
    fi
  fi

  # Docker operations -> Suggest Docker-specialized tools
  if echo "$COMMAND" | grep -qE '^docker\s+(build|push|pull|run|compose|ps|logs)'; then
    HAS_DOCKER=$(jq -e '.capabilities[] | select(.keywords[] | test("docker"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_DOCKER" ]]; then
      echo '{"systemMessage": "💡 Docker-specialized tools available for container operations."}'
      exit 0
    fi
  fi

  # Test commands -> Suggest test automation agents
  if echo "$COMMAND" | grep -qE '(npm|yarn|pnpm|pytest|jest|vitest|cargo)\s+(test|run.*test)'; then
    HAS_TEST=$(jq -e '.capabilities[] | select(.id | test("test"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_TEST" ]]; then
      echo '{"systemMessage": "💡 Test automation agent available for comprehensive testing with coverage analysis."}'
      exit 0
    fi
  fi

  # Database CLI -> Suggest database tools/agents
  if echo "$COMMAND" | grep -qE '^(psql|mysql|mongosh|redis-cli|sqlite3)'; then
    HAS_DB=$(jq -e '.capabilities[] | select(.keywords[] | test("database|sql"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_DB" ]]; then
      echo '{"systemMessage": "💡 Database tools/agents available for database operations with better integration."}'
      exit 0
    fi
  fi

  # Curl/wget -> Suggest WebFetch
  if echo "$COMMAND" | grep -qE '^(curl|wget)\s'; then
    echo '{"systemMessage": "💡 Consider WebFetch tool for HTTP requests - better error handling and response parsing."}'
    exit 0
  fi

  # Build commands -> Suggest build agents
  if echo "$COMMAND" | grep -qE '(npm|yarn|pnpm)\s+(run\s+)?(build|compile)'; then
    HAS_BUILD=$(jq -e '.capabilities[] | select(.keywords[] | test("build"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_BUILD" ]]; then
      echo '{"systemMessage": "💡 Build agents available for comprehensive build operations with error handling."}'
      exit 0
    fi
  fi

  # Deploy commands -> Suggest deployment agents
  if echo "$COMMAND" | grep -qE '(deploy|vercel|netlify|heroku|fly)'; then
    HAS_DEPLOY=$(jq -e '.capabilities[] | select(.keywords[] | test("deploy"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_DEPLOY" ]]; then
      echo '{"systemMessage": "💡 Deployment agents available for comprehensive deployment with rollback support."}'
      exit 0
    fi
  fi
fi

# ============================================================================
# TASK TOOL ANALYSIS - Check if more specialized agent available
# ============================================================================

if [[ "$TOOL_NAME" == "Task" ]]; then
  PROMPT=$(echo "$TOOL_INPUT" | jq -r '.prompt // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')
  SUBAGENT=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // empty' 2>/dev/null)

  # If using generic agents, check for specialized ones
  if [[ "$SUBAGENT" == "general-purpose" || "$SUBAGENT" == "Explore" || "$SUBAGENT" == "Bash" ]]; then
    # Check for specialized agents by keyword
    for kw in deploy security database review test debug build performance api frontend backend; do
      if echo "$PROMPT" | grep -qwE "$kw"; then
        MATCH=$(jq -r ".keyword_index[\"$kw\"] // [] | .[0] // empty" "$CACHE_FILE" 2>/dev/null || echo "")
        if [[ -n "$MATCH" && "$MATCH" != "null" ]]; then
          TYPE=$(jq -r ".capabilities[] | select(.id == \"$MATCH\") | .type" "$CACHE_FILE" 2>/dev/null || echo "")
          if [[ "$TYPE" == "agent" ]]; then
            echo "{\"systemMessage\": \"💡 Specialized agent available: '$MATCH' - may be more effective than $SUBAGENT for this task.\"}"
            exit 0
          fi
        fi
        break
      fi
    done
  fi
fi

# ============================================================================
# WRITE/EDIT ANALYSIS - Check for specialized code generators
# ============================================================================

if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
  FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null || echo "")

  # Check file extension for specialized tools
  if echo "$FILE_PATH" | grep -qE '\.(tsx|jsx)$'; then
    HAS_FRONTEND=$(jq -e '.capabilities[] | select(.keywords[] | test("frontend|react"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_FRONTEND" ]]; then
      echo '{"systemMessage": "💡 Frontend development agents available for React/TypeScript with best practices."}'
      exit 0
    fi
  fi

  if echo "$FILE_PATH" | grep -qE '\.(py)$'; then
    HAS_PYTHON=$(jq -e '.capabilities[] | select(.keywords[] | test("python"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_PYTHON" ]]; then
      echo '{"systemMessage": "💡 Python development agents available with framework-specific expertise."}'
      exit 0
    fi
  fi

  if echo "$FILE_PATH" | grep -qE '(schema\.prisma|\.sql)$'; then
    HAS_DB=$(jq -e '.capabilities[] | select(.keywords[] | test("database"; "i"))' "$CACHE_FILE" 2>/dev/null || echo "")
    if [[ -n "$HAS_DB" ]]; then
      echo '{"systemMessage": "💡 Database agents available for schema design and migrations."}'
      exit 0
    fi
  fi
fi

# No better alternative found - let tool proceed silently
exit 0
