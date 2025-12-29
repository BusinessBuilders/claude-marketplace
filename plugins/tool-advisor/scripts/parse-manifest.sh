#!/usr/bin/env bash
#
# parse-manifest.sh - Extract metadata from a plugin.json manifest
#
# Usage: ./parse-manifest.sh <path-to-plugin.json>
#
# Outputs JSON with extracted plugin metadata
#

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-plugin.json>" >&2
  exit 1
fi

MANIFEST_PATH="$1"

# Verify manifest exists
if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "{\"error\": \"Manifest not found: $MANIFEST_PATH\"}" >&2
  exit 1
fi

# Verify it's valid JSON
if ! jq empty "$MANIFEST_PATH" 2>/dev/null; then
  echo "{\"error\": \"Invalid JSON in manifest: $MANIFEST_PATH\"}" >&2
  exit 1
fi

# Extract metadata using jq
jq '{
  name: .name,
  version: (.version // "0.0.0"),
  description: (.description // ""),
  author: (.author // null),
  keywords: (.keywords // []),
  homepage: (.homepage // null),
  repository: (.repository // null),
  license: (.license // null)
}' "$MANIFEST_PATH"

exit 0
