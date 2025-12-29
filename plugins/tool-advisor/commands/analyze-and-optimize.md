---
name: analyze-and-optimize
description: Complete project analysis - analyze codebase, recommend plugins to install, suggest agents to use, and provide optimization roadmap
argument-hint: "[project-dir]"
allowed-tools: ["Read", "Bash", "Glob"]
---

# Complete Project Analysis & Optimization

You are providing a **comprehensive analysis** of the user's project to optimize their Claude Code setup.

## Your Mission

Give the user a **complete action plan** in ONE response:

1. 🔍 **Project Analysis** - What's in their codebase
2. 📦 **Install Recommendations** - Which discovered plugins to activate
3. ✅ **Ready to Use** - Which agents are already available
4. 🎯 **Specific Use Cases** - How to use agents for their project
5. 🚀 **Quick Start Commands** - Copy-paste to get started

## Step-by-Step Process

### Step 1: Analyze Project Tech Stack

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/analyze-project.sh [project-dir]
```

**Note**: `${CLAUDE_PLUGIN_ROOT}` automatically resolves to the tool-advisor plugin directory, regardless of installation location (local, marketplace, or custom).

### Step 2: Load Capability Index

```bash
cat ~/.claude/tool-advisor-cache.json
```

### Step 3: Comprehensive Analysis

Combine everything into one unified report:

```markdown
# 🎯 Claude Code Optimization for {Project Name}

## 📊 Your Tech Stack

Detected technologies:
- **TypeScript** (95% confidence) - Primary language
- **tRPC** (95%) - API layer
- **Prisma** (95%) - Database ORM
- **AI Integration** (85%) - OpenAI/Anthropic providers
- **Docker/K8s** (80-90%) - Infrastructure
- **GitHub Actions** (95%) - CI/CD

---

## 📦 INSTALL THESE PLUGINS (Discovered but not active)

### High Priority - Install Now

**1. llm-application-dev** (95% match) 📌
- **Why**: Your code uses OpenAI, Anthropic AI providers
- **What you get**:
  - `ai-engineer` agent - Optimize your AI provider abstraction
  - `prompt-engineer` agent - Improve OCR/voice transcription prompts
  - `vector-database-engineer` agent - Add pgvector semantic search
- **Install**: `/plugin install llm-application-dev`
- **Use for**:
  - "Optimize AI provider fallback logic"
  - "Improve receipt OCR prompt accuracy"
  - "Add semantic search to invoices"

**2. backend-development** (92% match) 📌
- **Why**: Your tRPC routers and API architecture
- **What you get**:
  - `backend-architect` agent - Review tRPC router design
  - `api-designer` agent - Design new endpoints
  - `microservices-architect` agent - Architecture guidance
- **Install**: `/plugin install backend-development`
- **Use for**:
  - "Design Tally voice invoice API"
  - "Review tRPC router structure"
  - "Optimize API performance"

**3. database-migrations** (88% match) 📌
- **Why**: Active Prisma schema development detected
- **What you get**:
  - `database-admin` agent - Schema optimization
  - `migration-specialist` agent - Safe migrations
- **Install**: `/plugin install database-migrations`
- **Use for**:
  - "Add userId to Service table"
  - "Optimize invoice query N+1 issues"
  - "Design schema for Tally integration"

### Medium Priority - Install When Needed

**4. tdd-workflows** (85% match)
- **Why**: Jest testing framework detected
- **Install**: `/plugin install tdd-workflows`
- **Use when**: Writing tests for new routers

**5. cicd-automation** (80% match)
- **Why**: GitHub Actions workflows detected
- **Install**: `/plugin install cicd-automation`
- **Use when**: Setting up deployment pipelines

---

## ✅ ALREADY INSTALLED - Ready to Use Now

### serena (Semantic Code Navigation)

**Available agents**: None (this is an MCP tool, not agent-based)

**Use for**:
```bash
# Navigate your large codebase efficiently
mcp__serena__find_symbol("createInvoice", include_body=true)
mcp__serena__get_symbols_overview("apps/backend/src/routers/")
```

### tool-advisor (This Plugin)

**Available commands**:
- `/tool-advisor/recommend` - Get agent recommendations for tasks
- `/tool-advisor/scan-tools` - Refresh capability index
- `/tool-advisor/analyze-and-optimize` - This command!

---

## 🎯 SPECIFIC USE CASES FOR YOUR PROJECT

### Current Feature: Tally Voice Invoice Integration

**Recommended workflow**:

```bash
# 1. Install the AI plugin
/plugin install llm-application-dev

# 2. Use ai-engineer for voice transcription
Task(subagent_type="llm-application-dev:ai-engineer",
     prompt="Review apps/backend/src/routers/voice.ts and optimize
             Whisper transcription with fallback to Anthropic")

# 3. Install backend plugin
/plugin install backend-development

# 4. Use backend-architect for API design
Task(subagent_type="backend-development:backend-architect",
     prompt="Review apps/backend/src/routers/tally.ts and suggest
             improvements for the Tally integration API")

# 5. Install database plugin
/plugin install database-migrations

# 6. Use database-admin for schema
Task(subagent_type="database-migrations:database-admin",
     prompt="Design Prisma schema additions for Tally voice recordings
             and transcription cache")
```

### Future: Production Deployment

**When you're ready to deploy**:

```bash
# Install infrastructure plugins
/plugin install kubernetes-operations
/plugin install security-scanning

# Use deployment agents
Task(subagent_type="kubernetes-operations:k8s-architect",
     prompt="Review K8s manifests for production readiness")
```

---

## 🚀 QUICK START - Copy & Paste

### Install Essential Plugins (30 seconds)

```bash
/plugin install llm-application-dev
/plugin install backend-development
/plugin install database-migrations
```

### Immediate Actions for Current Feature

```bash
# Analyze your new routers
Task(subagent_type="backend-development:backend-architect",
     prompt="Review apps/backend/src/routers/tally.ts and voice.ts")

# Optimize AI integration
Task(subagent_type="llm-application-dev:ai-engineer",
     prompt="Review AI provider abstraction in apps/backend/src/services/ai/")

# Check database schema
Task(subagent_type="database-migrations:database-admin",
     prompt="Review Prisma schema for Tally integration needs")
```

---

## 📈 Expected Benefits

After installing these 3 plugins, you'll have:

- **6 specialized agents** for your AI/backend/database work
- **95% coverage** of your current tech stack
- **Domain expertise** in areas you're actively developing
- **Faster development** with intelligent agent recommendations

---

## 💡 Next Steps

1. ✅ **Install high-priority plugins** (3 commands above)
2. ✅ **Try the agents** with your current feature branch
3. ✅ **Add more plugins** as you work on different areas
4. ✅ **Run this command again** after adding new dependencies

Need help with any specific area? Just ask!
```

## Important Guidelines

**Be Specific**:
- Don't just list plugins - explain WHY for THIS project
- Show actual file paths from their codebase
- Give copy-paste commands they can run immediately

**Be Actionable**:
- High/Medium/Low priority tiers
- Quick start section with essential commands
- Specific use cases for their current work

**Be Honest**:
- If they already have great coverage, say so
- Don't recommend plugins they don't need
- Show what's already installed and ready to use

**Be Helpful**:
- Group by workflow (current feature, future work)
- Show agent invocation syntax
- Explain what each agent actually does for THEIR code

## Output Format

Always use this structure:
1. Tech Stack Summary (what you detected)
2. Install Recommendations (discovered plugins, sorted by priority)
3. Already Installed (what they can use now)
4. Specific Use Cases (for their current work)
5. Quick Start Commands (copy-paste ready)

This gives users a **complete action plan** in one response!
