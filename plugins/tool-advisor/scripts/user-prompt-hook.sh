#!/usr/bin/env bash
#
# user-prompt-hook.sh - UserPromptSubmit hook
#
# Analyzes user prompt against capability cache using multi-factor scoring
# from the recommendation skill algorithm (35% keyword, 25% type, 20% status, etc.)
#
# Outputs systemMessage to guide Claude toward specialized tools/skills
#

set -euo pipefail

CACHE_FILE="$HOME/.claude/tool-advisor-cache.json"
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || echo "")

[[ -z "$PROMPT" ]] && exit 0
[[ ! -f "$CACHE_FILE" ]] && exit 0

PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# ============================================================================
# DIRECT SKILL TRIGGERS - High confidence auto-invocation patterns
# ============================================================================

# Auto-optimize / project setup
if echo "$PROMPT_LOWER" | grep -qE '(optimize.*setup|auto.?optimize|get.*started|analyze.*improve|read.*project\.md)'; then
  echo '{"systemMessage": "🎯 INVOKE: Use Skill(skill=\"tool-advisor:auto-optimize\") for automated project analysis and agent orchestration."}'
  exit 0
fi

# Multi-agent orchestration
if echo "$PROMPT_LOWER" | grep -qE '(spawn.*agent|launch.*agent|orchestrate.*workflow|delegate.*work|multi.*agent|parallel.*agent)'; then
  echo '{"systemMessage": "🎯 INVOKE: Use Skill(skill=\"tool-advisor:workflow-orchestrator\") for multi-agent workflow orchestration with parallel/sequential execution."}'
  exit 0
fi

# Tool discovery
if echo "$PROMPT_LOWER" | grep -qE '(what.*tools|show.*capabilities|list.*plugins|discover.*available|what.*can.*do)'; then
  echo '{"systemMessage": "🎯 INVOKE: Use Skill(skill=\"tool-advisor:discovery\") to discover and list all available tools, skills, and agents."}'
  exit 0
fi

# Tool recommendations
if echo "$PROMPT_LOWER" | grep -qE '(recommend.*tool|what.*should.*use|suggest.*tool|best.*for|help.*choose|which.*tool)'; then
  echo '{"systemMessage": "🎯 INVOKE: Use Skill(skill=\"tool-advisor:recommend\") for intelligent tool recommendations with multi-factor scoring."}'
  exit 0
fi

# ============================================================================
# MULTI-FACTOR KEYWORD MATCHING - Against capability cache
# ============================================================================

# Task keywords to scan (high-value action words)
KEYWORDS="deploy test review debug build security database api frontend backend mobile performance docker kubernetes git cicd optimize analyze create implement fix refactor migrate validate"

BEST_MATCH=""
BEST_SCORE=0
BEST_TYPE=""
BEST_DESC=""
BEST_INVOKE=""

for kw in $KEYWORDS; do
  if echo "$PROMPT_LOWER" | grep -qwE "$kw"; then
    # Query keyword index from cache
    MATCHES=$(jq -r ".keyword_index[\"$kw\"] // [] | .[]" "$CACHE_FILE" 2>/dev/null || echo "")

    for match in $MATCHES; do
      [[ -z "$match" || "$match" == "null" ]] && continue

      # Get capability details
      CAP=$(jq -r ".capabilities[] | select(.id == \"$match\")" "$CACHE_FILE" 2>/dev/null || echo "")
      [[ -z "$CAP" || "$CAP" == "null" ]] && continue

      TYPE=$(echo "$CAP" | jq -r '.type // "unknown"')
      DESC=$(echo "$CAP" | jq -r '.description // ""')
      STATUS=$(echo "$CAP" | jq -r '.status // "discovered"')
      INVOKE=$(echo "$CAP" | jq -r '.invocation // ""')

      # ============================================================
      # MULTI-FACTOR SCORING (from recommendation skill algorithm)
      # - 35% keyword match (already matched by being here)
      # - 25% capability type preference (agents > skills > commands)
      # - 20% installation status
      # - 10% description relevance
      # - 10% base score
      # ============================================================

      SCORE=35  # Base keyword match score

      # Type scoring (agents are more powerful, prefer them)
      case "$TYPE" in
        agent) SCORE=$((SCORE + 25)) ;;
        skill) SCORE=$((SCORE + 20)) ;;
        command) SCORE=$((SCORE + 15)) ;;
        *) SCORE=$((SCORE + 5)) ;;
      esac

      # Installation status bonus
      [[ "$STATUS" == "installed" ]] && SCORE=$((SCORE + 20))

      # Description relevance (does description also mention the keyword?)
      if echo "$DESC" | grep -qiE "$kw"; then
        SCORE=$((SCORE + 10))
      fi

      # Base score
      SCORE=$((SCORE + 10))

      # Track best match
      if [[ $SCORE -gt $BEST_SCORE ]]; then
        BEST_SCORE=$SCORE
        BEST_MATCH="$match"
        BEST_TYPE="$TYPE"
        BEST_DESC="$DESC"
        BEST_INVOKE="$INVOKE"
      fi
    done

    # Only process first matching keyword for performance
    [[ -n "$BEST_MATCH" ]] && break
  fi
done

# ============================================================================
# OUTPUT BASED ON CONFIDENCE THRESHOLDS (from recommendation skill)
# ============================================================================

if [[ $BEST_SCORE -ge 90 ]]; then
  # HIGH CONFIDENCE (≥90%) - Strong suggestion to use
  echo "{\"systemMessage\": \"🎯 HIGH MATCH ($BEST_SCORE%): '$BEST_MATCH' ($BEST_TYPE) is ideal for this task. Invoke: $BEST_INVOKE\"}"
  exit 0
elif [[ $BEST_SCORE -ge 70 ]]; then
  # MEDIUM CONFIDENCE (70-89%) - Suggest as option
  echo "{\"systemMessage\": \"💡 SUGGESTION ($BEST_SCORE%): $BEST_TYPE '$BEST_MATCH' may help. $BEST_DESC\"}"
  exit 0
elif [[ $BEST_SCORE -ge 50 ]]; then
  # LOW CONFIDENCE (50-69%) - Mention availability
  echo "{\"systemMessage\": \"ℹ️ Available: '$BEST_MATCH' ($BEST_TYPE) - confidence: $BEST_SCORE%\"}"
  exit 0
fi

# No significant match - stay silent
exit 0
