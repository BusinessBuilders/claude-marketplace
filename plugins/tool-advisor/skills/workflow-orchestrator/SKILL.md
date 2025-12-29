---
name: workflow-orchestrator
description: This skill should be used when the user asks to "summarize and launch agents", "spawn agents for this work", "orchestrate the workflow", "launch agents to handle this", "analyze and spawn agents", or when the user wants Claude to summarize the current plan/context and automatically spawn appropriate agents mid-workflow.
version: 0.1.0
---

# Workflow Orchestrator Skill

## Purpose

The Workflow Orchestrator skill enables mid-workflow agent spawning and coordination. Unlike the auto-optimize skill which starts from a Project.md file, this skill analyzes the **current conversation context**, summarizes the work at hand, and launches appropriate agents to execute the plan.

Use this skill when:
- Working on a task and needing to delegate to specialized agents
- The user explicitly asks to spawn agents mid-workflow
- Complex work is identified that would benefit from agent orchestration
- A plan exists but needs agents to execute it

## When to Use This Skill

**Automatic Triggers:**
- "Summarize and launch agents"
- "Spawn agents for this work"
- "Orchestrate the workflow"
- "Launch agents to handle this"
- "Analyze and spawn agents"

**Manual Invocation:**
```
Skill(skill="tool-advisor:workflow-orchestrator")
```

**Context-Based Triggers:**
- User has outlined a multi-step plan
- Conversation shows multiple distinct tasks that could be parallelized
- User is stuck and asks for help orchestrating the work
- Complex implementation needs specialized expertise

## Workflow Steps

### Step 1: Analyze Current Context

**Objective**: Understand what work needs to be done based on the conversation.

**Actions**:
1. Review the last 10-15 messages in the conversation
2. Identify:
   - Stated goals and objectives
   - Tasks already completed
   - Tasks remaining
   - Blockers or challenges mentioned
   - Technical stack and constraints
3. Extract key requirements and success criteria

**Output**: Internal understanding of the work context

### Step 2: Summarize the Plan

**Objective**: Create a clear, structured summary of what needs to be done.

**Actions**:
1. Organize identified tasks into logical phases
2. Determine task dependencies (parallel vs sequential)
3. Identify required expertise (code audit, implementation, testing, etc.)
4. Estimate complexity and scope
5. Present summary to user for validation

**Output Format**:
```markdown
## Workflow Summary

**Current State**: [What's been done]
**Goal**: [What needs to be achieved]

**Proposed Plan**:

### Phase 1: [Name] (Parallel/Sequential)
- Task 1: [Description] → Agent: [agent-type]
- Task 2: [Description] → Agent: [agent-type]

### Phase 2: [Name] (Parallel/Sequential)
- Task 3: [Description] → Agent: [agent-type]

**Estimated Complexity**: [Low/Medium/High]
```

### Step 3: Validate with User

**Objective**: Ensure the plan matches user expectations before spawning agents.

**Actions**:
1. Present the workflow summary
2. Ask clarifying questions if:
   - Multiple valid approaches exist
   - Priorities are unclear
   - Technical decisions need user input
3. Get user confirmation to proceed

**Example Questions**:
- "Should the code audit happen before or during implementation?"
- "Do you want agents to work in parallel or wait for each phase?"
- "Should I prioritize speed or thoroughness?"

### Step 4: Determine Agent Strategy

**Objective**: Select the right agents and execution strategy.

**Available Agent Types**:
- **Code audit agents**: Review existing code, find issues
- **Implementation agents**: Write new code, refactor
- **Test agents**: Create tests, verify functionality
- **Review agents**: Code review, quality checks
- **Documentation agents**: Write docs, comments
- **Research agents**: Investigate libraries, patterns
- **Architecture agents**: Design systems, plan structure

**Execution Strategies**:
- **Parallel**: Multiple agents work simultaneously on independent tasks
- **Sequential**: Agents work one after another (when dependencies exist)
- **Pipeline**: Output of one agent feeds into the next
- **Hybrid**: Mix of parallel and sequential phases

**Selection Criteria**:
- Task type → Agent expertise
- Dependencies → Execution order
- Urgency → Parallel vs sequential
- Complexity → Number of agents

### Step 5: Spawn Agents

**Objective**: Launch agents with clear instructions and context.

**For Each Agent**:
1. Provide focused task description
2. Include relevant context from conversation
3. Specify expected outputs
4. Set success criteria
5. Provide file paths or code locations if applicable

**Agent Spawning Patterns**:

**Parallel Spawning** (independent tasks):
```
Use Task tool to spawn multiple agents in a single message:
- Task(subagent_type="general-purpose", prompt="Agent 1 task...")
- Task(subagent_type="general-purpose", prompt="Agent 2 task...")
- Task(subagent_type="general-purpose", prompt="Agent 3 task...")
```

**Sequential Spawning** (dependent tasks):
```
Spawn agents one at a time, waiting for results:
1. Task(subagent_type="general-purpose", prompt="Phase 1 task...")
2. Analyze results
3. Task(subagent_type="general-purpose", prompt="Phase 2 task based on phase 1...")
```

**Background Agents** (long-running):
```
Task(
  subagent_type="general-purpose",
  prompt="Long-running analysis...",
  run_in_background=true
)
```

### Step 6: Monitor and Coordinate

**Objective**: Track agent progress and coordinate results.

**Actions**:
1. Track which agents have completed
2. Collect and summarize results
3. Identify any blockers or issues
4. Coordinate between agents if needed
5. Report progress to user

**Coordination Patterns**:
- **Results aggregation**: Combine outputs from parallel agents
- **Handoff**: Pass one agent's output to the next
- **Conflict resolution**: Handle contradictory recommendations
- **Progress reporting**: Keep user informed

### Step 7: Report Results

**Objective**: Summarize what the agents accomplished.

**Report Format**:
```markdown
## Workflow Execution Results

**Phase 1: [Name]** ✅
- Agent 1: [Summary of work done]
- Agent 2: [Summary of work done]

**Phase 2: [Name]** ✅
- Agent 3: [Summary of work done]

**Summary**: [Overall accomplishments]
**Next Steps**: [Recommended follow-up actions]
```

## Key Differences from Auto-Optimize

| Aspect | Auto-Optimize | Workflow-Orchestrator |
|--------|---------------|----------------------|
| **Starting Point** | Project.md file | Current conversation |
| **Context Source** | User interview + file | Conversation history |
| **Use Case** | Project kickoff | Mid-workflow delegation |
| **Scope** | Full project setup | Specific task execution |
| **User Input** | Answers questions | Validates plan |

## Best Practices

### Context Analysis
- Focus on the last 10-15 messages for recent context
- Don't re-read entire conversation (use recent context)
- Identify explicit user goals vs implicit needs
- Recognize when user is stuck vs when they have a clear plan

### Plan Summarization
- Keep summaries concise (under 300 words)
- Use clear phase names (not "Phase 1, Phase 2")
- Specify parallel vs sequential explicitly
- Show agent-to-task mapping

### User Validation
- Always confirm plan before spawning agents
- Ask questions for ambiguous priorities
- Present options when multiple approaches exist
- Get explicit "yes" before proceeding

### Agent Selection
- Match agent expertise to task type
- Don't over-engineer (simple tasks don't need agents)
- Prefer parallel execution when possible
- Use sequential only when dependencies exist

### Coordination
- Track agent completion status
- Summarize results after each phase
- Report blockers immediately
- Keep user informed of progress

### Avoid
- Spawning too many agents (max 3-4 per phase)
- Creating agents for trivial tasks
- Skipping user validation
- Losing context between agent results
- Over-complicated orchestration

## Example Scenarios

### Scenario 1: Code Refactoring

**User**: "I need to refactor this authentication module. Can you orchestrate the work?"

**Workflow**:
1. **Analyze**: Review conversation, identify auth module files
2. **Summarize**:
   - Phase 1: Code audit (find issues)
   - Phase 2: Refactor implementation
   - Phase 3: Update tests
3. **Validate**: Confirm approach with user
4. **Spawn**:
   - Agent 1 (audit): Analyze auth module for issues
   - Agent 2 (refactor): Implement improvements
   - Agent 3 (test): Update test coverage
5. **Monitor**: Coordinate results between agents
6. **Report**: Summarize changes and recommendations

### Scenario 2: Feature Implementation

**User**: "Summarize what we discussed and launch agents to build it"

**Workflow**:
1. **Analyze**: Review conversation for feature requirements
2. **Summarize**:
   - Phase 1 (Parallel): Architecture design + API design
   - Phase 2 (Sequential): Implementation
   - Phase 3 (Parallel): Tests + Documentation
3. **Validate**: "Should I design the API first or start implementation?"
4. **Spawn**: Parallel agents for architecture + API design
5. **Coordinate**: Wait for phase 1, then spawn implementation agent
6. **Report**: Show completed work and next steps

### Scenario 3: Bug Investigation

**User**: "Launch agents to find and fix this bug"

**Workflow**:
1. **Analyze**: Identify bug description from conversation
2. **Summarize**:
   - Phase 1: Investigate root cause
   - Phase 2: Fix implementation
   - Phase 3: Add regression test
3. **Validate**: Confirm investigation approach
4. **Spawn Sequential**:
   - Agent 1: Find root cause
   - Agent 2: Implement fix based on findings
   - Agent 3: Add test to prevent regression
5. **Monitor**: Ensure each phase completes before next
6. **Report**: Explain bug, fix, and prevention

## Integration with Other Skills

**With auto-optimize**:
- Auto-optimize: Project kickoff and setup
- Workflow-orchestrator: Mid-project task execution
- Complementary, not overlapping

**With discovery skill**:
- Discovery can inform which agents exist
- Workflow-orchestrator uses that info to select agents

**With recommendation skill**:
- Recommendation suggests tools/plugins
- Workflow-orchestrator suggests agents for tasks

## Troubleshooting

**Issue**: Agents spawned with insufficient context
**Fix**: Include more conversation context in agent prompts

**Issue**: Too many agents spawned at once
**Fix**: Limit to 3-4 agents per phase

**Issue**: User unclear about plan
**Fix**: Ask more clarifying questions before spawning

**Issue**: Agents produce conflicting results
**Fix**: Coordinate results, ask user to resolve conflicts

**Issue**: Workflow stalls mid-execution
**Fix**: Report status to user, ask for guidance

## Success Criteria

A successful workflow orchestration:
- ✅ Accurately summarizes current work from conversation
- ✅ Proposes logical phase breakdown
- ✅ Gets user validation before spawning
- ✅ Spawns appropriate agents for tasks
- ✅ Coordinates results effectively
- ✅ Reports clear outcomes to user
- ✅ Completes work faster than single-agent approach

## Quick Reference

**Trigger Phrases**: "summarize and launch agents", "spawn agents", "orchestrate workflow"

**Workflow**: Analyze → Summarize → Validate → Spawn → Coordinate → Report

**Agent Types**: Audit, Implementation, Test, Review, Documentation, Research, Architecture

**Execution**: Parallel (independent) vs Sequential (dependent)

**Best Practice**: Always validate plan with user before spawning agents
