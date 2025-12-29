---
name: Recommendation Strategies
description: Use this skill when analyzing user tasks to recommend appropriate tools, when user asks "What should I use for X?", "Help me with Y", "Recommend a tool for...", or before executing any significant action where tool selection matters. Provides intelligent matching algorithms and ranking strategies for recommending the best Claude Code tools for specific tasks.
version: 0.1.0
---

# Recommendation Strategies

Intelligent algorithms for matching user tasks to the most appropriate Claude Code tools, with multi-factor scoring and context-aware ranking.

## When to Use This Skill

Load this skill when you need to:

- Recommend tools for a user-described task
- Match natural language queries to capabilities
- Rank multiple tool options by suitability
- Explain why a particular tool is recommended
- Make proactive tool suggestions during conversations
- Optimize tool selection for specific contexts

## Core Recommendation Process

### 1. Analyze User Intent

Extract the essential information from the user's request:

```typescript
interface TaskIntent {
  primary_action: string;      // deploy, test, review, debug, build
  target: string | null;       // what's being acted upon
  constraints: string[];       // requirements or preferences
  context: string[];           // environmental factors
  urgency: 'low' | 'medium' | 'high';
}
```

**Example**:
- Query: "Help me deploy my React app to AWS production"
- Intent:
  - primary_action: "deploy"
  - target: "React app"
  - constraints: ["AWS", "production"]
  - context: ["React", "AWS"]
  - urgency: "high"

### 2. Load Capability Index

```typescript
const index = loadCapabilityIndex();  // From ~/.claude/tool-advisor-cache.json
const capabilities = index.capabilities;
```

If cache doesn't exist or is stale (> 1 hour old), trigger a scan first.

### 3. Filter Candidates

Narrow down capabilities based on hard requirements:

```typescript
function filterCandidates(
  capabilities: Capability[],
  intent: TaskIntent,
  settings: UserSettings
): Capability[] {
  return capabilities.filter(cap => {
    // Exclude user-blacklisted plugins
    if (isExcluded(cap.plugin, settings.exclude_plugins)) {
      return false;
    }

    // Minimum keyword overlap
    const keywords = extractKeywords(intent);
    const overlap = cap.keywords.filter(k => keywords.includes(k));
    if (overlap.length === 0) {
      return false;  // No relevance at all
    }

    return true;
  });
}
```

### 4. Score Each Candidate

Apply multi-factor scoring algorithm:

```typescript
interface ScoringFactors {
  keyword_match: number;      // 35% - How well keywords match
  capability_type: number;    // 25% - Agent vs command vs skill fit
  user_history: number;       // 20% - Usage frequency
  tool_freshness: number;     // 10% - Recent usage
  success_rate: number;       // 10% - Historical success
}

function scoreCapability(
  query: string,
  capability: Capability,
  history: UsageHistory
): number {
  const weights = {
    keyword_match: 0.35,
    capability_type: 0.25,
    user_history: 0.20,
    tool_freshness: 0.10,
    success_rate: 0.10,
  };

  const scores = {
    keyword_match: calculateKeywordScore(query, capability),
    capability_type: calculateTypeScore(query, capability),
    user_history: calculateHistoryScore(capability, history),
    tool_freshness: calculateFreshnessScore(capability),
    success_rate: capability.success_rate,
  };

  // Weighted sum
  let total = Object.keys(weights).reduce((sum, key) => {
    return sum + weights[key] * scores[key];
  }, 0);

  // Apply user preference boost
  total += capability.confidence_boost;

  // Clamp to [0, 1]
  return Math.max(0, Math.min(1, total));
}
```

See `references/search-patterns.md` in the discovery skill for detailed scoring algorithms.

### 5. Rank and Select

```typescript
function rankCapabilities(
  candidates: Capability[],
  query: string
): ScoredCapability[] {
  const scored = candidates.map(cap => ({
    capability: cap,
    score: scoreCapability(query, cap)
  }));

  // Sort by score descending
  scored.sort((a, b) => b.score - a.score);

  return scored;
}
```

### 6. Apply Confidence Thresholds

Determine how to present recommendations based on score:

```typescript
function determineRecommendationStrategy(score: number): Strategy {
  if (score >= 0.90) {
    return 'auto_use';     // Very high confidence - use immediately
  }
  if (score >= 0.70) {
    return 'suggest_one';  // High confidence - show top pick
  }
  if (score >= 0.50) {
    return 'suggest_many'; // Medium confidence - show top 3
  }
  return 'insufficient';   // Low confidence - ask for clarification
}
```

## Scoring Factor Details

### Keyword Match Score (35%)

Measures semantic similarity between query and capability:

1. **Extract keywords** from user query
2. **Expand with synonyms** (deploy → release, ship, publish)
3. **Match against** capability keywords
4. **Score by overlap** and relevance

Formula:
```
keyword_score = (exact_matches + 0.9 * synonym_matches + 0.8 * fuzzy_matches) / total_query_keywords
```

**Example**:
- Query: "deploy to production"
- Keywords: ["deploy", "production"]
- Capability keywords: ["deployment", "release", "production", "ci-cd"]
- Matches: "deploy"/"deployment" (synonym), "production" (exact)
- Score: (0.9 + 1.0) / 2 = 0.95

### Capability Type Score (25%)

Prefers appropriate capability types based on query pattern:

| Query Pattern | Preferred Type | Score |
|---------------|----------------|-------|
| "run...", "execute..." | command | 1.0 |
| "help...", "how to..." | skill | 1.0 |
| "automatically...", "whenever..." | hook | 1.0 |
| Complex multi-step task | agent | 1.0 |
| Other types | - | 0.5 |

**Example**:
- Query: "Automatically suggest tools when I start a task"
- Type inference: hook (keyword "automatically")
- Capability type: hook
- Score: 1.0

### User History Score (20%)

Rewards frequently-used tools:

```
history_score = min(usage_count / 10, 1.0)
```

**Example**:
- usage_count = 15
- Score: min(15/10, 1.0) = 1.0

### Tool Freshness Score (10%)

Rewards recently-used tools:

| Last Used | Score |
|-----------|-------|
| < 1 day | 1.0 |
| 1-7 days | 0.9 |
| 7-30 days | 0.7 |
| > 30 days or never | 0.5 |

**Example**:
- last_used: 2 days ago
- Score: 0.9

### Success Rate Score (10%)

Based on historical success of this tool:

```
success_rate = (successes / total_uses)
```

Tracked with exponential moving average:
```
new_rate = 0.2 * current_result + 0.8 * previous_rate
```

**Example**:
- 18 successes out of 20 uses
- Score: 0.90

## Recommendation Presentation

### High Confidence (≥90%)

**Auto-use with brief notification**:

```
💡 Using cloud-infrastructure:deployment-engineer (94% match) for AWS deployment

Deploying your React application...
```

### Medium Confidence (70-89%)

**Show top recommendation with explanation**:

```
I recommend using **deployment-strategies:blue-green-deploy** (87% match) because:
- Matches your deployment needs
- Supports AWS infrastructure
- Handles production rollouts safely
- You've used it successfully 12 times before

Would you like me to proceed with this tool?
```

### Low Confidence (50-69%)

**Show top 3 options for user choice**:

```
I found 3 tools that might help with deploying to AWS:

1. **cloud-infrastructure:deployment-engineer** (68% match)
   - Full-service deployment automation
   - Best for complex AWS setups

2. **deployment-strategies:aws-cloudformation** (65% match)
   - Infrastructure as code approach
   - Best for reproducible deployments

3. **cicd-automation:aws-pipeline** (62% match)
   - CI/CD pipeline automation
   - Best for automated deployments

Which would you prefer?
```

### Insufficient Confidence (<50%)

**Ask for clarification**:

```
I need more information to recommend the right tool. Could you clarify:
- What type of application are you deploying?
- What AWS services are you using?
- Is this a first-time deployment or an update?
```

## Context-Aware Enhancements

### Project Context Integration

Boost scores for project-relevant tools:

```typescript
function applyProjectContext(
  score: number,
  capability: Capability,
  projectContext: ProjectContext
): number {
  let adjusted = score;

  // Boost project-local tools
  if (capability.path.startsWith(projectContext.root)) {
    adjusted += 0.10;
  }

  // Boost based on detected technologies
  for (const tech of projectContext.technologies) {
    if (capability.keywords.includes(tech.toLowerCase())) {
      adjusted += 0.05;
    }
  }

  // Boost based on project type
  if (projectContext.type === 'web' && capability.tags.includes('frontend')) {
    adjusted += 0.05;
  }

  return Math.min(adjusted, 1.0);
}
```

### User Preference Learning

Track which recommendations user accepts:

```typescript
interface UserPreferences {
  preferred_tools: Record<string, string>;  // task_type -> tool_id
  rejected_tools: Set<string>;
  preferred_types: Record<string, CapabilityType>;
}

function applyUserPreferences(
  score: number,
  capability: Capability,
  taskType: string,
  prefs: UserPreferences
): number {
  // Strong boost for explicitly preferred tools
  if (prefs.preferred_tools[taskType] === capability.id) {
    return Math.min(score + 0.20, 1.0);
  }

  // Penalty for previously rejected tools
  if (prefs.rejected_tools.has(capability.id)) {
    return Math.max(score - 0.15, 0.0);
  }

  return score;
}
```

## Advanced Recommendation Patterns

### Multi-Tool Workflows

For complex tasks requiring multiple tools:

```typescript
function recommendWorkflow(query: string): ToolWorkflow {
  const steps = decomposeTask(query);

  return steps.map(step => ({
    step: step.description,
    recommended_tool: rankCapabilities(
      filterCandidates(capabilities, step),
      step.query
    )[0]
  }));
}
```

**Example**:
- Query: "Set up CI/CD pipeline for my Node.js app"
- Workflow:
  1. Test setup → tdd-workflows:configure-testing
  2. Build configuration → build-automation:node-builder
  3. Deployment pipeline → cicd-automation:pipeline-setup

### Fallback Recommendations

When no good match exists, recommend learning resources:

```typescript
function generateFallbacks(query: string): Recommendation[] {
  return [
    {
      type: 'skill',
      name: 'Related Documentation',
      action: 'Show available skills that might help you build this capability'
    },
    {
      type: 'command',
      name: 'Manual Execution',
      action: 'I can help you accomplish this task step-by-step without a specialized tool'
    },
    {
      type: 'suggestion',
      name: 'Create Custom Tool',
      action: 'Would you like to create a custom agent or command for this task?'
    }
  ];
}
```

## Performance Optimization

### Caching Strategies

Cache recent recommendations:

```typescript
const recommendationCache = new Map<string, ScoredCapability[]>();
const CACHE_TTL = 5 * 60 * 1000;  // 5 minutes

function getCachedRecommendation(query: string): ScoredCapability[] | null {
  const key = normalizeText(query);
  const cached = recommendationCache.get(key);

  if (cached && (Date.now() - cached.timestamp) < CACHE_TTL) {
    return cached.results;
  }

  return null;
}
```

### Incremental Scoring

Stop scoring once high-confidence match is found:

```typescript
function findBestMatch(query: string): Capability | null {
  const candidates = filterCandidates(capabilities, parseIntent(query));

  for (const candidate of candidates) {
    const score = scoreCapability(query, candidate);

    if (score >= 0.95) {
      return candidate;  // Early exit for very high confidence
    }
  }

  // Continue with full ranking if no high-confidence match
  return rankCapabilities(candidates, query)[0]?.capability || null;
}
```

## Integration with Tool Advisor

This skill powers:

- **recommendation-engine agent**: Autonomous matching and ranking
- **proactive-advisor agent**: Contextual tool suggestions
- **/tool-advisor:recommend command**: Explicit recommendations

Use this skill whenever you need to intelligently match tasks to available tools.

## Best Practices

1. **Always explain recommendations**: Show why a tool was suggested
2. **Respect user preferences**: Honor preferred/rejected tools
3. **Consider context**: Use project and conversation context
4. **Handle ambiguity**: Ask clarifying questions when confidence is low
5. **Learn from feedback**: Update scores based on user acceptance
6. **Provide alternatives**: Show multiple options when appropriate
7. **Fallback gracefully**: Offer manual help when no good match exists

## Example Usage

```typescript
// User query
const query = "Help me review this pull request for security issues";

// 1. Parse intent
const intent = parseIntent(query);
// { primary_action: "review", target: "pull request", constraints: ["security"] }

// 2. Filter candidates
const candidates = filterCandidates(capabilities, intent, userSettings);

// 3. Rank capabilities
const ranked = rankCapabilities(candidates, query);

// 4. Get top recommendation
const top = ranked[0];
// { capability: security-scanning:pr-scanner, score: 0.93 }

// 5. Determine strategy
const strategy = determineRecommendationStrategy(top.score);
// "auto_use"

// 6. Execute
console.log(`💡 Using ${top.capability.name} (93% match) for security PR review`);
// Proceed with the tool
```
