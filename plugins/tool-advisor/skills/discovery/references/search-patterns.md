# Search Patterns and Matching Reference

Comprehensive guide to keyword extraction, search pattern matching, and capability ranking algorithms.

## Overview

The tool-advisor uses multi-factor matching to rank capabilities against user tasks. This involves keyword extraction, semantic matching, and weighted scoring.

## Keyword Extraction

### From User Queries

Extract searchable keywords from user input:

#### 1. Normalize Text

```typescript
function normalizeText(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, ' ')  // Remove punctuation
    .replace(/\s+/g, ' ')        // Collapse whitespace
    .trim();
}
```

#### 2. Remove Stop Words

```typescript
const STOP_WORDS = new Set([
  'a', 'an', 'the', 'is', 'are', 'was', 'were',
  'to', 'for', 'of', 'in', 'on', 'at', 'by',
  'i', 'me', 'my', 'we', 'you', 'can', 'could',
  'will', 'would', 'should', 'do', 'does', 'did'
]);

function removeStopWords(words: string[]): string[] {
  return words.filter(word => !STOP_WORDS.has(word));
}
```

#### 3. Extract Noun Phrases

```typescript
function extractNounPhrases(text: string): string[] {
  const normalized = normalizeText(text);
  const words = normalized.split(' ');
  const filtered = removeStopWords(words);

  // Extract multi-word phrases
  const phrases: string[] = [];

  // Single words
  phrases.push(...filtered);

  // Two-word combinations
  for (let i = 0; i < filtered.length - 1; i++) {
    phrases.push(`${filtered[i]} ${filtered[i + 1]}`);
  }

  return phrases;
}
```

Example:
- Input: "Help me deploy my application to AWS"
- Output: ["help", "deploy", "application", "aws", "help deploy", "deploy application", "application aws"]

### From Capability Descriptions

Extract keywords from capability metadata:

#### From Names

```typescript
function extractKeywordsFromName(name: string): string[] {
  // Split on hyphens, underscores, and camelCase
  return name
    .replace(/([a-z])([A-Z])/g, '$1 $2')  // camelCase
    .split(/[-_\s]+/)
    .map(w => w.toLowerCase())
    .filter(w => w.length > 2);
}
```

Example:
- "terraform-specialist" → ["terraform", "specialist"]
- "CodeReviewAgent" → ["code", "review", "agent"]

#### From Descriptions

```typescript
function extractKeywordsFromDescription(desc: string): string[] {
  const normalized = normalizeText(desc);
  const words = normalized.split(' ');
  const filtered = removeStopWords(words);

  // Weight technical terms higher
  const technicalTerms = filtered.filter(w =>
    /^(aws|azure|gcp|terraform|kubernetes|docker|api|sql|nosql|react|vue|python|node|java)/.test(w)
  );

  return [...new Set([...filtered, ...technicalTerms])];
}
```

#### From Trigger Examples

```typescript
function extractKeywordsFromTriggers(triggers: string[]): string[] {
  const allKeywords = triggers.flatMap(trigger => {
    const normalized = normalizeText(trigger);
    const words = normalized.split(' ');
    return removeStopWords(words);
  });

  return [...new Set(allKeywords)];
}
```

## Matching Algorithms

### Exact Keyword Match

```typescript
function exactKeywordMatch(query: string[], capabilityKeywords: string[]): number {
  const matches = query.filter(q => capabilityKeywords.includes(q));
  return matches.length / query.length;  // 0.0 - 1.0
}
```

### Fuzzy String Matching

Use Levenshtein distance for typo tolerance:

```typescript
function fuzzyMatch(a: string, b: string): number {
  const distance = levenshteinDistance(a, b);
  const maxLength = Math.max(a.length, b.length);
  return 1 - (distance / maxLength);  // 0.0 - 1.0
}

function levenshteinDistance(a: string, b: string): number {
  const matrix: number[][] = [];

  for (let i = 0; i <= b.length; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= a.length; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      if (b.charAt(i - 1) === a.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,  // substitution
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j] + 1       // deletion
        );
      }
    }
  }

  return matrix[b.length][a.length];
}
```

### Semantic Similarity

Match by meaning rather than exact words:

```typescript
const SYNONYMS: Record<string, string[]> = {
  'deploy': ['deployment', 'release', 'ship', 'publish'],
  'test': ['testing', 'check', 'verify', 'validate'],
  'review': ['analyze', 'inspect', 'audit', 'examine'],
  'debug': ['troubleshoot', 'diagnose', 'fix'],
  'build': ['compile', 'construct', 'create', 'generate'],
};

function expandWithSynonyms(keyword: string): string[] {
  const expanded = [keyword];
  for (const [base, synonyms] of Object.entries(SYNONYMS)) {
    if (synonyms.includes(keyword) || base === keyword) {
      expanded.push(base, ...synonyms);
    }
  }
  return [...new Set(expanded)];
}
```

### Capability Type Matching

Prefer certain capability types based on query patterns:

```typescript
function inferPreferredType(query: string): CapabilityType | null {
  const lower = query.toLowerCase();

  if (lower.includes('run') || lower.includes('execute')) {
    return 'command';
  }
  if (lower.includes('help') || lower.includes('guide')) {
    return 'skill';
  }
  if (lower.includes('automatically') || lower.includes('whenever')) {
    return 'hook';
  }
  // Default to agent for complex tasks
  if (query.length > 50) {
    return 'agent';
  }

  return null;
}
```

## Ranking Algorithm

### Multi-Factor Scoring

Combine multiple signals to rank capabilities:

```typescript
interface ScoringWeights {
  keyword_match: number;      // 35%
  capability_type: number;    // 25%
  user_history: number;       // 20%
  tool_freshness: number;     // 10%
  success_rate: number;       // 10%
}

const DEFAULT_WEIGHTS: ScoringWeights = {
  keyword_match: 0.35,
  capability_type: 0.25,
  user_history: 0.20,
  tool_freshness: 0.10,
  success_rate: 0.10,
};

function scoreCapability(
  query: string,
  capability: Capability,
  weights: ScoringWeights = DEFAULT_WEIGHTS
): number {
  // Extract query keywords
  const queryKeywords = extractNounPhrases(query);

  // 1. Keyword Match Score (0.0 - 1.0)
  const keywordScore = calculateKeywordScore(queryKeywords, capability.keywords);

  // 2. Capability Type Score (0.0 - 1.0)
  const preferredType = inferPreferredType(query);
  const typeScore = preferredType === capability.type ? 1.0 : 0.5;

  // 3. User History Score (0.0 - 1.0)
  const historyScore = Math.min(capability.usage_count / 10, 1.0);

  // 4. Tool Freshness Score (0.0 - 1.0)
  const freshnessScore = calculateFreshnessScore(capability.last_used);

  // 5. Success Rate (0.0 - 1.0)
  const successScore = capability.success_rate;

  // Weighted sum
  const totalScore =
    keywordScore * weights.keyword_match +
    typeScore * weights.capability_type +
    historyScore * weights.user_history +
    freshnessScore * weights.tool_freshness +
    successScore * weights.success_rate;

  // Apply confidence boost from user preferences
  const finalScore = Math.max(0, Math.min(1, totalScore + capability.confidence_boost));

  return finalScore;
}
```

### Keyword Score Calculation

```typescript
function calculateKeywordScore(queryKeywords: string[], capabilityKeywords: string[]): number {
  let score = 0;
  let maxPossibleScore = 0;

  for (const queryKeyword of queryKeywords) {
    maxPossibleScore += 1.0;

    // Check for exact match
    if (capabilityKeywords.includes(queryKeyword)) {
      score += 1.0;
      continue;
    }

    // Check for fuzzy match
    const fuzzyScores = capabilityKeywords.map(ck =>
      fuzzyMatch(queryKeyword, ck)
    );
    const bestFuzzy = Math.max(...fuzzyScores);
    if (bestFuzzy > 0.8) {  // 80% similarity threshold
      score += bestFuzzy;
      continue;
    }

    // Check for synonym match
    const expandedQuery = expandWithSynonyms(queryKeyword);
    const hasSynonym = expandedQuery.some(eq =>
      capabilityKeywords.includes(eq)
    );
    if (hasSynonym) {
      score += 0.9;  // Slightly lower than exact match
      continue;
    }
  }

  return maxPossibleScore > 0 ? score / maxPossibleScore : 0;
}
```

### Freshness Score Calculation

```typescript
function calculateFreshnessScore(lastUsed: string | null): number {
  if (!lastUsed) {
    return 0.5;  // Neutral for never-used tools
  }

  const now = Date.now();
  const used = new Date(lastUsed).getTime();
  const ageMs = now - used;

  // Decay over 30 days
  const dayMs = 24 * 60 * 60 * 1000;
  const ageDays = ageMs / dayMs;

  if (ageDays < 1) return 1.0;    // Used today
  if (ageDays < 7) return 0.9;    // Used this week
  if (ageDays < 30) return 0.7;   // Used this month
  return 0.5;                      // Older than a month
}
```

## Ranking and Filtering

### Top-K Results

```typescript
function getTopRecommendations(
  query: string,
  capabilities: Capability[],
  k: number = 3
): ScoredCapability[] {
  const scored = capabilities.map(cap => ({
    capability: cap,
    score: scoreCapability(query, cap)
  }));

  // Filter low-confidence results
  const filtered = scored.filter(s => s.score > 0.1);

  // Sort by score descending
  filtered.sort((a, b) => b.score - a.score);

  // Return top K
  return filtered.slice(0, k);
}
```

### Confidence Thresholds

```typescript
function getRecommendationTier(score: number): 'high' | 'medium' | 'low' {
  if (score >= 0.90) return 'high';   // Auto-use
  if (score >= 0.70) return 'medium'; // Suggest
  return 'low';                        // Don't show
}
```

## Optimization Techniques

### Index Pre-computation

Pre-compute keyword expansions and store in index:

```typescript
function buildEnrichedIndex(capabilities: Capability[]): EnrichedIndex {
  return capabilities.map(cap => ({
    ...cap,
    expanded_keywords: cap.keywords.flatMap(expandWithSynonyms),
    normalized_name: normalizeText(cap.name),
    normalized_description: normalizeText(cap.description)
  }));
}
```

### Caching Search Results

Cache recent searches:

```typescript
const searchCache = new Map<string, ScoredCapability[]>();

function cachedSearch(query: string, capabilities: Capability[]): ScoredCapability[] {
  const cacheKey = normalizeText(query);

  if (searchCache.has(cacheKey)) {
    return searchCache.get(cacheKey)!;
  }

  const results = getTopRecommendations(query, capabilities);
  searchCache.set(cacheKey, results);

  return results;
}
```

### Early Termination

Stop scoring once confidence is high enough:

```typescript
function findBestMatch(query: string, capabilities: Capability[]): Capability | null {
  let bestMatch: Capability | null = null;
  let bestScore = 0;

  for (const capability of capabilities) {
    const score = scoreCapability(query, capability);

    if (score > bestScore) {
      bestScore = score;
      bestMatch = capability;
    }

    // Early termination for very high confidence
    if (score >= 0.95) {
      return capability;
    }
  }

  return bestMatch;
}
```

## Advanced Patterns

### Context-Aware Ranking

Boost scores based on current project context:

```typescript
function contextAwareScore(
  query: string,
  capability: Capability,
  projectContext: ProjectContext
): number {
  let score = scoreCapability(query, capability);

  // Boost project-local capabilities
  if (capability.path.startsWith(projectContext.projectRoot)) {
    score += 0.1;
  }

  // Boost based on project tech stack
  for (const tech of projectContext.technologies) {
    if (capability.keywords.includes(tech.toLowerCase())) {
      score += 0.05;
    }
  }

  return Math.min(score, 1.0);
}
```

### Learning from Feedback

Update rankings based on user acceptance:

```typescript
function recordFeedback(
  query: string,
  acceptedCapability: Capability,
  rejectedCapabilities: Capability[]
): void {
  // Boost accepted capability
  acceptedCapability.confidence_boost += 0.05;

  // Penalize rejected capabilities
  for (const rejected of rejectedCapabilities) {
    rejected.confidence_boost -= 0.02;
  }

  // Clamp to [-1.0, 1.0]
  acceptedCapability.confidence_boost = Math.max(-1, Math.min(1, acceptedCapability.confidence_boost));
  rejectedCapabilities.forEach(r => {
    r.confidence_boost = Math.max(-1, Math.min(1, r.confidence_boost));
  });
}
```

## Example Usage

```typescript
// User query
const query = "Help me deploy my React app to AWS";

// Load capabilities
const index = loadCapabilityIndex();
const capabilities = index.capabilities;

// Get recommendations
const recommendations = getTopRecommendations(query, capabilities, 3);

// Display results
for (const { capability, score } of recommendations) {
  const tier = getRecommendationTier(score);
  console.log(`${capability.name} (${(score * 100).toFixed(0)}% match) [${tier}]`);
}

// Expected output:
// cloud-infrastructure:deployment-engineer (94% match) [high]
// frontend-mobile-development:react-deploy (87% match) [medium]
// deployment-strategies:aws-cloudformation (78% match) [medium]
```
