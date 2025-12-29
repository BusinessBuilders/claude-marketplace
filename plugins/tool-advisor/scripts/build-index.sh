#!/usr/bin/env bash
#
# build-index.sh - Build complete capability index for tool-advisor
#
# Usage: ./build-index.sh [--force]
#
# Creates ~/.claude/tool-advisor-cache.json with all capabilities
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="$HOME/.claude/tool-advisor-cache.json"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --force)
      FORCE=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--force]" >&2
      exit 1
      ;;
  esac
done

# Check if cache exists and is fresh
if [[ -f "$CACHE_FILE" ]] && [[ "$FORCE" == "false" ]]; then
  # Get cache age in seconds
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    cache_mtime=$(stat -f %m "$CACHE_FILE")
  else
    # Linux
    cache_mtime=$(stat -c %Y "$CACHE_FILE")
  fi

  current_time=$(date +%s)
  age_seconds=$((current_time - cache_mtime))

  # If less than 1 hour old, skip
  if [[ $age_seconds -lt 3600 ]]; then
    echo "Cache is fresh (${age_seconds}s old), skipping scan. Use --force to override." >&2
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# Scan start time
SCAN_START=$(date +%s%3N)

# Discover all plugins
echo "Discovering plugins..." >&2
PLUGINS_JSON=$("$SCRIPT_DIR/scan-plugins.sh")

# Count plugins
PLUGIN_COUNT=$(echo "$PLUGINS_JSON" | jq 'length')
echo "Found $PLUGIN_COUNT plugins/skills" >&2

# Use temp file for capabilities
CAPABILITIES_FILE=$(mktemp)
trap "rm -f $CAPABILITIES_FILE" EXIT

echo "[]" > "$CAPABILITIES_FILE"

# Parse each plugin
echo "Extracting capabilities..." >&2

while IFS= read -r plugin_dir; do
  # Skip empty lines
  [[ -z "$plugin_dir" ]] && continue

  # Check for plugin manifest
  manifest_path="$plugin_dir/.claude-plugin/plugin.json"

  if [[ -f "$manifest_path" ]]; then
    # Parse manifest
    plugin_meta=$("$SCRIPT_DIR/parse-manifest.sh" "$manifest_path" 2>/dev/null || echo '{}')
    plugin_name=$(echo "$plugin_meta" | jq -r '.name // "unknown"')

    echo "  Scanning: $plugin_name" >&2

    # Extract capabilities from this plugin
    plugin_capabilities=$("$SCRIPT_DIR/extract-capabilities.sh" "$plugin_dir" "$plugin_name" 2>/dev/null || echo '[]')

    # Append to capabilities file
    jq --argjson new "$plugin_capabilities" '. += $new' "$CAPABILITIES_FILE" > "$CAPABILITIES_FILE.tmp"
    mv "$CAPABILITIES_FILE.tmp" "$CAPABILITIES_FILE"

  elif [[ -f "$plugin_dir/SKILL.md" ]]; then
    # Standalone skill
    skill_name=$(basename "$plugin_dir")
    echo "  Scanning skill: $skill_name" >&2

    # Extract skill metadata
    skill_capabilities=$("$SCRIPT_DIR/extract-capabilities.sh" "$plugin_dir" "$skill_name" 2>/dev/null || echo '[]')

    # Append to capabilities file
    jq --argjson new "$skill_capabilities" '. += $new' "$CAPABILITIES_FILE" > "$CAPABILITIES_FILE.tmp"
    mv "$CAPABILITIES_FILE.tmp" "$CAPABILITIES_FILE"
  fi

done < <(echo "$PLUGINS_JSON" | jq -r '.[]')

# Scan end time
SCAN_END=$(date +%s%3N)
SCAN_DURATION=$((SCAN_END - SCAN_START))

# Build keyword index (keyword -> capability IDs)
KEYWORD_INDEX=$(cat "$CAPABILITIES_FILE" | jq 'reduce .[] as $cap ({};
  reduce $cap.keywords[] as $kw (.;
    .[$kw] = ((.[$kw] // []) + [$cap.id])
  )
)')

# Build plugin index (plugin -> capability IDs)
PLUGIN_INDEX=$(cat "$CAPABILITIES_FILE" | jq 'group_by(.plugin) |
  reduce .[] as $group ({};
    .[$group[0].plugin] = ($group | map(.id))
  )
')

# Build complete index structure using temp files to avoid arg limits
TEMP_INDEX=$(mktemp)
trap "rm -f $TEMP_INDEX" EXIT

# Create base structure
cat > "$TEMP_INDEX" << EOF
{
  "version": "1.0.0",
  "last_scan": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "scan_locations": ["$HOME/.claude/plugins/marketplaces", "$HOME/.claude/plugins", "$HOME/.claude/skills"],
  "total_plugins": $PLUGIN_COUNT,
  "scan_duration_ms": $SCAN_DURATION
}
EOF

# Merge with capabilities, keyword index, and plugin index using stdin
jq -s '.[0] + {
  capabilities: .[1],
  total_capabilities: (.[1] | length),
  keyword_index: .[2],
  plugin_index: .[3],
  statistics: {
    scan_duration_ms: .[0].scan_duration_ms,
    plugins_scanned: .[0].total_plugins,
    plugins_skipped: 0,
    capabilities_found: (.[1] | length),
    capabilities_updated: 0,
    errors: []
  }
}' "$TEMP_INDEX" "$CAPABILITIES_FILE" \
  <(echo "$KEYWORD_INDEX") \
  <(echo "$PLUGIN_INDEX") > "$CACHE_FILE"

echo "✓ Index saved to $CACHE_FILE" >&2
echo "  Duration: ${SCAN_DURATION}ms" >&2
echo "  Plugins: $PLUGIN_COUNT" >&2
echo "  Capabilities: $(cat "$CACHE_FILE" | jq '.total_capabilities')" >&2

# Output the index
cat "$CACHE_FILE"

exit 0
