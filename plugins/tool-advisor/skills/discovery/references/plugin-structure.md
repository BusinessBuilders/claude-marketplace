# Plugin Structure Reference

Detailed reference for Claude Code plugin directory organization and component discovery.

## Standard Directory Layout

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # REQUIRED: Plugin manifest
├── commands/                 # Slash commands
│   ├── command-name.md
│   └── another-command.md
├── agents/                   # Autonomous agents
│   ├── agent-name.md
│   └── specialized-agent.md
├── skills/                   # Agent skills
│   ├── skill-name/
│   │   ├── SKILL.md        # REQUIRED for each skill
│   │   ├── references/     # Detailed documentation
│   │   ├── examples/       # Working code examples
│   │   └── scripts/        # Utility scripts
│   └── another-skill/
│       └── SKILL.md
├── hooks/
│   └── hooks.json          # Event handler configuration
├── .mcp.json               # MCP server definitions
├── README.md               # Plugin documentation
└── scripts/                # Plugin-level utilities
```

## Component Auto-Discovery

Claude Code automatically discovers components in these locations:

### Commands Discovery

1. Checks `commands/` directory at plugin root
2. Reads all `.md` files
3. Parses frontmatter for command configuration
4. Registers as `/plugin-name:command-name`

**File naming**: `command-name.md` → `/plugin-name:command-name`

### Agents Discovery

1. Checks `agents/` directory at plugin root
2. Reads all `.md` files
3. Parses frontmatter for agent configuration
4. Makes agent available for Task tool invocation

**Identifier**: Derived from `name` field in frontmatter

### Skills Discovery

1. Checks `skills/` directory at plugin root
2. Looks for subdirectories containing `SKILL.md`
3. Parses frontmatter for skill metadata
4. Loads skill when trigger conditions match

**Directory naming**: `skill-name/` → Skill identifier

### Hooks Discovery

1. Checks for `hooks/hooks.json` at plugin root
2. Parses JSON configuration
3. Registers hooks for specified events

### MCP Discovery

1. Checks for `.mcp.json` at plugin root
2. Parses server configurations
3. Establishes connections to MCP servers

## Plugin Manifest Schema

### Minimal manifest

```json
{
  "name": "plugin-name"
}
```

### Complete manifest

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://example.com"
  },
  "homepage": "https://docs.example.com",
  "repository": "https://github.com/user/plugin-name",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "commands": "./custom-commands",
  "agents": ["./agents", "./specialized"],
  "hooks": "./config/hooks.json",
  "mcpServers": "./.mcp.json"
}
```

## Component File Formats

### Command File Format

```markdown
---
name: command-name
description: What this command does
argument-hint: [task-description]
allowed-tools: ["Read", "Write", "Bash"]
---

Command instructions for Claude go here.
These are instructions FOR Claude, not TO the user.
```

### Agent File Format

```markdown
---
name: agent-name
description: Use this agent when... <example>...</example>
model: sonnet
color: blue
tools: ["Read", "Write"]
---

System prompt for the agent.
Defines agent's role, responsibilities, and behavior.
```

### Skill File Format

```markdown
---
name: Skill Name
description: Use this skill when...
version: 1.0.0
---

# Skill content in markdown format
```

### Hooks File Format

```json
{
  "hooks": [
    {
      "name": "hook-name",
      "event": "pre-tool-call",
      "type": "prompt",
      "prompt": "Check if there's a better tool available..."
    }
  ]
}
```

## Discovery Scan Process

### 1. Find Plugin Directories

```bash
# Standard locations
~/.claude/plugins/marketplaces/*/plugins/*/
~/.claude/plugins/*/
./.claude/plugins/*/
```

### 2. Validate Plugin

- Check for `.claude-plugin/plugin.json`
- Verify `name` field exists
- Parse additional metadata

### 3. Scan Components

For each component type:
- Check if directory/file exists
- Read component files
- Parse metadata
- Extract capabilities
- Build index entries

### 4. Build Relationships

- Map commands to plugins
- Link agents to required skills
- Connect hooks to plugins
- Associate MCP tools with servers

## File System Patterns

### Finding all plugin manifests

```bash
find ~/.claude/plugins -name "plugin.json" -path "*/.claude-plugin/*"
```

### Finding all commands in a plugin

```bash
find /path/to/plugin/commands -name "*.md" -type f
```

### Finding all agents across all plugins

```bash
find ~/.claude/plugins -path "*/agents/*.md" -type f
```

### Finding all skills

```bash
find ~/.claude/plugins -name "SKILL.md" -type f
```

## Capability Extraction

### From plugin.json

```javascript
const manifest = JSON.parse(readFile('.claude-plugin/plugin.json'));
const capabilities = {
  plugin_name: manifest.name,
  version: manifest.version,
  description: manifest.description,
  keywords: manifest.keywords || []
};
```

### From command file

```javascript
const content = readFile('commands/deploy.md');
const frontmatter = parseFrontmatter(content);
const command = {
  id: `${pluginName}:${frontmatter.name}`,
  type: 'command',
  description: frontmatter.description,
  arguments: frontmatter['argument-hint'],
  tools: frontmatter['allowed-tools']
};
```

### From agent file

```javascript
const content = readFile('agents/scanner.md');
const frontmatter = parseFrontmatter(content);
const description = frontmatter.description;
const examples = extractExampleBlocks(description);
const agent = {
  id: frontmatter.name,
  type: 'agent',
  description: description.replace(/<example>.*?<\/example>/gs, '').trim(),
  triggers: examples.map(ex => ex.userMessage),
  model: frontmatter.model,
  tools: frontmatter.tools
};
```

## Component Relationships

### Skills used by Agents

Agents may reference skills in their system prompts:

```markdown
Load the plugin-structure skill when analyzing plugins.
```

Scan agent system prompts for skill references to build dependency graph.

### Commands using Agents

Commands may invoke agents via Agent tool:

```markdown
Use the scanner agent to analyze installed plugins.
```

### Hooks triggering Commands

Hooks may execute commands:

```json
{
  "event": "pre-tool-call",
  "type": "command",
  "command": "/plugin-name:check-alternatives"
}
```

## Best Practices for Discovery

1. **Cache aggressively**: File system scans are expensive
2. **Scan incrementally**: Use mtime to detect changes
3. **Handle errors**: Skip malformed plugins, continue scanning
4. **Normalize paths**: Expand ~ and resolve relative paths
5. **Extract keywords**: Build comprehensive search index
6. **Preserve metadata**: Keep user preferences across scans
7. **Validate schemas**: Ensure component files are well-formed

## Performance Optimization

### Fast path for unchanged plugins

```javascript
const lastScan = loadCache().last_scan;
const pluginMtime = getDirectoryMtime(pluginPath);
if (pluginMtime < lastScan) {
  // Plugin hasn't changed, use cached data
  return getCachedCapabilities(pluginName);
}
```

### Parallel scanning

```javascript
const plugins = findAllPlugins();
const results = await Promise.all(
  plugins.map(plugin => scanPlugin(plugin))
);
```

### Lazy loading

Only parse component details when needed for recommendations, not during initial scan.
