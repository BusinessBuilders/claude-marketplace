#!/usr/bin/env bash
#
# extract-capabilities.sh - Extract capabilities from a plugin directory
#
# Usage: ./extract-capabilities.sh <plugin-dir> <plugin-name>
#
# Outputs JSON array of capabilities found in the plugin
#

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <plugin-dir> <plugin-name>" >&2
  exit 1
fi

PLUGIN_DIR="$1"
PLUGIN_NAME="$2"

# Check if plugin is installed (vs just discovered)
INSTALLED_PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"
PLUGIN_STATUS="discovered"
INSTALL_COUNT=0

if [[ -f "$INSTALLED_PLUGINS_FILE" ]]; then
  # Check for both exact match and @registry suffix patterns
  if jq -e ".plugins.\"$PLUGIN_NAME\"" "$INSTALLED_PLUGINS_FILE" > /dev/null 2>&1; then
    PLUGIN_STATUS="installed"
    INSTALL_COUNT=$(jq ".plugins.\"$PLUGIN_NAME\" | length" "$INSTALLED_PLUGINS_FILE" 2>/dev/null || echo 0)
  elif jq -e ".plugins | keys[] | select(startswith(\"$PLUGIN_NAME@\"))" "$INSTALLED_PLUGINS_FILE" > /dev/null 2>&1; then
    PLUGIN_STATUS="installed"
    # Find the full key name (e.g., "feature-dev@claude-plugins-official")
    FULL_KEY=$(jq -r ".plugins | keys[] | select(startswith(\"$PLUGIN_NAME@\"))" "$INSTALLED_PLUGINS_FILE" | head -1)
    INSTALL_COUNT=$(jq ".plugins.\"$FULL_KEY\" | length" "$INSTALLED_PLUGINS_FILE" 2>/dev/null || echo 0)
  fi
fi

# Function to extract YAML frontmatter from markdown files
extract_frontmatter() {
  local file="$1"

  # Extract content between --- markers
  awk '
    BEGIN { in_frontmatter=0; frontmatter="" }
    /^---$/ {
      if (in_frontmatter == 0) {
        in_frontmatter=1;
        next
      } else {
        print frontmatter;
        exit
      }
    }
    in_frontmatter { frontmatter = frontmatter $0 "\n" }
  ' "$file"
}

# Function to extract keywords from text
extract_keywords() {
  local text="$1"

  # Extract meaningful words (lowercase, remove punctuation, filter common words)
  echo "$text" | tr '[:upper:]' '[:lower:]' | \
    grep -oE '\b[a-z]{3,}\b' | \
    grep -vE '^(the|and|for|with|this|that|from|will|can|use|using|help|when|how|what|where)$' | \
    sort -u | \
    head -20
}

# Initialize capabilities array
CAPABILITIES="[]"

# Scan commands directory
if [[ -d "$PLUGIN_DIR/commands" ]]; then
  while IFS= read -r -d '' cmd_file; do
    cmd_name=$(basename "$cmd_file" .md)

    # Extract frontmatter
    frontmatter=$(extract_frontmatter "$cmd_file" || echo "")

    # Parse fields from frontmatter (simple key: value extraction)
    description=$(echo "$frontmatter" | grep -E '^description:' | sed 's/^description:[[:space:]]*//' || echo "")

    # Extract keywords from description
    keywords_text="$description command $cmd_name"
    keywords=$(extract_keywords "$keywords_text" | jq -R . | jq -s .)

    # Build capability object
    capability=$(jq -n \
      --arg id "$PLUGIN_NAME:$cmd_name" \
      --arg name "$cmd_name" \
      --arg type "command" \
      --arg plugin "$PLUGIN_NAME" \
      --arg desc "$description" \
      --arg invoke "/$PLUGIN_NAME/$cmd_name" \
      --arg status "$PLUGIN_STATUS" \
      --argjson install_count "$INSTALL_COUNT" \
      --argjson keywords "$keywords" \
      '{
        id: $id,
        name: $name,
        type: $type,
        plugin: $plugin,
        description: $desc,
        invocation: $invoke,
        status: $status,
        install_count: $install_count,
        keywords: $keywords,
        usage_count: 0,
        success_rate: 1.0,
        last_used: null
      }')

    # Add to capabilities array
    CAPABILITIES=$(echo "$CAPABILITIES" | jq --argjson cap "$capability" '. += [$cap]')

  done < <(find "$PLUGIN_DIR/commands" -name "*.md" -type f -print0 2>/dev/null || true)
fi

# Scan agents directory
if [[ -d "$PLUGIN_DIR/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    agent_name=$(basename "$agent_file" .md)

    # Extract frontmatter
    frontmatter=$(extract_frontmatter "$agent_file" || echo "")

    # Parse fields
    description=$(echo "$frontmatter" | grep -E '^description:' | sed 's/^description:[[:space:]]*//' || echo "")

    # Extract keywords
    keywords_text="$description agent $agent_name"
    keywords=$(extract_keywords "$keywords_text" | jq -R . | jq -s .)

    # Build capability object
    capability=$(jq -n \
      --arg id "$PLUGIN_NAME:$agent_name" \
      --arg name "$agent_name" \
      --arg type "agent" \
      --arg plugin "$PLUGIN_NAME" \
      --arg desc "$description" \
      --arg invoke "Task(subagent_type=\"$PLUGIN_NAME:$agent_name\", prompt=\"...\")" \
      --arg status "$PLUGIN_STATUS" \
      --argjson install_count "$INSTALL_COUNT" \
      --argjson keywords "$keywords" \
      '{
        id: $id,
        name: $name,
        type: $type,
        plugin: $plugin,
        description: $desc,
        invocation: $invoke,
        status: $status,
        install_count: $install_count,
        keywords: $keywords,
        usage_count: 0,
        success_rate: 1.0,
        last_used: null
      }')

    CAPABILITIES=$(echo "$CAPABILITIES" | jq --argjson cap "$capability" '. += [$cap]')

  done < <(find "$PLUGIN_DIR/agents" -name "*.md" -type f -print0 2>/dev/null || true)
fi

# Scan skills directory
if [[ -d "$PLUGIN_DIR/skills" ]]; then
  while IFS= read -r -d '' skill_file; do
    skill_dir=$(dirname "$skill_file")
    skill_name=$(basename "$skill_dir")

    # Extract frontmatter
    frontmatter=$(extract_frontmatter "$skill_file" || echo "")

    # Parse fields
    description=$(echo "$frontmatter" | grep -E '^description:' | sed 's/^description:[[:space:]]*//' || echo "")

    # Extract keywords
    keywords_text="$description skill $skill_name"
    keywords=$(extract_keywords "$keywords_text" | jq -R . | jq -s .)

    # Build capability object
    capability=$(jq -n \
      --arg id "$PLUGIN_NAME:$skill_name" \
      --arg name "$skill_name" \
      --arg type "skill" \
      --arg plugin "$PLUGIN_NAME" \
      --arg desc "$description" \
      --arg invoke "Skill(skill=\"$PLUGIN_NAME:$skill_name\")" \
      --arg status "$PLUGIN_STATUS" \
      --argjson install_count "$INSTALL_COUNT" \
      --argjson keywords "$keywords" \
      '{
        id: $id,
        name: $name,
        type: $type,
        plugin: $plugin,
        description: $desc,
        invocation: $invoke,
        status: $status,
        install_count: $install_count,
        keywords: $keywords,
        usage_count: 0,
        success_rate: 1.0,
        last_used: null
      }')

    CAPABILITIES=$(echo "$CAPABILITIES" | jq --argjson cap "$capability" '. += [$cap]')

  done < <(find "$PLUGIN_DIR/skills" -name "SKILL.md" -type f -print0 2>/dev/null || true)
fi

# Output capabilities array
echo "$CAPABILITIES"

exit 0
