>---
name: Plugin Discovery & Analysis
description: Use this skill when the user asks "What tools do I have?", "Show my capabilities", "What can you do?", "List installed plugins", "Analyze my setup", or when you need to discover available tools for an unknown task. This skill provides techniques for discovering, analyzing, and cataloging Claude Code plugins, skills, agents, and MCP servers.
version: 0.1.0
---

# Plugin Discovery & Analysis

Discover and analyze all available Claude Code tools to provide comprehensive capability awareness and intelligent tool selection.

## When to Use This Skill

Load this skill when you need to:

- Discover what plugins, skills, and agents are installed
- Analyze plugin capabilities and features
- Build an index of available tools
- Understand the full toolkit available to the user
- Match tasks to available capabilities
- Answer questions about what Claude Code can do

## Core Discovery Process

Follow this systematic approach to discover and catalog available tools:

### 1. Identify Scan Locations

Scan these standard directories in order of priority:

```
~/.claude/plugins/marketplaces/  # Marketplace-installed plugins
~/.claude/plugins/               # User-installed plugins
~/.claude/skills/                # User skills
./.claude/                       # Project-specific tools
```

**Important**: Always check both global (`~/`) and project-local (`./`) directories.

### 2. Discover Plugins

For each plugin directory:

1. **Check for manifest**: Look for `.claude-plugin/plugin.json`
2. **Extract metadata**: Read name, description, version, keywords
3. **Identify components**: Scan for:
   - `commands/` directory → Slash commands
   - `agents/` directory → Autonomous agents
   - `skills/` directory → Agent skills
   - `hooks/hooks.json` → Event hooks
   - `.mcp.json` → MCP server integrations

4. **Parse capabilities**: For each component type, extract:
   - Component name and identifier
   - Description and purpose
   - Trigger conditions (for skills/agents)
   - Required tools (for agents)
   - Usage examples

### 3. Analyze Component Details

#### For Commands (`commands/*.md`)

Extract from frontmatter:
- `name`: Command identifier
- `description`: What the command does
- `argument-hint`: Expected arguments
- `allowed-tools`: Which tools it can use

#### For Agents (`agents/*.md`)

Extract from frontmatter:
- `name`: Agent identifier
- `description`: When to use this agent (includes trigger examples)
- `model`: Which Claude model it uses
- `color`: Visual indicator color
- `tools`: Tool access permissions

Parse the description field for trigger patterns in `<example>` blocks.

#### For Skills (`skills/*/SKILL.md`)

Extract from frontmatter:
- `name`: Skill name
- `description`: When to load this skill
- `version`: Skill version

Parse description for trigger phrases.

#### For Hooks (`hooks/hooks.json`)

Extract hook configurations:
- Event type (pre-tool-call, post-tool-call, etc.)
- Hook type (prompt-based or command-based)
- Activation conditions

#### For MCP Servers (`.mcp.json`)

Extract server definitions:
- Server name and type (stdio, SSE, HTTP)
- Available tools and resources
- Connection requirements

### 4. Build Capability Index

Create a searchable index structure:

```json
{
  "last_scan": "2025-01-15T10:30:00Z",
  "scan_locations": [
    "~/.claude/plugins/",
    "~/.claude/skills/",
    "./.claude/"
  ],
  "capabilities": [
    {
      "id": "plugin-name:component-name",
      "type": "agent|command|skill|hook|mcp",
      "name": "Human-readable name",
      "description": "What it does",
      "keywords": ["deploy", "aws", "infrastructure"],
      "triggers": ["deploy to production", "set up infrastructure"],
      "plugin": "plugin-name",
      "path": "/full/path/to/component",
      "metadata": {
        "model": "sonnet",
        "tools": ["Read", "Write", "Bash"],
        "confidence_boost": 0.0
      }
    }
  ],
  "keyword_index": {
    "deploy": ["cloud-infrastructure", "deployment-strategies"],
    "test": ["tdd-workflows", "unit-testing"],
    "review": ["code-review-ai", "comprehensive-review"]
  }
}
```

**Save index to**: `~/.claude/tool-advisor-cache.json`

## Discovery Techniques

### Fast Scanning

Use glob patterns to quickly find components:

```bash
# Find all plugins
find ~/.claude/plugins -name "plugin.json" -type f

# Find all agents
find ~/.claude/plugins -path "*/agents/*.md" -type f

# Find all commands
find ~/.claude/plugins -path "*/commands/*.md" -type f
```

### Deep Analysis

For thorough capability extraction:

1. Read full component files
2. Parse frontmatter metadata
3. Extract trigger examples from descriptions
4. Analyze system prompts for capabilities
5. Identify tool dependencies
6. Map relationships between components

### Incremental Updates

Optimize for repeat scans:

1. Check cache timestamp
2. Only scan if cache is stale (>1 hour old)
3. Use file modification times to skip unchanged components
4. Merge new discoveries with existing index
5. Preserve user preference data

## Keyword Extraction

Build searchable keyword index from:

- Plugin names and descriptions
- Component names
- Description trigger phrases
- System prompt content (for agents)
- Usage examples
- Metadata keywords field

**Normalization**:
- Convert to lowercase
- Remove stop words ("the", "a", "an")
- Stem common variations (deploy/deployment/deploying)
- Extract noun phrases

## Utility Scripts

Use these scripts for discovery operations:

### scan-plugins.sh

Discovers all installed plugins and creates basic inventory:

```bash
#!/bin/bash
# Usage: ./scripts/scan-plugins.sh
# Output: List of plugin names and locations
```

See `scripts/scan-plugins.sh` for implementation.

### parse-manifest.sh

Extracts capabilities from a plugin.json file:

```bash
#!/bin/bash
# Usage: ./scripts/parse-manifest.sh <path-to-plugin.json>
# Output: JSON with extracted metadata
```

See `scripts/parse-manifest.sh` for implementation.

### build-index.sh

Creates complete searchable capability index:

```bash
#!/bin/bash
# Usage: ./scripts/build-index.sh
# Output: ~/.claude/tool-advisor-cache.json
```

See `scripts/build-index.sh` for implementation.

## Reference Documentation

For detailed information on specific topics:

- **Plugin Structure**: See `references/plugin-structure.md` for directory layout and organization patterns
- **Capability Schema**: See `references/capability-schema.md` for the full index data structure
- **Search Patterns**: See `references/search-patterns.md` for keyword matching and ranking algorithms

## Best Practices

1. **Always check cache first**: Avoid unnecessary scans by checking if cached data is fresh
2. **Scan incrementally**: Only re-analyze changed files
3. **Index keywords thoroughly**: Extract all possible search terms for better matching
4. **Preserve metadata**: Keep user preferences and usage statistics
5. **Handle errors gracefully**: Skip malformed plugins, log issues for review
6. **Respect exclusions**: Honor user's exclude_plugins setting
7. **Update after changes**: Re-scan after plugin installation/removal

## Common Patterns

### Check if cache exists and is fresh

```javascript
const cacheFile = '~/.claude/tool-advisor-cache.json';
const maxAge = 3600000; // 1 hour in milliseconds

if (fileExists(cacheFile)) {
  const stat = fileStat(cacheFile);
  const age = Date.now() - stat.mtime;
  if (age < maxAge) {
    return readCache(cacheFile);
  }
}
// Cache is stale or missing, perform full scan
```

### Extract trigger patterns from agent descriptions

```javascript
const description = readAgentDescription('agents/tool-scanner.md');
const examples = extractExampleBlocks(description);
const triggers = examples.map(ex => ex.userMessage.toLowerCase());
// triggers = ["scan my plugins", "what tools do i have", ...]
```

### Build keyword index

```javascript
const keywords = {};
for (const capability of capabilities) {
  const terms = extractKeywords(capability.description);
  for (const term of terms) {
    if (!keywords[term]) keywords[term] = [];
    keywords[term].push(capability.id);
  }
}
```

## Integration with Tool Advisor

This skill powers the tool-scanner agent and scan-tools command by providing:

- Standard scanning procedures
- Index schema definition
- Keyword extraction logic
- Cache management strategies

Use this skill whenever you need to discover, analyze, or catalog available Claude Code capabilities.
