---
name: scan-tools
description: Scan and index all installed Claude Code tools including plugins, skills, agents, commands, hooks, and MCP servers. Creates a searchable capability index for intelligent tool recommendations.
argument-hint: "[--quiet] [--force]"
allowed-tools: ["Read", "Write", "Bash", "Glob"]
---

# Tool Scanning Command

You are helping the user scan and catalog all their installed Claude Code tools. This command discovers capabilities across the entire `.claude/` ecosystem and builds a searchable index.

## Your Task

1. **Parse arguments** to determine scan mode
2. **Load the discovery skill** to access scanning techniques
3. **Scan all standard locations** for plugins, skills, and tools
4. **Extract capabilities** from each discovered component
5. **Build searchable index** with keywords and metadata
6. **Save index to cache** for fast lookups
7. **Report scan results** to user

## Step-by-Step Process

### Step 1: Parse Arguments

Support these flags:

- `--quiet`: Suppress progress output, just update cache
- `--force`: Force full rescan even if cache is fresh

Default behavior (no flags): Show progress and summary.

### Step 2: Load Discovery Skill

Load the plugin discovery skill to access scanning procedures:

```
Load the tool-advisor discovery skill for scanning techniques.
```

This skill provides:
- Directory scanning patterns
- Component parsing logic
- Keyword extraction algorithms
- Index schema definition

### Step 3: Determine Scan Scope

Scan these locations in order:

1. **Marketplace plugins**: `~/.claude/plugins/marketplaces/*/plugins/*/`
2. **User plugins**: `~/.claude/plugins/*/`
3. **User skills**: `~/.claude/skills/*/`
4. **Project-local tools**: `./.claude/` (if in a project)

Check user settings for custom scan directories:
```bash
# Read from ~/.claude/tool-advisor.local.md
scan_directories:
  - ~/.claude/plugins/
  - ~/.claude/skills/
  - ./.claude/
  - /custom/path/
```

### Step 4: Scan Each Location

For each scan location:

#### A. Find Plugin Directories

```bash
# Find all plugin manifests
find ~/.claude/plugins -name "plugin.json" -path "*/.claude-plugin/*"
```

For each plugin found:

1. **Read manifest** (`.claude-plugin/plugin.json`)
2. **Extract metadata**:
   - Plugin name
   - Version
   - Description
   - Keywords
   - Author

3. **Scan components**:
   - Commands: `commands/*.md`
   - Agents: `agents/*.md`
   - Skills: `skills/*/SKILL.md`
   - Hooks: `hooks/hooks.json`
   - MCP: `.mcp.json`

#### B. For Each Component Type

**Commands** (`commands/*.md`):
```typescript
for (const commandFile of findCommandFiles(pluginDir)) {
  const content = readFile(commandFile);
  const frontmatter = parseFrontmatter(content);

  const capability = {
    id: `${pluginName}:${frontmatter.name}`,
    type: 'command',
    name: frontmatter.name,
    plugin: pluginName,
    description: frontmatter.description,
    keywords: extractKeywords(frontmatter.description),
    triggers: [],
    path: commandFile,
    metadata: {
      argument_hint: frontmatter['argument-hint'],
      allowed_tools: frontmatter['allowed-tools'],
      is_interactive: detectInteractive(content)
    }
  };

  addToIndex(capability);
}
```

**Agents** (`agents/*.md`):
```typescript
for (const agentFile of findAgentFiles(pluginDir)) {
  const content = readFile(agentFile);
  const frontmatter = parseFrontmatter(content);

  // Extract trigger examples from description
  const examples = extractExampleBlocks(frontmatter.description);
  const triggers = examples.map(ex => ex.userMessage.toLowerCase());

  const capability = {
    id: frontmatter.name,
    type: 'agent',
    name: frontmatter.name,
    plugin: pluginName,
    description: cleanDescription(frontmatter.description),
    keywords: extractKeywords(frontmatter.description),
    triggers: triggers,
    path: agentFile,
    metadata: {
      model: frontmatter.model || 'inherit',
      color: frontmatter.color || 'default',
      tools: frontmatter.tools || null,
      system_prompt_length: content.length - frontmatterLength,
      example_count: examples.length
    }
  };

  addToIndex(capability);
}
```

**Skills** (`skills/*/SKILL.md`):
```typescript
for (const skillDir of findSkillDirs(pluginDir)) {
  const skillFile = path.join(skillDir, 'SKILL.md');
  const content = readFile(skillFile);
  const frontmatter = parseFrontmatter(content);

  const capability = {
    id: `${pluginName}:${skillDirName}`,
    type: 'skill',
    name: frontmatter.name,
    plugin: pluginName,
    description: frontmatter.description,
    keywords: extractKeywords(frontmatter.description),
    triggers: extractTriggers(frontmatter.description),
    path: skillFile,
    metadata: {
      version: frontmatter.version,
      has_references: dirExists(path.join(skillDir, 'references')),
      has_examples: dirExists(path.join(skillDir, 'examples')),
      has_scripts: dirExists(path.join(skillDir, 'scripts')),
      file_count: countFiles(skillDir)
    }
  };

  addToIndex(capability);
}
```

**Hooks** (`hooks/hooks.json`):
```typescript
const hooksFile = path.join(pluginDir, 'hooks/hooks.json');
if (fileExists(hooksFile)) {
  const hooksConfig = JSON.parse(readFile(hooksFile));

  for (const hook of hooksConfig.hooks) {
    const capability = {
      id: `${pluginName}:${hook.name}`,
      type: 'hook',
      name: hook.name,
      plugin: pluginName,
      description: hook.prompt || hook.command || 'Event hook',
      keywords: [hook.event, 'automation', 'hook'],
      triggers: [],
      path: hooksFile,
      metadata: {
        event: hook.event,
        hook_type: hook.type,
        priority: hook.priority || null,
        conditions: hook.conditions || null
      }
    };

    addToIndex(capability);
  }
}
```

**MCP Servers** (`.mcp.json`):
```typescript
const mcpFile = path.join(pluginDir, '.mcp.json');
if (fileExists(mcpFile)) {
  const mcpConfig = JSON.parse(readFile(mcpFile));

  for (const [serverName, serverConfig] of Object.entries(mcpConfig.mcpServers)) {
    const capability = {
      id: `${pluginName}:mcp:${serverName}`,
      type: 'mcp_server',
      name: serverName,
      plugin: pluginName,
      description: `MCP server: ${serverName}`,
      keywords: ['mcp', 'integration', serverName],
      triggers: [],
      path: mcpFile,
      metadata: {
        server_type: inferServerType(serverConfig),
        command: serverConfig.command || null,
        tools_count: 0,  // Will be updated when connected
        resources_count: 0
      }
    };

    addToIndex(capability);
  }
}
```

### Step 5: Build Keyword Index

Create reverse index for fast keyword lookups:

```typescript
const keywordIndex: Record<string, string[]> = {};

for (const capability of capabilities) {
  for (const keyword of capability.keywords) {
    if (!keywordIndex[keyword]) {
      keywordIndex[keyword] = [];
    }
    keywordIndex[keyword].push(capability.id);
  }
}
```

### Step 6: Build Plugin Index

Create plugin metadata index:

```typescript
const pluginIndex: Record<string, PluginMetadata> = {};

for (const capability of capabilities) {
  if (!pluginIndex[capability.plugin]) {
    pluginIndex[capability.plugin] = {
      name: capability.plugin,
      version: '0.0.0',  // From manifest
      description: '',   // From manifest
      author: null,
      path: pluginPath,
      keywords: [],
      capabilities: [],
      install_location: inferLocation(pluginPath)
    };
  }

  pluginIndex[capability.plugin].capabilities.push(capability.id);
}
```

### Step 7: Create Capability Index

Assemble complete index:

```typescript
const index = {
  version: '1.0.0',
  last_scan: new Date().toISOString(),
  scan_locations: scanLocations,
  total_plugins: Object.keys(pluginIndex).length,
  total_capabilities: capabilities.length,
  capabilities: capabilities,
  keyword_index: keywordIndex,
  plugin_index: pluginIndex,
  statistics: {
    scan_duration_ms: scanDuration,
    plugins_scanned: pluginsScanned,
    plugins_skipped: pluginsSkipped,
    capabilities_found: capabilities.length,
    capabilities_updated: updatedCount,
    errors: scanErrors
  }
};
```

### Step 8: Save Index

Write to cache file:

```bash
mkdir -p ~/.claude
cat > ~/.claude/tool-advisor-cache.json << 'EOF'
${JSON.stringify(index, null, 2)}
EOF
```

### Step 9: Report Results

**Quiet Mode** (`--quiet`):
No output, just update cache.

**Normal Mode** (default):
```markdown
## Tool Scan Complete

📊 **Scan Results**:
- **Plugins scanned**: ${pluginsScanned}
- **Capabilities indexed**: ${totalCapabilities}
  - Commands: ${commandCount}
  - Agents: ${agentCount}
  - Skills: ${skillCount}
  - Hooks: ${hookCount}
  - MCP Servers: ${mcpCount}

⏱️ **Scan duration**: ${duration}ms

💾 **Cache saved**: `~/.claude/tool-advisor-cache.json`

${errorsCount > 0 ? `⚠️ **Errors**: ${errorsCount} (see logs)` : '✓ No errors'}
```

If errors occurred, show details:
```markdown
### Scan Errors

${errors.map(e => `- ${e.path}: ${e.error}`).join('\n')}
```

## Utility Scripts

Delegate heavy lifting to bash scripts:

### scan-plugins.sh

```bash
# Scan for plugins and return list
./scripts/scan-plugins.sh
```

Returns JSON array of plugin paths.

### parse-manifest.sh

```bash
# Extract metadata from plugin.json
./scripts/parse-manifest.sh /path/to/.claude-plugin/plugin.json
```

Returns JSON with plugin metadata.

### build-index.sh

```bash
# Build complete capability index
./scripts/build-index.sh
```

Orchestrates full scan and index creation.

See Phase 5.5 for script implementations.

## Performance Optimization

### Incremental Scanning

If `--force` not specified and cache exists:

1. Check file modification times
2. Only re-scan changed plugins
3. Merge with existing cache
4. Preserve usage statistics

```typescript
const cachedIndex = loadCache();
const changedPlugins = findChangedPlugins(cachedIndex.last_scan);

if (changedPlugins.length === 0 && !forceFlag) {
  console.log('Cache is fresh, no scan needed');
  return cachedIndex;
}

// Only scan changed plugins
for (const plugin of changedPlugins) {
  scanPlugin(plugin);
}
```

### Parallel Scanning

Scan plugins in parallel for speed:

```bash
# Use xargs for parallel execution
find ~/.claude/plugins -name "plugin.json" | \
  xargs -P 4 -I {} ./scripts/parse-manifest.sh {}
```

## Error Handling

Handle gracefully:

1. **Malformed JSON**: Skip plugin, log error, continue
2. **Missing manifests**: Skip directory, log warning
3. **Permission errors**: Skip inaccessible files
4. **Invalid frontmatter**: Skip component, log error

**Never fail the entire scan due to one bad plugin.**

## Example Output

```
## Tool Scan Complete

📊 **Scan Results**:
- **Plugins scanned**: 42
- **Capabilities indexed**: 156
  - Commands: 38
  - Agents: 67
  - Skills: 31
  - Hooks: 12
  - MCP Servers: 8

⏱️ **Scan duration**: 1,250ms

💾 **Cache saved**: `~/.claude/tool-advisor-cache.json`

✓ No errors

Your tools are now indexed and ready for recommendations!
```

## Integration Notes

This command is called by:
- **conversation-start hook**: Auto-scan on startup (if cache stale)
- **recommend command**: Ensure fresh index before recommendations
- **User manually**: When they install new plugins

The scan creates the foundation for all tool-advisor features.
