#!/usr/bin/env bash
#
# scan-plugins.sh - Discover all installed Claude Code plugins
#
# Usage: ./scan-plugins.sh [scan_location...]
#
# Outputs JSON array of plugin paths
#

set -euo pipefail

# Default scan locations
DEFAULT_LOCATIONS=(
  "$HOME/.claude/plugins/marketplaces"
  "$HOME/.claude/plugins"
  "$HOME/.claude/skills"
)

# Use provided locations or defaults
SCAN_LOCATIONS=("${@:-${DEFAULT_LOCATIONS[@]}}")

# JSON array to collect results
PLUGINS=()

# Find all plugin.json files
find_plugins() {
  local location="$1"

  # Skip if location doesn't exist
  if [[ ! -d "$location" ]]; then
    return
  fi

  # Find all plugin.json files in .claude-plugin directories
  while IFS= read -r -d '' manifest; do
    # Get plugin directory (parent of .claude-plugin)
    plugin_dir="$(dirname "$(dirname "$manifest")")"

    # Verify it's a valid plugin directory
    if [[ -f "$manifest" ]]; then
      PLUGINS+=("$plugin_dir")
    fi
  done < <(find "$location" -name "plugin.json" -path "*/.claude-plugin/*" -print0 2>/dev/null)
}

# Scan each location
for location in "${SCAN_LOCATIONS[@]}"; do
  find_plugins "$location"
done

# Also scan for standalone skills (SKILL.md files)
find_skills() {
  local skills_dir="$HOME/.claude/skills"

  if [[ ! -d "$skills_dir" ]]; then
    return
  fi

  while IFS= read -r -d '' skill_file; do
    # Get skill directory (parent of SKILL.md)
    skill_dir="$(dirname "$skill_file")"
    PLUGINS+=("$skill_dir")
  done < <(find "$skills_dir" -name "SKILL.md" -type f -print0 2>/dev/null)
}

find_skills

# Output as JSON array
printf '[\n'
for i in "${!PLUGINS[@]}"; do
  printf '  "%s"' "${PLUGINS[$i]}"
  if [[ $i -lt $((${#PLUGINS[@]} - 1)) ]]; then
    printf ','
  fi
  printf '\n'
done
printf ']\n'

# Exit with count as status (0 if no plugins found)
exit 0
