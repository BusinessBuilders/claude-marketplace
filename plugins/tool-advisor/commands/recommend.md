---
name: recommend
description: Get intelligent tool recommendations for a specific task. Analyzes your query against all installed plugins, skills, and agents to suggest the best tools with confidence scores and explanations.
argument-hint: "[task-description] or --task \"description\" [--prefer type] [--exclude pattern]"
allowed-tools: ["Read", "Bash", "Glob"]
---

# Tool Recommendation Command

You are helping the user find the best tool for their task. This command analyzes the user's request against all available capabilities and provides intelligent recommendations.

## Your Task

1. **Parse the user's request** to understand what they want to do
2. **Load or scan capabilities** to ensure fresh recommendations
3. **Load the recommendation skill** to apply intelligent matching
4. **Find and rank matching tools** using multi-factor scoring
5. **Present recommendations** with confidence levels and explanations

## Step-by-Step Process

### Step 1: Parse Arguments

The user can provide the task in two formats:

**Simple format**:
```bash
/tool-advisor:recommend "deploy to AWS production"
```

**Structured format**:
```bash
/tool-advisor:recommend --task "code review" --prefer agent --exclude "legacy-*"
```

Extract:
- `task`: The main task description (required)
- `--prefer`: Preferred capability type (agent|command|skill|hook|mcp) (optional)
- `--exclude`: Glob pattern for plugins to exclude (optional)

### Step 2: Check Capability Cache

Check if `~/.claude/tool-advisor-cache.json` exists and is fresh:

```bash
if [ -f ~/.claude/tool-advisor-cache.json ]; then
  # Check age (should be < 1 hour old)
  age_seconds=$(( $(date +%s) - $(stat -c %Y ~/.claude/tool-advisor-cache.json) ))
  if [ $age_seconds -gt 3600 ]; then
    echo "Cache is stale, scanning..."
    # Trigger scan
  fi
fi
```

If cache doesn't exist or is stale:
- Run `/tool-advisor:scan-tools --quiet` first
- Wait for scan to complete
- Then proceed with recommendation

### Step 3: Load Recommendation Skill

Load the recommendation strategies skill to access matching algorithms:

```
Load the tool-advisor recommendation skill to apply intelligent ranking.
```

This skill provides:
- Multi-factor scoring algorithm
- Keyword extraction and matching
- Confidence threshold logic
- Ranking and filtering strategies

### Step 4: Load and Parse Capability Index

Read the capability index:

```typescript
const cachePath = expandPath('~/.claude/tool-advisor-cache.json');
const index = JSON.parse(readFile(cachePath));
const capabilities = index.capabilities;
```

### Step 5: Filter Candidates

Apply user preferences and constraints:

1. **Exclude user-specified patterns**:
   ```typescript
   if (excludePattern) {
     capabilities = capabilities.filter(cap =>
       !minimatch(cap.plugin, excludePattern)
     );
   }
   ```

2. **Filter by preferred type** (if specified):
   ```typescript
   if (preferType) {
     capabilities = capabilities.filter(cap =>
       cap.type === preferType
     );
   }
   ```

3. **Apply minimum relevance threshold**:
   - Extract keywords from task description
   - Filter out capabilities with zero keyword overlap

### Step 6: Score and Rank

Apply multi-factor scoring (from recommendation skill):

1. **Keyword match** (35%): Semantic similarity to task
2. **Capability type** (25%): Appropriate type for task
3. **User history** (20%): Usage frequency
4. **Tool freshness** (10%): Recent usage
5. **Success rate** (10%): Historical performance

Rank by total score descending.

### Step 7: Determine Presentation Strategy

Based on top score:

| Score Range | Strategy | Action |
|-------------|----------|--------|
| ≥ 0.90 | Auto-use | Use immediately with brief note |
| 0.70 - 0.89 | Suggest one | Show top pick with explanation |
| 0.50 - 0.69 | Suggest many | Show top 3 options |
| < 0.50 | Insufficient | Ask for clarification |

### Step 8: Present Recommendations

#### High Confidence (≥90%) - Auto-Use

```markdown
💡 **Using ${toolName}** (${score}% match)

${briefDescription}

Proceeding with this tool...
```

Then automatically invoke the recommended tool.

#### Medium Confidence (70-89%) - Suggest One

```markdown
## Recommended Tool

**${toolName}** (${score}% match)

### Why This Tool?
- ${reason1}
- ${reason2}
- ${reason3}

### How to Use
${usageExample}

Would you like me to proceed with this tool?
```

Wait for user confirmation before proceeding.

#### Low Confidence (50-69%) - Suggest Many

```markdown
## Top Recommendations for "${task}"

I found ${count} tools that might help:

### 1. ${tool1Name} (${score1}% match)
${tool1Description}
**Best for**: ${tool1UseCase}

### 2. ${tool2Name} (${score2}% match)
${tool2Description}
**Best for**: ${tool2UseCase}

### 3. ${tool3Name} (${score3}% match)
${tool3Description}
**Best for**: ${tool3UseCase}

Which would you prefer? Or would you like me to explain any of these in more detail?
```

#### Insufficient (<50%) - Ask for Clarification

```markdown
## Need More Information

I couldn't find a strong match for "${task}". To recommend the right tool, could you clarify:

${clarifyingQuestions}

Alternatively, I can:
- Show you all available ${relatedType} tools
- Help you accomplish this task step-by-step
- Create a custom tool for this specific need
```

## Examples

### Example 1: High Confidence Match

**User**: `/tool-advisor:recommend "deploy React app to AWS"`

**Your Response**:
```
💡 **Using cloud-infrastructure:deployment-engineer** (94% match)

Expert agent for AWS deployments with React support.

Analyzing your React application for deployment...
```

### Example 2: Medium Confidence Match

**User**: `/tool-advisor:recommend "review code for security"`

**Your Response**:
```
## Recommended Tool

**security-scanning:code-scanner** (87% match)

### Why This Tool?
- Specializes in security analysis
- Scans for OWASP Top 10 vulnerabilities
- Provides actionable remediation advice
- You've used it successfully 8 times before

### How to Use
This agent will scan your code for:
- SQL injection vulnerabilities
- XSS attack vectors
- Authentication issues
- Dependency vulnerabilities

Would you like me to proceed with the security scan?
```

### Example 3: Multiple Options

**User**: `/tool-advisor:recommend --task "test my API" --prefer agent"`

**Your Response**:
```
## Top Agent Recommendations for "test my API"

I found 3 agents that specialize in API testing:

### 1. api-testing-observability:api-tester (78% match)
Comprehensive API testing with observability integration
**Best for**: Full API test suites with monitoring

### 2. tdd-workflows:api-test-generator (72% match)
Generates API test cases from OpenAPI specs
**Best for**: Creating new test coverage

### 3. backend-development:api-validator (68% match)
Validates API responses against schemas
**Best for**: Contract testing

Which would you prefer?
```

### Example 4: No Good Match

**User**: `/tool-advisor:recommend "translate app to Klingon"`

**Your Response**:
```
## Need More Information

I couldn't find a strong match for "translate app to Klingon". To recommend the right tool, could you clarify:

- Are you looking for internationalization (i18n) tools?
- Do you need translation service integration?
- Is this for UI text or content translation?

Alternatively, I can:
- Show you all available localization tools
- Help you set up i18n step-by-step
- Create a custom translation workflow
```

## Important Notes

1. **Always load the recommendation skill** before scoring - it contains the algorithms
2. **Show confidence scores** if user settings have `show_scores: true`
3. **Explain your reasoning** - users should understand why you recommend something
4. **Respect user preferences** - check their preferred/excluded tools
5. **Update usage statistics** after user accepts a recommendation
6. **Be conversational** - you're helping them discover tools, not just listing options

## Error Handling

If cache doesn't exist:
```
I need to scan your installed tools first. Running scan now...
[Run scan-tools command]
[Retry recommendation]
```

If no capabilities match:
```
I couldn't find any installed tools that match "${task}".

You might want to:
- Install relevant plugins from the marketplace
- Check if you have the right tools installed
- Describe your task differently

Would you like me to show all available tools?
```

## Recording Feedback

When user accepts a recommendation, update the capability:

```typescript
// Increment usage count
capability.usage_count++;

// Update last_used timestamp
capability.last_used = new Date().toISOString();

// Update confidence boost (if this was preferred over others)
capability.confidence_boost += 0.05;

// Save updated index
saveCapabilityIndex(index);
```

When user rejects a recommendation:

```typescript
// Small penalty to confidence
capability.confidence_boost -= 0.02;

// Save updated index
saveCapabilityIndex(index);
```

This helps the system learn and improve recommendations over time.
