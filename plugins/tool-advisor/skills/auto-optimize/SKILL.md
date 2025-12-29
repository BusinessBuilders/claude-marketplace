---
name: auto-optimize
description: This skill should be used when the user asks to "optimize my setup", "analyze and improve my project", "automatically set up agents", "auto-optimize", "start working on my project automatically", "read my Project.md and get started", or provides a project specification file and wants Claude to ask clarifying questions then automatically spawn agents to execute. Provides full automation of project analysis, requirements gathering, agent orchestration, and workflow coordination.
version: 0.1.0
---

# Auto-Optimize: Intelligent Project Analysis & Agent Orchestration

Automatically analyze a project specification (Project.md), interview the user to gather requirements, then spawn appropriate agents to work on implementation with full coordination through a shared context file.

## Purpose

Transform project specifications into active execution through intelligent automation:

1. **Reads** Project.md file (requirements, goals, constraints)
2. **Interviews** user with targeted questions (Socratic dialogue)
3. **Analyzes** codebase and tech stack automatically
4. **Spawns** appropriate agents based on requirements and findings
5. **Coordinates** agents via shared context file
6. **Tracks** progress and manages state
7. **Reports** results with clear outcomes

## When to Use This Skill

Invoke this skill when the user:
- Provides a Project.md file and says "get started" or "build this"
- Asks to "read my requirements and start working"
- Wants automated project kickoff with requirements gathering
- Says "ask me questions then deploy agents automatically"
- Has a spec document and wants intelligent execution

**Do NOT use this skill when:**
- User asks for specific agent (invoke that agent directly instead)
- User wants only analysis without execution
- User is asking questions about how to use tools
- No Project.md or spec file exists (use standard auto-optimize instead)

## Core Workflow

### Step 1: Read Project Specification

Read the Project.md file to understand initial requirements:

**Expected Project.md format:**
```markdown
# Project: [Name]

## Goal
What we're building and why

## Requirements
- Functional requirements
- Technical requirements
- Constraints

## Tech Stack
- Languages, frameworks, tools

## Success Criteria
How we know it's done

## Additional Context
Any other relevant information
```

**Implementation:**
```typescript
// Read Project.md
const projectSpec = readFile('./Project.md');

// Parse sections
const goal = extractSection(projectSpec, '## Goal');
const requirements = extractSection(projectSpec, '## Requirements');
const techStack = extractSection(projectSpec, '## Tech Stack');
const successCriteria = extractSection(projectSpec, '## Success Criteria');
```

### Step 2: Interview User (Requirements Gathering)

Ask targeted questions to clarify ambiguities and gather missing details:

**Question strategy:**
- Ask about unclear requirements
- Clarify technical decisions
- Understand constraints and priorities
- Gather additional context

**Use AskUserQuestion tool for structured questions:**

```typescript
AskUserQuestion({
  questions: [
    {
      question: "What's your preferred deployment strategy for this project?",
      header: "Deployment",
      multiSelect: false,
      options: [
        {
          label: "Docker containers",
          description: "Containerized deployment with Docker Compose or K8s"
        },
        {
          label: "Serverless",
          description: "AWS Lambda, Vercel, or similar serverless platforms"
        },
        {
          label: "Traditional server",
          description: "VPS or dedicated server with direct deployment"
        }
      ]
    },
    {
      question: "Which testing approach should we prioritize?",
      header: "Testing",
      multiSelect: true,
      options: [
        {
          label: "Unit tests",
          description: "Test individual functions and components"
        },
        {
          label: "Integration tests",
          description: "Test API endpoints and database interactions"
        },
        {
          label: "E2E tests",
          description: "Test complete user workflows"
        }
      ]
    }
  ]
});
```

**Question categories:**
1. **Architecture** - Monolith vs microservices, deployment strategy
2. **Tech choices** - Specific frameworks, libraries, tools
3. **Testing** - Test coverage requirements, testing frameworks
4. **Timeline** - Priorities, what to build first
5. **Constraints** - Budget, performance requirements, compatibility

**Interview flow:**
```typescript
// Phase 1: Critical architectural decisions
const architectureAnswers = await askArchitectureQuestions();

// Phase 2: Technical implementation details
const techAnswers = await askTechnicalQuestions();

// Phase 3: Quality and testing requirements
const qualityAnswers = await askQualityQuestions();

// Compile complete requirements
const completeRequirements = {
  ...projectSpec,
  ...architectureAnswers,
  ...techAnswers,
  ...qualityAnswers
};
```

### Step 3: Analyze Codebase

Analyze existing codebase to understand current state and tech stack:

```bash
# Run codebase analyzer
PROJECT_ANALYSIS=$(~/.claude/plugins/tool-advisor/scripts/analyze-project.sh .)

# Load capability index
CAPABILITIES=$(cat ~/.claude/tool-advisor-cache.json)
```

**Analysis includes:**
- Detected technologies and frameworks
- Project structure and patterns
- Existing code quality
- Test coverage
- Available plugins/agents that match tech stack

### Step 4: Create Context File

Create shared context file for agent coordination:

**File location:** `./.claude-optimize/context.json`

```json
{
  "version": "1.0.0",
  "project": "MyProject",
  "analyzed_at": "2025-12-28T22:00:00Z",
  "requirements": {
    "goal": "Build user authentication system",
    "functional": ["Login", "Signup", "Password reset"],
    "technical": ["TypeScript", "React", "Prisma", "PostgreSQL"],
    "constraints": ["Must support OAuth", "Mobile-friendly"]
  },
  "user_preferences": {
    "deployment": "Docker containers",
    "testing": ["Unit tests", "Integration tests"],
    "architecture": "Microservices"
  },
  "tech_stack": {
    "languages": ["TypeScript"],
    "frameworks": ["React", "Express"],
    "tools": ["Prisma", "Docker"]
  },
  "agents": {
    "spawned": [],
    "completed": [],
    "failed": []
  },
  "progress": {
    "total_tasks": 0,
    "completed_tasks": 0,
    "current_phase": "planning"
  }
}
```

### Step 5: Determine Agent Strategy

Based on requirements and analysis, determine which agents to spawn:

```typescript
const agentStrategy = {
  // Phase 1: Architecture & Planning (parallel)
  planning: [
    {
      type: "feature-dev:code-architect",
      task: "Design authentication system architecture based on requirements",
      parallel: true
    },
    {
      type: "feature-dev:code-explorer",
      task: "Analyze existing codebase structure",
      parallel: true
    }
  ],

  // Phase 2: Implementation (sequential after planning)
  implementation: [
    {
      type: "plugin:implementation-agent",
      task: "Implement authentication routes and controllers",
      parallel: false,
      dependsOn: ["code-architect"]
    }
  ],

  // Phase 3: Quality & Testing (parallel)
  quality: [
    {
      type: "pr-review-toolkit:code-reviewer",
      task: "Review implementation for quality issues",
      parallel: true
    },
    {
      type: "pr-review-toolkit:pr-test-analyzer",
      task: "Ensure test coverage for auth flows",
      parallel: true
    }
  ]
};
```

### Step 6: Spawn Agents Automatically

Spawn agents in parallel when possible, sequential when dependencies exist:

**Phase 1 - Parallel Planning:**
```typescript
// Send SINGLE message with MULTIPLE Task calls for parallel execution
Task(subagent_type="feature-dev:code-architect",
     prompt=`Design authentication system architecture.

Requirements from Project.md:
${JSON.stringify(completeRequirements, null, 2)}

Context file: ./.claude-optimize/context.json
Read context, design architecture, update context with recommendations.`)

Task(subagent_type="feature-dev:code-explorer",
     prompt=`Analyze existing codebase structure for auth integration.

Context file: ./.claude-optimize/context.json
Read context, analyze codebase, update findings.`)
```

**Phase 2 - Sequential Implementation:**
```typescript
// Wait for planning phase, then implement
Task(subagent_type="implementation:backend-dev",
     prompt=`Implement authentication system based on architecture design.

Read design from: ./.claude-optimize/context.json
Implement routes, controllers, middleware.
Update context when complete.`)
```

**Phase 3 - Parallel Quality Check:**
```typescript
Task(subagent_type="pr-review-toolkit:code-reviewer",
     prompt=`Review authentication implementation.
Context: ./.claude-optimize/context.json`)

Task(subagent_type="pr-review-toolkit:pr-test-analyzer",
     prompt=`Verify test coverage for auth flows.
Context: ./.claude-optimize/context.json`)
```

### Step 7: Monitor Progress & Report

Track agent completion and report results:

```typescript
// Agents update context as they complete
// Read context to check progress
const context = JSON.parse(readFile('./.claude-optimize/context.json'));

// Generate report
const report = `
# 🚀 Auto-Optimize Deployment Results

## Project: ${context.project}

### Requirements Summary
${context.requirements.goal}

### Agents Deployed
✅ **${context.agents.completed.length}** completed
⏳ **${context.agents.spawned.filter(a => a.status === 'running').length}** running
❌ **${context.agents.failed.length}** failed

### Findings

#### Architecture Design (code-architect)
${context.findings.architecture}

#### Code Quality (code-reviewer)
${context.findings.code_quality}

#### Test Coverage (pr-test-analyzer)
${context.findings.testing}

### Next Steps
1. Review agent findings in context file
2. Address any issues identified
3. Run tests and verify implementation
4. Deploy to staging environment

### Context File
All details saved to: ./.claude-optimize/context.json
`;

console.log(report);
```

## Complete Example Flow

User provides Project.md:
```markdown
# Project: Authentication System

## Goal
Add OAuth and email/password authentication to existing app

## Requirements
- Support Google and GitHub OAuth
- Email/password authentication
- Password reset functionality
- JWT token-based sessions

## Tech Stack
- TypeScript
- React (frontend)
- Express (backend)
- Prisma + PostgreSQL
- Docker deployment

## Success Criteria
- Users can login via OAuth or email
- Secure password storage (bcrypt)
- Tests cover all auth flows
```

User invokes: `Skill(skill="tool-advisor:auto-optimize")`

**Execution:**

1. **Read Project.md** ✅
   - Parse goal, requirements, tech stack

2. **Interview User** ❓
   ```
   Q: Which OAuth providers should we prioritize?
   A: Google first, GitHub later

   Q: Token expiration preference?
   A: 7 days with refresh tokens

   Q: Password requirements?
   A: 8+ chars, special char required
   ```

3. **Analyze Codebase** 🔍
   - Detect: TypeScript, React, Express, Prisma
   - Find: Existing user model, no auth routes

4. **Create Context** 📝
   - Write `./.claude-optimize/context.json`
   - Include all requirements and preferences

5. **Deploy Agents** 🤖
   ```bash
   # Phase 1 (parallel)
   Task(subagent_type="feature-dev:code-architect", ...)
   Task(subagent_type="feature-dev:code-explorer", ...)

   # Phase 2 (sequential)
   Task(subagent_type="implementation:backend-dev", ...)

   # Phase 3 (parallel)
   Task(subagent_type="pr-review-toolkit:code-reviewer", ...)
   Task(subagent_type="pr-review-toolkit:pr-test-analyzer", ...)
   ```

6. **Monitor & Report** 📊
   - Track completion in context file
   - Generate summary report
   - Provide next steps

## Key Benefits

✅ **Zero Manual Invocation** - Read Project.md, ask questions, deploy automatically
✅ **Intelligent Questioning** - Only ask what's needed, not overwhelming
✅ **Parallel Execution** - Multiple agents work simultaneously
✅ **Progress Tracking** - Context file shows real-time status
✅ **Coordinated Work** - Agents communicate via shared context
✅ **Clear Results** - Actionable report with findings

## Invocation

```bash
Skill(skill="tool-advisor:auto-optimize")
```

Or user can say:
- "Read my Project.md and get started"
- "Ask me questions then build this automatically"
- "Auto-optimize my project"

The skill handles everything from there!
