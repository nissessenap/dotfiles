---
date: 2026-01-01T12:00:00+01:00
researcher: Claude
git_commit: 1165dd36a00263e803bc196e269bf7d8cf83aa40
branch: claude_ralpg_loop
repository: dotfiles
topic: "Orchestrator + Sub-agents Pattern for Automated Plan Implementation"
tags: [research, automation, sub-agents, ralph-loop, implement_plan, context-isolation]
status: complete
last_updated: 2026-01-01
last_updated_by: Claude
---

# Research: Orchestrator + Sub-agents Pattern for Automated Plan Implementation

**Date**: 2026-01-01T12:00:00+01:00
**Researcher**: Claude
**Git Commit**: 1165dd36a00263e803bc196e269bf7d8cf83aa40
**Branch**: claude_ralpg_loop
**Repository**: dotfiles

## Research Question

How can the ralph-loop automation pattern be combined with sub-agents to implement multi-phase plans while maintaining context isolation between phases?

## Summary

The solution combines three mechanisms:

1. **Ralph-loop** as the outer automation loop (keeps the orchestrator running)
2. **A thin orchestrator** that tracks state and coordinates work
3. **Sub-agents** for isolated implementation and review (fresh context per phase)

This architecture achieves the user's goals:

- Automated progression through 7+ phase plans
- Fresh context for each phase (no accumulated confusion)
- Self-healing with retry limits (try to fix, escalate after N failures)
- Commits between phases
- Human notification on completion or unrecoverable errors

## Detailed Findings

### Sub-agent Context Isolation (Confirmed)

From Claude Code documentation:

- Each sub-agent operates in **its own isolated context window**
- The parent receives only the **final result**, not intermediate work
- Files read, edits made, and explorations by sub-agents do NOT pollute parent context
- Sub-agents have access to the filesystem but NOT the parent's conversation history

This means:

```
Orchestrator context stays lean:
- Reads plan document once
- Tracks phase number (1, 2, 3...)
- Receives summary results from sub-agents
- Never accumulates implementation details
```

### Ralph-loop Mechanism

The ralph-loop creates a state file (`.claude/ralph-loop.local.md`) with:

```yaml
---
active: true
iteration: 1
max_iterations: 20
completion_promise: "ALL_PHASES_COMPLETE"
---
<your prompt here>
```

When Claude tries to exit:

- Stop hook intercepts
- Same prompt re-injected
- Iteration counter increments
- Continues until `completion_promise` output or `max_iterations` reached

### Stop Hook Capabilities

Stop hooks can:

- **Block exit** (exit code 2 or `{"decision": "block"}`)
- **Inject context** (stderr shown to Claude)
- **Read state files** to make decisions
- **Use LLM evaluation** (Haiku) for context-aware decisions

## Architecture Documentation

### The Orchestrator Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│  RALPH-LOOP (outer automation)                                  │
│  - Keeps orchestrator running                                   │
│  - Stops on: "ALL_PHASES_COMPLETE" or max_iterations            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  ORCHESTRATOR (thin main context)                               │
│  1. Read plan document                                          │
│  2. Read state file (.claude/orchestrator-state.json)           │
│  3. Determine current phase                                     │
│  4. Spawn sub-agent for implementation                          │
│  5. Run verification (tests/lint) directly                      │
│  6. Spawn sub-agent for code review                             │
│  7. If issues: retry or escalate                                │
│  8. If success: commit, update state, proceed                   │
│  9. When done: output completion signal                         │
└─────────────────────────────────────────────────────────────────┘
            │                                    │
            ▼                                    ▼
┌───────────────────────┐           ┌───────────────────────┐
│  SUB-AGENT:           │           │  SUB-AGENT:           │
│  Implement Phase N    │           │  Code Review          │
│  (isolated context)   │           │  (isolated context)   │
└───────────────────────┘           └───────────────────────┘
            │                                    │
            ▼                                    ▼
     Returns: result                      Returns: findings
     + success/failure                    + blockers/warnings
```

### State File Structure

File: `.claude/orchestrator-state.json`

```json
{
  "plan_path": "thoughts/plans/2026-01-01-TICKET-123-feature.md",
  "total_phases": 7,
  "current_phase": 3,
  "phase_status": "implementing",
  "retry_count": 0,
  "max_retries": 3,
  "completed_phases": [1, 2],
  "commits": [
    {"phase": 1, "hash": "abc123", "message": "Phase 1: ..."},
    {"phase": 2, "hash": "def456", "message": "Phase 2: ..."}
  ],
  "last_error": null
}
```

### The Orchestrator Command

File: `.claude/commands/orchestrate_plan.md`

```markdown
---
description: Automated plan implementation with sub-agents
model: opus
---

# Orchestrate Plan Implementation

## Overview
Automatically implement a plan using sub-agents for context isolation.
Each phase runs in a fresh sub-agent context. Commits after each phase.
Self-heals up to 3 times before escalating to human.

## Workflow

### 1. Initialize
- Read the plan document (passed as argument)
- Read/create state file: `.claude/orchestrator-state.json`
- Determine current phase (may be resuming)

### 2. For Each Phase (until complete or blocked)

#### 2.1 Implementation
Spawn sub-agent with:
- subagent_type: "senior-software-engineer"
- prompt: "Implement Phase {N} from plan {path}. Read the plan first.
          Focus ONLY on this phase. The plan contains success criteria."

Wait for sub-agent to return.

#### 2.2 Verification
Run directly (not in sub-agent):
- `make test` (or project-specific test command)
- `make lint` (or project-specific lint command)

If tests/lint fail:
- Increment retry_count
- If retry_count <= 3: spawn fix sub-agent
- If retry_count > 3: STOP and ask human

#### 2.3 Code Review
Spawn sub-agent with:
- subagent_type: "code-reviewer" (your code-reviewe agent)
- prompt: "Review the changes for Phase {N}. 
          Run: git diff HEAD~1 to see changes."

Parse review results:
- If blockers found and retry_count <= 3: spawn fix sub-agent
- If blockers found and retry_count > 3: STOP and ask human
- If no blockers: proceed

#### 2.4 Commit
If all verification passed:
- `git add -A && git commit -m "Phase {N}: {description}"`
- Update state file: mark phase complete, reset retry_count

#### 2.5 Proceed or Complete
- If more phases: continue to next phase
- If all phases done: output "ALL_PHASES_COMPLETE" and stop

### 3. Error Escalation
When retry_count > 3:
```

⛔ Phase {N} blocked after 3 attempts.

Last error:
{error details}

Attempted fixes:

1. {first attempt summary}
2. {second attempt summary}
3. {third attempt summary}

Please review and either:

- Fix manually and run: /orchestrate_plan {path} --resume
- Provide guidance for next attempt

```
```

### Starting the Automated Loop

```bash
# Start the orchestrated implementation
/ralph-loop "/orchestrate_plan thoughts/plans/2026-01-01-feature.md" \
  --max-iterations 50 \
  --completion-promise "ALL_PHASES_COMPLETE"
```

### Resume After Human Intervention

```bash
# After fixing an issue manually
/orchestrate_plan thoughts/plans/2026-01-01-feature.md --resume
```

## Sub-agent Prompts

### Implementation Sub-agent

```
You are implementing Phase {N} of a plan.

Plan path: {plan_path}
Phase: {N} of {total}

Instructions:
1. Read the plan document completely
2. Find the section for Phase {N}
3. Implement ONLY what's described in that phase
4. Follow the success criteria listed
5. Do not proceed to other phases
6. When done, summarize what you implemented

Return format:
- SUCCESS: {summary of changes}
- FAILURE: {what went wrong}
```

### Code Review Sub-agent

```
You are reviewing code changes for Phase {N}.

Review the diff: `git diff HEAD~1`

Focus ONLY on blockers (Level 1 from code-reviewe.md):
- Security vulnerabilities
- Critical logic bugs
- Missing tests for new logic
- Breaking API changes

Ignore:
- Style suggestions
- Minor improvements
- Documentation gaps

Return format:
- APPROVED: {brief summary}
- BLOCKERS: {list of blocking issues}
```

### Fix Sub-agent

```
You are fixing issues found in Phase {N}.

Issues to fix:
{list of issues from verification/review}

Instructions:
1. Read the relevant files
2. Fix ONLY the listed issues
3. Do not refactor or improve other code
4. Run tests after fixing

Return format:
- FIXED: {summary of fixes}
- UNABLE: {what couldn't be fixed and why}
```

## Code References

- `claude/.claude/commands/implement_plan.md:1-85` - Current manual implementation workflow
- `claude/.claude/commands/code-reviewe.md:1-86` - Code review criteria
- `claude/.claude/agents/senior-software-engineer.md:1-23` - Implementation agent

## Considerations

### Parallel Phases

Some plans have phases that can run in parallel. The orchestrator could:

1. Parse the plan for dependency markers (e.g., "depends on Phase 2")
2. Spawn multiple implementation sub-agents concurrently
3. Wait for all to complete before proceeding

### Context Passing

Sub-agents don't have access to orchestrator's conversation history.
Must explicitly include in prompts:

- Plan path
- Phase number
- Any relevant context from previous phases

### State Persistence

The state file enables:

- Resume after crashes
- Resume after human intervention
- Tracking progress across sessions

## Alternative Approaches

### Option 1: Ralph-loop + Sub-agents (Documented Above)

**How it works**: Ralph-loop keeps a thin orchestrator running. The orchestrator delegates all implementation and review work to sub-agents with isolated contexts.

| Aspect | Details |
|--------|---------|
| Context Isolation | Per sub-agent (fresh each spawn) |
| Automation | Stop hook prevents exit until complete |
| Complexity | Medium - requires orchestrator command |
| Best For | Your current workflow with minimal changes |

---

### Option 2: CLI Headless Mode (`claude -p`)

**How it works**: Each phase runs as a completely separate `claude -p` invocation. A shell script orchestrates the phases.

```bash
#!/bin/bash
# orchestrate.sh - Each invocation gets fresh context automatically

PLAN="$1"

# Phase 1
claude -p "Implement Phase 1 from $PLAN" \
  --allowedTools "Read,Edit,Write,Bash" \
  --output-format json > phase1_result.json

# Run tests directly
make test || { echo "Tests failed"; exit 1; }

# Phase 2 (completely fresh context)
claude -p "Implement Phase 2 from $PLAN" \
  --allowedTools "Read,Edit,Write,Bash" \
  --output-format json > phase2_result.json

# ... continue for all phases
```

| Aspect | Details |
|--------|---------|
| Context Isolation | Guaranteed (each `claude -p` is fresh) |
| Automation | Shell script controls flow |
| Complexity | Low - just bash scripting |
| Best For | CI/CD integration, simple workflows |

**Limitations**:

- Slash commands (`/research_codebase`) not available in `-p` mode
- No interactive prompts possible
- Less sophisticated error recovery

**Source**: [Claude Code Headless Mode](https://docs.anthropic.com/en/docs/claude-code/core-features/headless-mode)

---

### Option 3: Git Worktrees + Parallel Sessions

**How it works**: Each phase runs in a separate git worktree with its own Claude session. Complete filesystem and context isolation.

```bash
#!/bin/bash
# Create worktrees for parallel work
git worktree add ../project-phase1 -b phase1
git worktree add ../project-phase2 -b phase2

# Run phases in parallel (if independent)
(cd ../project-phase1 && claude -p "Implement Phase 1") &
(cd ../project-phase2 && claude -p "Implement Phase 2") &
wait

# Merge results
git merge phase1 phase2
```

| Aspect | Details |
|--------|---------|
| Context Isolation | Complete (filesystem-level separation) |
| Automation | Shell script with git |
| Complexity | Medium - requires git worktree knowledge |
| Best For | Large refactors, truly parallel phases |

**Limitations**:

- Requires careful merge conflict handling
- More disk space (multiple working directories)
- Overkill for sequential phases

**Source**: [Running Claude Code in Parallel with Git Worktrees](https://dev.to/datadeer/part-2-running-multiple-claude-code-sessions-in-parallel-with-git-worktree-165i)

---

### Option 4: Claude Agent SDK (Python/TypeScript)

**How it works**: Build a custom orchestrator using the Agent SDK. Full programmatic control over agent behavior.

```python
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition

async def orchestrate_plan(plan_path: str):
    for phase in parse_phases(plan_path):
        # Each query() call can use subagents with isolated context
        result = await query(
            prompt=f"Implement Phase {phase.number} from {plan_path}",
            options=ClaudeAgentOptions(
                allowed_tools=["Read", "Edit", "Write", "Bash", "Task"],
                agents={
                    "implementer": AgentDefinition(
                        description="Implements plan phases",
                        tools=["Read", "Edit", "Write", "Bash"]
                    ),
                    "reviewer": AgentDefinition(
                        description="Reviews code changes",
                        tools=["Read", "Grep", "Bash"]
                    )
                }
            )
        )

        # Run verification
        if not run_tests():
            # Retry logic here
            pass

        # Commit
        commit_phase(phase)
```

| Aspect | Details |
|--------|---------|
| Context Isolation | Per subagent + per query() call |
| Automation | Full programmatic control |
| Complexity | High - requires SDK development |
| Best For | Production systems, complex workflows |

**Limitations**:

- Requires Python/TypeScript development
- More complex setup
- Overkill for personal workflow automation

**Source**: [Claude Agent SDK](https://github.com/anthropics/claude-agent-sdk-python)

---

### Option 5: MCP Workflow Server

**How it works**: Define workflows declaratively in YAML. An MCP server orchestrates execution.

```yaml
# workflows/implement-plan.yaml
name: implement-plan
steps:
  - name: implement
    agent: senior-software-engineer
    tools: [Read, Edit, Write, Bash]

  - name: test
    command: make test

  - name: review
    agent: code-reviewer
    tools: [Read, Grep, Bash]

  - name: commit
    command: git commit -am "Phase complete"
```

| Aspect | Details |
|--------|---------|
| Context Isolation | Depends on workflow design |
| Automation | Declarative YAML workflows |
| Complexity | Medium - requires MCP setup |
| Best For | Reusable workflow libraries |

**Source**: [Workflows MCP Server](https://github.com/cyanheads/workflows-mcp-server)

---

## Comparison Matrix

| Approach | Context Isolation | Setup Complexity | Fits Current Workflow | Parallel Phases |
|----------|------------------|------------------|----------------------|-----------------|
| Ralph-loop + Sub-agents | Per sub-agent | Medium | Excellent | Yes |
| CLI `-p` mode | Per invocation | Low | Good (no slash commands) | Yes |
| Git Worktrees | Complete | Medium | Good | Excellent |
| Agent SDK | Per subagent/query | High | Requires rewrite | Yes |
| MCP Workflows | Design-dependent | Medium | Moderate | Design-dependent |

## Recommendation

For your specific workflow (research → plan → implement with phases):

**Primary: Ralph-loop + Sub-agents** (Option 1)

- Keeps your existing commands (`/implement_plan`, `/code-reviewe`)
- Sub-agents provide context isolation
- State file enables resume
- Self-healing with retry limits

**Alternative: CLI `-p` + Shell Script** (Option 2)

- Simpler to implement
- Guaranteed fresh context per phase
- But: loses slash commands and interactive features
- Good for: running overnight with no human interaction expected

**For parallel phases specifically**: Consider Git Worktrees (Option 3) for truly independent work.

## Open Questions

1. **Test command detection**: How to determine project-specific test/lint commands?
   - Could read from CONTRIBUTING.md or Makefile
   - Could be passed as arguments to orchestrate_plan

2. **Phase dependency parsing**: How to detect parallelizable phases?
   - Could require explicit markers in plan format
   - Could assume sequential by default

3. **Commit granularity**: One commit per phase or squash on completion?
   - Per-phase enables bisecting
   - Squash keeps history clean
