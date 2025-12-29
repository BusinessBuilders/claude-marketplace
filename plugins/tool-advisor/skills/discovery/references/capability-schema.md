# Capability Index Schema Reference

Complete specification for the tool-advisor capability index data structure.

## Overview

The capability index is a searchable JSON document stored at `~/.claude/tool-advisor-cache.json` that catalogs all available Claude Code tools and their capabilities.

## Top-Level Schema

```typescript
interface CapabilityIndex {
  version: string;              // Schema version (e.g., "1.0.0")
  last_scan: string;            // ISO 8601 timestamp of last scan
  scan_locations: string[];     // Directories scanned
  total_plugins: number;        // Count of discovered plugins
  total_capabilities: number;   // Total capability entries
  capabilities: Capability[];   // Array of capability entries
  keyword_index: KeywordIndex;  // Searchable keyword mapping
  plugin_index: PluginIndex;    // Plugin metadata mapping
  statistics: ScanStatistics;   // Scan metrics
}
```

## Capability Entry Schema

```typescript
interface Capability {
  // Identification
  id: string;                   // Unique identifier (e.g., "plugin:component")
  type: CapabilityType;         // Component type
  name: string;                 // Human-readable name
  plugin: string;               // Parent plugin name

  // Discovery
  description: string;          // What this capability does
  keywords: string[];           // Searchable keywords
  triggers: string[];           // Trigger phrases (for agents/skills)

  // Location
  path: string;                 // Absolute file path
  relative_path: string;        // Path relative to plugin root

  // Metadata
  metadata: ComponentMetadata;  // Type-specific metadata

  // Usage tracking
  usage_count: number;          // How many times used
  last_used: string | null;     // ISO 8601 timestamp
  success_rate: number;         // 0.0 - 1.0

  // Scoring
  confidence_boost: number;     // User preference adjustment (-1.0 to 1.0)
  tags: string[];               // User-defined tags
}
```

### Capability Types

```typescript
type CapabilityType =
  | "agent"        // Autonomous agent
  | "command"      // Slash command
  | "skill"        // Agent skill
  | "hook"         // Event hook
  | "mcp_server"   // MCP server
  | "mcp_tool";    // MCP tool (from server)
```

### Component Metadata Schema

Metadata varies by capability type:

#### Agent Metadata

```typescript
interface AgentMetadata {
  model: string;                // "sonnet" | "opus" | "haiku" | "inherit"
  color: string;                // Visual indicator color
  tools: string[] | null;       // Allowed tools (null = all tools)
  system_prompt_length: number; // Character count
  example_count: number;        // Number of trigger examples
}
```

#### Command Metadata

```typescript
interface CommandMetadata {
  argument_hint: string | null; // Expected argument format
  allowed_tools: string[];      // Tools this command can use
  is_interactive: boolean;      // Requires user interaction
}
```

#### Skill Metadata

```typescript
interface SkillMetadata {
  version: string;              // Skill version
  has_references: boolean;      // Has references/ directory
  has_examples: boolean;        // Has examples/ directory
  has_scripts: boolean;         // Has scripts/ directory
  file_count: number;           // Total files in skill
}
```

#### Hook Metadata

```typescript
interface HookMetadata {
  event: string;                // Hook event type
  hook_type: "prompt" | "command";
  priority: number | null;      // Execution priority
  conditions: string[] | null;  // Activation conditions
}
```

#### MCP Metadata

```typescript
interface McpServerMetadata {
  server_type: "stdio" | "sse" | "http";
  command: string | null;       // Server command
  tools_count: number;          // Number of exposed tools
  resources_count: number;      // Number of exposed resources
}

interface McpToolMetadata {
  server_name: string;          // Parent MCP server
  input_schema: object;         // Tool input parameters
  returns: string;              // Return type description
}
```

## Keyword Index Schema

```typescript
interface KeywordIndex {
  // Map keywords to capability IDs
  [keyword: string]: string[];
}
```

**Example**:

```json
{
  "deploy": [
    "cloud-infrastructure:deploy",
    "deployment-strategies:blue-green",
    "kubernetes-operations:helm-deploy"
  ],
  "test": [
    "tdd-workflows:run-tests",
    "unit-testing:generate-tests"
  ]
}
```

## Plugin Index Schema

```typescript
interface PluginIndex {
  [pluginName: string]: PluginMetadata;
}

interface PluginMetadata {
  name: string;
  version: string;
  description: string;
  author: AuthorInfo | null;
  path: string;
  keywords: string[];
  capabilities: string[];       // Array of capability IDs
  install_location: "marketplace" | "user" | "project";
}
```

## Scan Statistics

```typescript
interface ScanStatistics {
  scan_duration_ms: number;
  plugins_scanned: number;
  plugins_skipped: number;       // Malformed or excluded
  capabilities_found: number;
  capabilities_updated: number;   // Changed since last scan
  errors: ScanError[];
}

interface ScanError {
  path: string;
  error: string;
  timestamp: string;
}
```

## Complete Example

```json
{
  "version": "1.0.0",
  "last_scan": "2025-01-15T10:30:00Z",
  "scan_locations": [
    "/home/user/.claude/plugins/marketplaces",
    "/home/user/.claude/plugins",
    "/home/user/.claude/skills",
    "/project/.claude"
  ],
  "total_plugins": 42,
  "total_capabilities": 156,
  "capabilities": [
    {
      "id": "cloud-infrastructure:terraform-specialist",
      "type": "agent",
      "name": "Terraform Specialist",
      "plugin": "cloud-infrastructure",
      "description": "Expert agent for Terraform infrastructure as code development, planning, and troubleshooting",
      "keywords": ["terraform", "infrastructure", "iac", "cloud", "aws", "azure"],
      "triggers": [
        "help with terraform",
        "create infrastructure",
        "deploy to aws",
        "terraform plan"
      ],
      "path": "/home/user/.claude/plugins/marketplaces/claude-code-workflows/plugins/cloud-infrastructure/agents/terraform-specialist.md",
      "relative_path": "agents/terraform-specialist.md",
      "metadata": {
        "model": "sonnet",
        "color": "blue",
        "tools": ["Read", "Write", "Bash"],
        "system_prompt_length": 8557,
        "example_count": 4
      },
      "usage_count": 12,
      "last_used": "2025-01-14T15:22:00Z",
      "success_rate": 0.92,
      "confidence_boost": 0.1,
      "tags": ["infrastructure", "preferred"]
    },
    {
      "id": "tool-advisor:recommend",
      "type": "command",
      "name": "Recommend Tool",
      "plugin": "tool-advisor",
      "description": "Get intelligent recommendations for the best tool to use for a specific task",
      "keywords": ["recommend", "suggest", "find", "tool", "command"],
      "triggers": [],
      "path": "/home/user/.claude/plugins/tool-advisor/commands/recommend.md",
      "relative_path": "commands/recommend.md",
      "metadata": {
        "argument_hint": "[task-description]",
        "allowed_tools": ["Read", "Bash"],
        "is_interactive": true
      },
      "usage_count": 0,
      "last_used": null,
      "success_rate": 1.0,
      "confidence_boost": 0.0,
      "tags": []
    }
  ],
  "keyword_index": {
    "terraform": [
      "cloud-infrastructure:terraform-specialist",
      "cloud-infrastructure:terraform-module-library"
    ],
    "deploy": [
      "cloud-infrastructure:deployment-engineer",
      "deployment-strategies:blue-green-deploy",
      "kubernetes-operations:helm-deploy"
    ],
    "test": [
      "tdd-workflows:test-runner",
      "unit-testing:generate-tests",
      "unit-testing:run-tests"
    ],
    "recommend": [
      "tool-advisor:recommend",
      "tool-advisor:recommendation-engine"
    ]
  },
  "plugin_index": {
    "cloud-infrastructure": {
      "name": "cloud-infrastructure",
      "version": "1.0.0",
      "description": "Cloud infrastructure management toolkit",
      "author": {
        "name": "Plugin Author",
        "email": "author@example.com"
      },
      "path": "/home/user/.claude/plugins/marketplaces/claude-code-workflows/plugins/cloud-infrastructure",
      "keywords": ["cloud", "infrastructure", "terraform", "kubernetes"],
      "capabilities": [
        "cloud-infrastructure:terraform-specialist",
        "cloud-infrastructure:deployment-engineer",
        "cloud-infrastructure:cloud-architect"
      ],
      "install_location": "marketplace"
    },
    "tool-advisor": {
      "name": "tool-advisor",
      "version": "0.1.0",
      "description": "Intelligent tool recommendation and discovery",
      "author": {
        "name": "Will",
        "email": "will@business-builder.online"
      },
      "path": "/home/user/.claude/plugins/tool-advisor",
      "keywords": ["recommendation", "discovery", "analysis"],
      "capabilities": [
        "tool-advisor:recommend",
        "tool-advisor:scan-tools",
        "tool-advisor:tool-scanner",
        "tool-advisor:recommendation-engine"
      ],
      "install_location": "user"
    }
  },
  "statistics": {
    "scan_duration_ms": 1250,
    "plugins_scanned": 42,
    "plugins_skipped": 2,
    "capabilities_found": 156,
    "capabilities_updated": 8,
    "errors": [
      {
        "path": "/home/user/.claude/plugins/broken-plugin",
        "error": "Invalid plugin.json: missing 'name' field",
        "timestamp": "2025-01-15T10:30:05Z"
      }
    ]
  }
}
```

## Schema Evolution

### Version 1.0.0 (Current)

Initial schema with core functionality.

### Future Versions

Planned additions:
- Dependency graphs (which capabilities use others)
- Performance metrics (execution time, resource usage)
- Security ratings
- Compatibility matrices
- User ratings/feedback

## Usage Patterns

### Loading the Index

```typescript
function loadCapabilityIndex(): CapabilityIndex {
  const cachePath = expandPath('~/.claude/tool-advisor-cache.json');
  if (!fileExists(cachePath)) {
    return createEmptyIndex();
  }
  return JSON.parse(readFile(cachePath));
}
```

### Searching by Keyword

```typescript
function findByKeyword(keyword: string): Capability[] {
  const index = loadCapabilityIndex();
  const ids = index.keyword_index[keyword.toLowerCase()] || [];
  return ids.map(id =>
    index.capabilities.find(c => c.id === id)
  ).filter(Boolean);
}
```

### Adding a Capability

```typescript
function addCapability(capability: Capability): void {
  const index = loadCapabilityIndex();

  // Add to capabilities array
  index.capabilities.push(capability);
  index.total_capabilities++;

  // Update keyword index
  for (const keyword of capability.keywords) {
    if (!index.keyword_index[keyword]) {
      index.keyword_index[keyword] = [];
    }
    index.keyword_index[keyword].push(capability.id);
  }

  // Update plugin index
  if (!index.plugin_index[capability.plugin]) {
    index.plugin_index[capability.plugin] = createPluginEntry(capability.plugin);
  }
  index.plugin_index[capability.plugin].capabilities.push(capability.id);

  saveCapabilityIndex(index);
}
```

### Updating Usage Statistics

```typescript
function recordUsage(capabilityId: string, success: boolean): void {
  const index = loadCapabilityIndex();
  const capability = index.capabilities.find(c => c.id === capabilityId);

  if (capability) {
    capability.usage_count++;
    capability.last_used = new Date().toISOString();

    // Update success rate with exponential moving average
    const alpha = 0.2;
    const newRate = success ? 1.0 : 0.0;
    capability.success_rate =
      alpha * newRate + (1 - alpha) * capability.success_rate;

    saveCapabilityIndex(index);
  }
}
```

## Validation

### Schema Validation

Validate index structure before use:

```typescript
function validateIndex(index: any): boolean {
  if (!index.version || !index.capabilities || !index.keyword_index) {
    return false;
  }

  for (const capability of index.capabilities) {
    if (!capability.id || !capability.type || !capability.name) {
      return false;
    }
  }

  return true;
}
```

### Consistency Checks

Ensure internal consistency:

- All capability IDs are unique
- All plugin references exist in plugin_index
- Keyword index entries reference valid capabilities
- Usage statistics are valid (0.0 - 1.0 for success_rate)
