# Tool Advisor Hook Architecture

## What This Is

A set of Claude Code hooks that keep Claude working autonomously and verify production-grade output before stopping. Three hooks work together:

- **PostToolUse** → tracks what happened, cascades to next logical step
- **PreToolUse** → redirects to better tools if available
- **Stop** → blocks stopping until quality is verified

---

## How It Came To Be

The hook system grew from one observation: Claude stops too early. It finishes a task, says "done," and waits. But often there's an obvious next step — run the tests, check the build, commit the changes. The user has to prompt Claude to keep going.

The solution was a cascade system: after every tool call, inject a system message telling Claude what to do next. After editing a TypeScript file → "run type-check." After tests pass → "commit or proceed to next task." This keeps Claude in motion without the user having to nudge it.

The Stop hook was added separately to enforce quality before Claude could exit. Phase 4 — the **Million Dollar Grant Quality Self-Check** — forces Claude to verify its own work before stopping. Claude must respond with `QUALITY VERIFIED: [summary]` to exit the loop. If it finds issues during self-check, it fixes them first. This single hook dramatically improved output quality.

---

## Hook Architecture

### hooks.json — Event Registration

```
SessionStart    → build-index.sh     (scan all plugins, build capability cache)
UserPromptSubmit → user-prompt-hook.sh (suggest relevant tools for the task)
PreToolUse      → pre-tool-hook.sh   (redirect to better tool if available)
PostToolUse     → post-tool-hook.sh  (cascade + failure tracking)
Stop            → stop-hook.sh       (quality gate + Million Dollar Grant check)
```

**IMPORTANT**: All matchers must be `"*"`. Pipe-separated tool names (`"Bash|Read|Write|..."`) do not work — Claude Code uses glob matching, not regex.

---

## stop-hook.sh — The Quality Gate

Runs in 4 phases. Each phase can either exit (block or approve) or fall through to the next.

### Phase 1: Incomplete Todos
Reads the transcript for TodoWrite entries with `in_progress` or `pending` status. If found, blocks and tells Claude to finish them. This catches Claude that creates a task list but stops before completing it.

### Phase 2: Unresolved Failures + Minimal Progress
Reads `~/.claude/tool-advisor-state.json` for the current session:
- If `failures > 0` → block, name the specific tool and error type
- If `tools_used < 2` → block with "very few actions taken" nudge

**Known issue**: Phase 2's `tools_used` check depends on PostToolUse writing to the state file. If PostToolUse isn't firing (see bug history below), `tools_used` is always 0 and Phase 2 fires on every session, blocking Phase 4 from ever running.

### Phase 3: Transcript Quality Gates
Scans last 3000 chars of transcript for actual problems:
- Detects `QUALITY VERIFIED` → approve (Claude already self-checked)
- Detects waiting for user input → approve
- Detects unresolved tool errors (ENOENT, exit code, npm ERR) → block
- Detects test failures → block
- Detects build failures → block

### Phase 4: Million Dollar Grant Quality Self-Check
**Always fires** if Phases 1-3 don't exit first. Blocks and asks Claude to verify:

1. ✅ Did I perform EVERYTHING the user requested?
2. 🚫 Did I add any placeholders (TODO, FIXME, ..., etc.)?
3. 🚫 Did I hardcode any values that should be configurable?
4. 🚫 Are there any issues that are NOT production-grade?
5. 💎 Is this MILLION DOLLAR GRANT grade code?
6. 🤔 Is there anything else I can do autonomously to help the user?

Claude must respond with `QUALITY VERIFIED: [brief summary]`. Phase 3 detects this phrase on the next stop attempt and approves.

---

## post-tool-hook.sh — Cascade Engine

Runs after every tool call. Two jobs:

### 1. Track Tool Usage
Writes to `~/.claude/tool-advisor-state.json`:
```json
{
  "sessions": {
    "<session_id>": {
      "tools_used": ["Read", "Edit", "Bash"],
      "failures": [],
      "steps_completed": 3
    }
  }
}
```
This is what stop-hook Phase 2 reads to know if real work was done.

**Bug history**: Originally tracked only on success (skipped when tool result looked like an error). Fixed to track before failure detection so all tool calls are counted. Also: Claude Code sends the tool result in the `tool_response` field, not `tool_result`. Fixed to read `tool_response // .tool_result` for compatibility.

### 2. Cascade Messages
On success, outputs a `systemMessage` pushing Claude toward the next logical step:
- `Edit`/`Write` on `.ts` → "Run type-check or tests to verify"
- `Bash` with test pass → "Commit changes or proceed to next task"
- `Bash` with build success → "Run tests or deploy if ready"
- `Glob`/`Grep`/`Read` → "Use this information to proceed"
- `Task` completed → "Review results and continue with main workflow"

On failure, outputs a recovery message with specific guidance per failure type (permission, not_found, timeout, syntax, network, type_error).

**Key design**: Failure messages include `➡️ CONTINUE` to keep Claude working instead of stopping.

---

## pre-tool-hook.sh — Tool Redirector

Reads `~/.claude/tool-advisor-cache.json` (built by `build-index.sh` at session start). If a more specialized tool is available for the current operation (e.g., a GitHub MCP tool instead of `git push` via Bash), outputs a suggestion.

Non-blocking by design — only outputs `systemMessage`, never blocks the tool call.

---

## State Files

| File | Purpose |
|------|---------|
| `~/.claude/tool-advisor-state.json` | Per-session tool usage and failure tracking |
| `~/.claude/tool-advisor-cache.json` | Installed plugin/MCP capability index |

State is cleaned up when the stop hook approves (Phase 4 path or "QUALITY VERIFIED" path).

---

## Known Bugs & Fixes Applied

### Bug: PostToolUse hook never fired
**Root cause**: `hooks.json` used pipe-separated matcher (`"Bash|Read|Write|..."`) which Claude Code doesn't support — it uses glob matching. The Stop hook worked because it used `"*"`.  
**Fix**: Change all PreToolUse and PostToolUse matchers to `"*"`.  
**Status**: Applied to cached copy. Needs verification via debug log before committing to source.

### Bug: tools_used never incremented
**Root cause**: `post-tool-hook.sh` read `.tool_result` but Claude Code sends `.tool_response`. Result was always empty → early exit → no tracking.  
**Secondary cause**: Tracking only happened on success path. Any tool result containing "error" was classified as failed and skipped tracking.  
**Fix**: Read `.tool_response // .tool_result`. Move tracking before failure detection.  
**Status**: Applied to cached copy. Needs verification.

### Bug: Phase 2 blocks every session (masks Phase 4)
**Root cause**: Because PostToolUse never fired, `tools_used` was always 0. Phase 2's `tools_used < 2` check always triggered, exiting before Phase 4.  
**Fix**: The matcher and field name fixes above should resolve this. Phase 2's nudge is valuable — keep it. Once tracking works, Phase 2 only fires on genuinely idle sessions.

---

## Verification Procedure

After any change to hooks.json or post-tool-hook.sh:

1. Restart Claude Code (hooks.json loads at session start)
2. Run any tool in the new session
3. Check: `cat ~/.claude/post-tool-debug.log`
   - Should show timestamp + JSON keys Claude Code sent
   - Confirm `tool_response_present: true` or `tool_result_present: true`
4. Check: `cat ~/.claude/tool-advisor-state.json`
   - Should show the new session ID with tools_used populated
5. Only after confirmed → remove debug logging → commit to source repo

---

## OpenCode Port

`~/.config/opencode/plugins/quality-check.js` bridges all three hooks to OpenCode:
- `tool.execute.before` → runs pre-tool-hook.sh
- `tool.execute.after` → runs post-tool-hook.sh  
- `event` (session.idle) → runs stop-hook.sh, re-prompts via `client.session.prompt()`

Auto-discovers latest plugin version from `~/.claude/plugins/cache/businessbuilders-marketplace/tool-advisor/*/scripts/`.
