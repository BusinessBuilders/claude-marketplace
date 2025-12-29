---
name: recommend-installations
description: Analyze project codebase and recommend which discovered plugins to install based on detected tech stack and patterns
argument-hint: "[project-dir]"
allowed-tools: ["Read", "Bash", "Glob"]
---

# Installation Recommendation Command

You are helping the user discover which marketplace plugins they should install based on their project's actual codebase and tech stack.

## Your Task

1. **Analyze the project** to detect technologies and frameworks
2. **Load capability index** to see all available plugins
3. **Match tech stack to plugins** using keyword scoring
4. **Differentiate discovered vs installed** plugins
5. **Recommend top matches** with explanations
6. **Provide installation commands**

## Step-by-Step Process

### Step 1: Analyze Project Codebase

Run the codebase analyzer to detect tech stack:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/analyze-project.sh [project-dir]
```

**Note**: `${CLAUDE_PLUGIN_ROOT}` automatically resolves to the tool-advisor plugin directory.

This returns JSON with detected technologies:
```json
{
  "project": "AutoInvoice",
  "technologies": [
    {"category": "backend", "name": "tRPC", "confidence": 0.95},
    {"category": "database", "name": "Prisma", "confidence": 0.95},
    {"category": "ai", "name": "LLM Integration", "confidence": 0.95},
    ...
  ]
}
```

### Step 2: Load Capability Index

Read the cached capability index:

```bash
cat ~/.claude/tool-advisor-cache.json
```

### Step 3: Match Technologies to Plugins

For each detected technology, find plugins with matching keywords:

**Matching Strategy:**
- Extract keywords from detected technologies (e.g., "tRPC" → ["trpc", "backend", "api"])
- Search capability index for plugins with overlapping keywords
- Calculate relevance score based on:
  - Keyword overlap (60%)
  - Confidence from tech detection (30%)
  - Plugin description relevance (10%)

**Status Filtering:**
- **discovered** plugins (install_count = 0) → Recommend these!
- **installed** plugins → Skip (already active)

### Step 4: Score and Rank Plugins

For each discovered plugin, calculate a recommendation score:

```typescript
function scorePlugin(plugin: Plugin, technologies: Technology[]): number {
  let score = 0;

  for (const tech of technologies) {
    // Keyword overlap
    const keywordMatch = plugin.keywords.filter(k =>
      tech.name.toLowerCase().includes(k) ||
      k.includes(tech.name.toLowerCase())
    ).length;

    score += (keywordMatch / plugin.keywords.length) * 0.6;

    // Boost by tech confidence
    score += tech.confidence * 0.3;

    // Category match
    if (plugin.categories?.includes(tech.category)) {
      score += 0.1;
    }
  }

  return Math.min(score, 1.0);
}
```

### Step 5: Present Recommendations

Format output to show:

**Template:**

```markdown
🔍 **Project Analysis**: {project_name}

**Detected Tech Stack:**
- {category}: {technology} ({confidence}%)
- ...

---

📦 **Recommended Plugins to Install** (Discovered but not activated)

### High Priority (>80% match)

**1. {plugin-name}** ({score}% match)
   - **Why**: Your project uses {tech1}, {tech2}
   - **Unlocks**:
     - {agent-name} - {description}
     - {command-name} - {description}
   - **Install**: `/plugin install {plugin-name}`

### Medium Priority (60-80% match)

...

### Already Installed ✅

- {plugin-name} - Active and loaded

---

💡 **Quick Install Commands:**

```bash
# Install high-priority plugins
/plugin install {plugin1}
/plugin install {plugin2}
/plugin install {plugin3}
```
```

### Step 6: Provide Context

Explain WHY each plugin is recommended:

```markdown
**Example: llm-application-dev** (95% match)

Your codebase shows:
- ✅ OpenAI API calls in `apps/backend/src/services/ai/openai.ts`
- ✅ Anthropic integration in `apps/backend/src/services/ai/anthropic.ts`
- ✅ AI provider abstraction layer

This plugin provides:
- **ai-engineer** agent → Optimize your AI provider fallback logic
- **prompt-engineer** agent → Improve OCR/transcription prompts
- **vector-database-engineer** agent → Add pgvector semantic search

Perfect fit for your AI-powered invoice automation!
```

## Important Notes

- **Only recommend discovered plugins** (status: "discovered", install_count: 0)
- **Skip installed plugins** (they're already active)
- **Require minimum 60% match** to recommend
- **Limit to top 10 recommendations** (avoid overwhelming user)
- **Group by priority**: High (>80%), Medium (60-80%), Low (40-60%)
- **Always provide install commands** for convenience

## Example Workflow

```bash
# 1. Analyze project
PROJECT_ANALYSIS=$(${CLAUDE_PLUGIN_ROOT}/scripts/analyze-project.sh ~/AutoInvoice)

# 2. Load capability index
CAPABILITIES=$(cat ~/.claude/tool-advisor-cache.json)

# 3. Match and score
# (Use jq to filter and score plugins based on detected technologies)

# 4. Present recommendations
# (Format output as markdown)
```

## Edge Cases

- **No discovered plugins**: "All relevant plugins are already installed! ✅"
- **No good matches**: "No plugins match your current tech stack. Consider browsing /plugin for general-purpose tools."
- **Cache missing**: "Run `/tool-advisor/scan-tools` first to build the capability index."
- **Project not detected**: "Unable to analyze project. Make sure you're in a project directory with package.json, requirements.txt, or similar."

## Success Criteria

User should clearly understand:
1. What technologies were detected in their project
2. Which plugins match their tech stack (and why)
3. What capabilities they'll unlock by installing
4. How to install with simple copy-paste commands
5. Which plugins are already installed (no need to reinstall)

Help users make informed decisions about which plugins to activate!
