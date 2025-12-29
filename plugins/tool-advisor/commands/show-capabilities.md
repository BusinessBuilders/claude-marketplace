---
name: show-capabilities
description: Display all available Claude Code tools organized by type (agents, commands, skills, hooks, MCP servers). Provides searchable, filterable view of your complete toolkit.
argument-hint: "[--all] [--type <type>] [--plugin <name>] [--search <term>]"
allowed-tools: ["Read"]
---

# Show Capabilities Command

You are helping the user explore their installed Claude Code tools. This command presents a clear, organized view of all available capabilities with filtering and search options.

## Your Task

1. **Parse arguments** to determine display mode and filters
2. **Load capability index** from cache
3. **Apply filters** (type, plugin, search term)
4. **Organize capabilities** by type
5. **Present in readable format** with appropriate detail level

## Step-by-Step Process

### Step 1: Parse Arguments

Support these flags:

- `--all`: Show detailed view with usage examples (default: brief)
- `--type <type>`: Filter by capability type (agent|command|skill|hook|mcp)
- `--plugin <name>`: Filter by plugin name
- `--search <term>`: Filter by keyword search

**Examples**:
```bash
/tool-advisor:show-capabilities
/tool-advisor:show-capabilities --all
/tool-advisor:show-capabilities --type agent
/tool-advisor:show-capabilities --plugin cloud-infrastructure
/tool-advisor:show-capabilities --search deploy
/tool-advisor:show-capabilities --type agent --search terraform
```

### Step 2: Load Capability Index

Read from cache:

```typescript
const cachePath = expandPath('~/.claude/tool-advisor-cache.json');

if (!fileExists(cachePath)) {
  return showError('No capability index found. Run /tool-advisor:scan-tools first.');
}

const index = JSON.parse(readFile(cachePath));
const allCapabilities = index.capabilities;
```

### Step 3: Apply Filters

Start with all capabilities, then filter:

```typescript
let filtered = allCapabilities;

// Filter by type
if (typeFilter) {
  filtered = filtered.filter(cap => cap.type === typeFilter);
}

// Filter by plugin
if (pluginFilter) {
  filtered = filtered.filter(cap =>
    cap.plugin.toLowerCase().includes(pluginFilter.toLowerCase())
  );
}

// Filter by search term
if (searchTerm) {
  const term = searchTerm.toLowerCase();
  filtered = filtered.filter(cap =>
    cap.name.toLowerCase().includes(term) ||
    cap.description.toLowerCase().includes(term) ||
    cap.keywords.some(k => k.includes(term))
  );
}
```

### Step 4: Organize by Type

Group capabilities by type:

```typescript
const grouped = {
  agent: [],
  command: [],
  skill: [],
  hook: [],
  mcp_server: [],
  mcp_tool: []
};

for (const cap of filtered) {
  grouped[cap.type].push(cap);
}

// Sort each group alphabetically
for (const type of Object.keys(grouped)) {
  grouped[type].sort((a, b) => a.name.localeCompare(b.name));
}
```

### Step 5: Present Results

#### Brief Mode (Default)

Show grouped list with names and brief descriptions:

```markdown
## Available Tools (${filtered.length} total)

${cacheAge}

### 🤖 Agents (${agentCount})

${agents.map(a => `- **${a.name}** - ${truncate(a.description, 80)}`).join('\n')}

### ⚡ Commands (${commandCount})

${commands.map(c => `- **/${c.plugin}:${c.name}** - ${truncate(c.description, 80)}`).join('\n')}

### 📚 Skills (${skillCount})

${skills.map(s => `- **${s.name}** - ${truncate(s.description, 80)}`).join('\n')}

### 🪝 Hooks (${hookCount})

${hooks.map(h => `- **${h.name}** (${h.metadata.event}) - ${truncate(h.description, 80)}`).join('\n')}

### 🔌 MCP Servers (${mcpCount})

${mcpServers.map(m => `- **${m.name}** (${m.metadata.server_type}) - ${truncate(m.description, 80)}`).join('\n')}

---

Use `--all` for detailed view with usage examples.
Use `--type <type>` to filter by capability type.
Use `--search <term>` to search capabilities.
```

#### Detailed Mode (`--all`)

Show full information for each capability:

```markdown
## Available Tools (${filtered.length} total) - Detailed View

${cacheAge}

${grouped.map(type => renderDetailedGroup(type)).join('\n\n')}
```

For each capability in detailed mode:

**Agents**:
```markdown
### ${name}

**Type**: Agent
**Plugin**: ${plugin}
**Model**: ${metadata.model}

**Description**: ${description}

**When to use**:
${triggers.map(t => `- "${t}"`).join('\n')}

**Tools**: ${metadata.tools ? metadata.tools.join(', ') : 'All tools'}

${usage_count > 0 ? `**Usage**: Used ${usage_count} times (${(success_rate * 100).toFixed(0)}% success rate)` : ''}

---
```

**Commands**:
```markdown
### /${plugin}:${name}

**Type**: Command
**Plugin**: ${plugin}

**Description**: ${description}

**Arguments**: ${metadata.argument_hint || 'None'}

**Example**:
\`\`\`bash
/${plugin}:${name} ${metadata.argument_hint || ''}
\`\`\`

**Allowed tools**: ${metadata.allowed_tools.join(', ')}

${usage_count > 0 ? `**Usage**: Used ${usage_count} times` : ''}

---
```

**Skills**:
```markdown
### ${name}

**Type**: Skill
**Plugin**: ${plugin}
**Version**: ${metadata.version}

**Description**: ${description}

**When to load**:
${extractTriggers(description).map(t => `- ${t}`).join('\n')}

**Resources**:
${metadata.has_references ? '- ✓ Reference documentation' : ''}
${metadata.has_examples ? '- ✓ Working examples' : ''}
${metadata.has_scripts ? '- ✓ Utility scripts' : ''}

---
```

**Hooks**:
```markdown
### ${name}

**Type**: Hook (${metadata.hook_type})
**Plugin**: ${plugin}
**Event**: ${metadata.event}

**Description**: ${description}

${metadata.conditions ? `**Activation**: ${metadata.conditions.join(', ')}` : ''}

---
```

**MCP Servers**:
```markdown
### ${name}

**Type**: MCP Server (${metadata.server_type})
**Plugin**: ${plugin}

**Description**: ${description}

**Command**: \`${metadata.command}\`

**Tools**: ${metadata.tools_count} exposed tools
**Resources**: ${metadata.resources_count} exposed resources

---
```

### Step 6: Add Search/Filter Hints

If results are filtered, show active filters:

```markdown
**Active Filters**:
${typeFilter ? `- Type: ${typeFilter}` : ''}
${pluginFilter ? `- Plugin: ${pluginFilter}` : ''}
${searchTerm ? `- Search: "${searchTerm}"` : ''}

Showing ${filtered.length} of ${total} total capabilities.

To see all: `/tool-advisor:show-capabilities`
```

If no results after filtering:

```markdown
## No Matching Capabilities

No tools match your filters:
${typeFilter ? `- Type: ${typeFilter}` : ''}
${pluginFilter ? `- Plugin: ${pluginFilter}` : ''}
${searchTerm ? `- Search: "${searchTerm}"` : ''}

Try:
- Removing filters
- Using different search terms
- Running `/tool-advisor:scan-tools` to refresh the index
```

## Helper Functions

### truncate(text, length)

```typescript
function truncate(text: string, length: number): string {
  if (text.length <= length) return text;
  return text.substring(0, length - 3) + '...';
}
```

### getCacheAge()

```typescript
function getCacheAge(lastScan: string): string {
  const now = Date.now();
  const scanned = new Date(lastScan).getTime();
  const ageMs = now - scanned;

  const minutes = Math.floor(ageMs / 60000);
  if (minutes < 60) return `📅 Scanned ${minutes} minutes ago`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `📅 Scanned ${hours} hours ago`;

  const days = Math.floor(hours / 24);
  return `📅 Scanned ${days} days ago`;
}
```

### extractTriggers(description)

```typescript
function extractTriggers(description: string): string[] {
  const triggers = [];

  // Look for common trigger patterns
  const patterns = [
    /when (the user |you )?(?:asks?|says?|needs?|wants?) "([^"]+)"/gi,
    /if (?:the user |you )(?:asks?|says?|needs?|wants?) "([^"]+)"/gi,
    /"([^"]+)"/g  // Any quoted text
  ];

  for (const pattern of patterns) {
    const matches = [...description.matchAll(pattern)];
    for (const match of matches) {
      const trigger = match[2] || match[1];
      if (trigger && trigger.length > 5) {
        triggers.push(trigger);
      }
    }
  }

  return [...new Set(triggers)].slice(0, 5);  // Max 5 unique triggers
}
```

## Example Outputs

### Example 1: Default Brief View

```markdown
## Available Tools (156 total)

📅 Scanned 15 minutes ago

### 🤖 Agents (67)

- **cloud-architect** - Expert in cloud infrastructure design and architecture
- **deployment-engineer** - Handles application deployments across cloud platforms
- **terraform-specialist** - Terraform infrastructure as code expert
- **tool-scanner** - Scans .claude/ directories for installed tools
- ... (63 more)

### ⚡ Commands (38)

- **/cloud-infrastructure:deploy** - Deploy infrastructure using Terraform
- **/tool-advisor:recommend** - Get tool recommendations for tasks
- **/tool-advisor:scan-tools** - Scan and index installed tools
- **/tool-advisor:show-capabilities** - Display all available tools
- ... (34 more)

### 📚 Skills (31)

- **Plugin Discovery & Analysis** - Techniques for discovering and analyzing plugins
- **Recommendation Strategies** - Intelligent tool matching and ranking algorithms
- **Terraform Best Practices** - Infrastructure as code patterns and standards
- ... (28 more)

### 🪝 Hooks (12)

- **pre-tool-call** (pre-tool-call) - Check for better tool alternatives
- **conversation-start** (conversation-start) - Auto-scan tools on startup
- ... (10 more)

### 🔌 MCP Servers (8)

- **github** (stdio) - GitHub API integration
- **database** (stdio) - Database query and management
- ... (6 more)

---

Use `--all` for detailed view with usage examples.
Use `--type <type>` to filter by capability type.
Use `--search <term>` to search capabilities.
```

### Example 2: Filtered by Type

```bash
/tool-advisor:show-capabilities --type agent --search terraform
```

```markdown
## Available Tools (2 total)

📅 Scanned 15 minutes ago

**Active Filters**:
- Type: agent
- Search: "terraform"

### 🤖 Agents (2)

- **terraform-specialist** - Expert in Terraform infrastructure as code
- **terraform-validator** - Validates Terraform configurations for best practices

---

Showing 2 of 156 total capabilities.

To see all: `/tool-advisor:show-capabilities`
```

### Example 3: Detailed View for One Agent

```bash
/tool-advisor:show-capabilities --all --plugin tool-advisor
```

```markdown
## Available Tools (5 total) - Detailed View

📅 Scanned 15 minutes ago

**Active Filters**:
- Plugin: tool-advisor

### 🤖 Agents (3)

#### tool-scanner

**Type**: Agent
**Plugin**: tool-advisor
**Model**: sonnet

**Description**: Automatically scans .claude/ directories for capabilities and builds searchable index.

**When to use**:
- "scan my plugins"
- "what tools do I have"
- "update tool index"

**Tools**: Read, Bash, Glob, Write

**Usage**: Used 5 times (100% success rate)

---

#### recommendation-engine

**Type**: Agent
**Plugin**: tool-advisor
**Model**: sonnet

**Description**: Matches tasks to the most appropriate tools using multi-factor scoring.

**When to use**:
- "what should I use for X"
- "recommend a tool"
- "help me with Y"

**Tools**: Read

**Usage**: Used 23 times (95% success rate)

---

#### proactive-advisor

**Type**: Agent
**Plugin**: tool-advisor
**Model**: haiku

**Description**: Provides contextual tool suggestions during conversations.

**When to use**:
- Automatically when tasks are detected
- "suggest tools"

**Tools**: Read

**Usage**: Used 47 times (89% success rate)

---

### ⚡ Commands (2)

#### /tool-advisor:recommend

**Type**: Command
**Plugin**: tool-advisor

**Description**: Get intelligent tool recommendations for a specific task.

**Arguments**: [task-description] or --task "description" [--prefer type] [--exclude pattern]

**Example**:
\`\`\`bash
/tool-advisor:recommend "deploy to production"
\`\`\`

**Allowed tools**: Read, Bash, Glob

**Usage**: Used 12 times

---

#### /tool-advisor:scan-tools

**Type**: Command
**Plugin**: tool-advisor

**Description**: Scan and index all installed tools.

**Arguments**: [--quiet] [--force]

**Example**:
\`\`\`bash
/tool-advisor:scan-tools
\`\`\`

**Allowed tools**: Read, Write, Bash, Glob

**Usage**: Used 6 times

---
```

## Integration Notes

This command helps users:
- Discover what tools they have installed
- Understand when to use each tool
- Find tools by keyword search
- Browse by plugin or type

It complements the recommend command by providing exploratory browsing vs. task-driven recommendations.
