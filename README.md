# Claude Marketplace - Custom Plugins

Personal Claude Code plugin marketplace.

## Plugins

### tool-advisor

Intelligently analyze installed plugins, skills, and agents to recommend the best tools for any project or task.

**Features:**
- 🔍 Auto-optimize skill - Automatically read Project.md, ask questions, and spawn agents
- 📊 Capability indexing and search
- 🎯 Smart tool recommendations
- 🤖 Agent orchestration

**Skills:**
- `auto-optimize` - Project analysis and automated agent orchestration
- `discovery` - Plugin and capability discovery
- `recommendation` - Tool recommendation engine

**Commands:**
- `/scan-tools` - Scan and index all Claude Code tools
- `/recommend` - Get tool recommendations
- `/analyze-and-optimize` - Complete project analysis

## Installation

Add this marketplace to Claude Code:

```
/plugin marketplace add yourusername/claude-marketplace
```

Then install plugins:

```
/plugin install tool-advisor
```

## Usage

### Auto-Optimize Skill

Navigate to a project with a `Project.md` file and say:

```
"read my Project.md and get started"
```

The auto-optimize skill will:
1. Read your project requirements
2. Ask clarifying questions
3. Analyze your codebase
4. Automatically spawn and coordinate agents
5. Track progress and report results

### Manual Tool Analysis

```bash
# Scan your tools
/scan-tools

# Get recommendations
/recommend "I need to test my React components"

# Complete analysis
/analyze-and-optimize
```

## License

MIT
