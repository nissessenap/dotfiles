---
date: 2026-01-01T12:00:00+01:00
researcher: Claude
git_commit: 1165dd36a00263e803bc196e269bf7d8cf83aa40
branch: claude_ralpg_loop
repository: dotfiles
topic: "Orchestrator + Sub-agents Pattern for Automated Plan Implementation"
tags: [research, automation, sub-agents, ralph-loop, implement_plan, context-isolation]
status: complete
last_updated: 2026-01-02
last_updated_by: Claude
last_updated_note: "Added checkbox-based verification to avoid duplicate test runs"
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

The solution combines four mechanisms:

1. **Setup skill** (`/setup_orchestrate`) - Generates the ralph-loop command for user verification
2. **Ralph-loop** as the outer automation loop (keeps the orchestrator running)
3. **A thin orchestrator** that tracks state and coordinates work
4. **Sub-agents** for isolated implementation and review (fresh context per phase)

Key design decisions:

- **Two-step workflow**: User runs setup skill, verifies output, then starts ralph-loop
- **Dynamic test parsing**: Verification commands extracted from plan's success criteria (not hardcoded)
- **Unified exit strategy**: Single completion promise with context explaining why (success, blocked, needs input)

This architecture achieves the user's goals:

- Automated progression through 7+ phase plans
- Fresh context for each phase (no accumulated confusion)
- Self-healing with retry limits (try to fix, escalate after N failures)
- Commits between phases
- Human notification on completion, errors, or when feedback is needed
- User can verify ralph-loop command before execution

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

### Two-Step Workflow

```
STEP 1: Setup (user runs once)
┌─────────────────────────────────────────────────────────────────┐
│  /setup_orchestrate thoughts/plans/feature.md                   │
│                                                                 │
│  Outputs:                                                       │
│  - Creates .claude/orchestrator-state.json                      │
│  - Displays ralph-loop command for verification                 │
│  - User reviews and decides to proceed                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ (user copies and runs)
STEP 2: Execution (automated)
┌─────────────────────────────────────────────────────────────────┐
│  /ralph-loop "/orchestrate_plan ..." --completion-promise ...   │
└─────────────────────────────────────────────────────────────────┘
```

### The Orchestrator Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│  RALPH-LOOP (outer automation)                                  │
│  - Keeps orchestrator running                                   │
│  - Stops on: "ORCHESTRATION_STOPPED" or max_iterations          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  ORCHESTRATOR (thin main context)                               │
│  1. Read plan document                                          │
│  2. Read state file (.claude/orchestrator-state.json)           │
│  3. Determine current phase                                     │
│  4. Spawn sub-agent for implementation                          │
│  5. Parse & run verification commands FROM PLAN                 │
│  6. Spawn sub-agent for code review                             │
│  7. If issues: retry or escalate                                │
│  8. If success: commit, update state, proceed                   │
│  9. When done/blocked/needs-input: output completion signal     │
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

### The Setup Skill

File: `.claude/commands/setup_orchestrate.md`

```markdown
---
description: Setup orchestration for a plan (generates ralph-loop command)
model: opus
argument-hint: "<path-to-plan.md> [--max-retries N] [--start-phase N]"
---

# Setup Orchestration

Prepares orchestration for a plan and outputs the ralph-loop command for verification.

## Arguments
- `plan_path` (required): Path to the implementation plan
- `--max-retries N`: Max fix attempts per phase (default: 3)
- `--start-phase N`: Start from specific phase (default: 1, or resume from state)

## Workflow

1. Read and validate the plan document
2. Count total phases
3. Create/update state file: `.claude/orchestrator-state.json`
4. Output the ralph-loop command for user to verify and run

## Output Format

```

✅ Orchestration prepared for: {plan_path}

Plan Summary:

- Total phases: {N}
- Starting from: Phase {start_phase}
- Max retries per phase: {max_retries}

Phases detected:

1. {Phase 1 name}
2. {Phase 2 name}
...

State file created: .claude/orchestrator-state.json

To start automated execution, run:
────────────────────────────────────────────────────────────
/ralph-loop "/orchestrate_plan {plan_path}" \
  --max-iterations {calculated} \
  --completion-promise "ORCHESTRATION_STOPPED"
────────────────────────────────────────────────────────────

⚠️  Review the above command before running.
    The loop will run until completion, error, or max iterations.

```
```

### The Orchestrator Command

File: `.claude/commands/orchestrate_plan.md`

```markdown
---
description: Execute plan phases with sub-agents (called by ralph-loop)
model: opus
---

# Orchestrate Plan Implementation

## Overview
Executes plan phases using sub-agents for context isolation.
Parses verification commands from each phase's success criteria.
Uses unified exit strategy - always exits with same promise, context explains why.

## Workflow

### 1. Initialize
- Read the plan document (passed as argument)
- Read state file: `.claude/orchestrator-state.json`
- Determine current phase (may be resuming)

### 2. For Each Phase (until complete or stopped)

#### 2.1 Implementation
Spawn sub-agent with:
- subagent_type: "senior-software-engineer"
- prompt: "Implement Phase {N} from plan {path}. Read the plan first.
          Focus ONLY on this phase. The plan contains success criteria."

Wait for sub-agent to return.

#### 2.2 Verification (Checkbox-Based)

The plan file is the source of truth. Sub-agents mark checkboxes as they complete verification steps.

**How it works:**

1. Sub-agent implements the phase
2. Sub-agent runs verification commands and marks checkboxes in the plan:
   ```markdown
   #### Automated Verification:
   - [x] Unit tests pass: `make test`        ← sub-agent ran this
   - [x] Linting passes: `make lint`         ← sub-agent ran this
   - [ ] E2E tests pass: `make e2e`          ← sub-agent skipped (slow)
   ```

1. Orchestrator reads the plan after sub-agent returns
2. Orchestrator only runs UNCHECKED items (e.g., `make e2e`)
3. If unchecked items pass, orchestrator marks them checked

**Benefits:**

- No duplicate test runs (especially important for slow e2e tests)
- Sub-agent has discretion to skip slow tests if not strictly needed
- Plan file shows exactly what was verified and by whom

**If any unchecked command fails:**

- Increment retry_count
- If retry_count <= max_retries: spawn fix sub-agent with the failure details
- If retry_count > max_retries: EXIT with blocked status

#### 2.3 Code Review

Spawn sub-agent with:

- subagent_type: "code-reviewer" (your code-reviewe agent)
- prompt: "Review the changes for Phase {N}.
          Run: git diff to see changes. Focus on blockers only."

Parse review results:

- If blockers found and retry_count <= max_retries: spawn fix sub-agent
- If blockers found and retry_count > max_retries: EXIT with blocked status
- If no blockers: proceed

#### 2.4 Commit

If all verification passed:

- `git add -A && git commit -m "Phase {N}: {description}"`
- Update state file: mark phase complete, reset retry_count

#### 2.5 Proceed or Exit

- If more phases: continue to next phase
- If all phases done: EXIT with success status

### 3. Unified Exit Strategy

Always exit with the same completion promise. Context explains why:

**Success:**

```
<promise>ORCHESTRATION_STOPPED</promise>

✅ All phases complete!

Completed phases:
1. Phase 1: {description} (commit: abc123)
2. Phase 2: {description} (commit: def456)
...

Ready for you to push and create PR.
```

**Blocked (retries exhausted):**

```
<promise>ORCHESTRATION_STOPPED</promise>

⛔ Phase {N} blocked after {max_retries} attempts.

Last error:
{error details}

Attempted fixes:
1. {first attempt summary}
2. {second attempt summary}
3. {third attempt summary}

To resume after fixing: /setup_orchestrate {path} --start-phase {N}
```

**Needs Human Input:**

```
<promise>ORCHESTRATION_STOPPED</promise>

🤚 Phase {N} needs your input.

Question: {what the orchestrator is unsure about}

Options:
1. {option 1}
2. {option 2}

After deciding, update the plan or state file and run:
/setup_orchestrate {path} --start-phase {N}
```

```

### Usage Flow

```bash
# Step 1: Setup (verify before running)
/setup_orchestrate thoughts/plans/2026-01-01-feature.md

# Step 2: Run the output command (after verification)
/ralph-loop "/orchestrate_plan thoughts/plans/2026-01-01-feature.md" \
  --max-iterations 50 \
  --completion-promise "ORCHESTRATION_STOPPED"

# Step 3: After completion/error, review output and either:
# - Push and create PR (if success)
# - Fix issue and re-run setup (if blocked)
```

## Sub-agent Prompts

### Implementation Sub-agent

```text
You are implementing Phase {N} of a plan.

Plan path: {plan_path}
Phase: {N} of {total}

Instructions:
1. Read the plan document completely
2. Find the section for Phase {N}
3. Implement ONLY what's described in that phase
4. Run verification commands from the "Automated Verification" section
5. IMPORTANT: Mark checkboxes in the plan file for tests you run successfully:
   - Change `- [ ]` to `- [x]` for each passing verification
   - Leave unchecked if you skip a test (e.g., slow e2e tests)
6. Do not proceed to other phases
7. When done, summarize what you implemented and verified

Return format:
- SUCCESS: {summary of changes}
  - Verified: {list of checkboxes you marked}
  - Skipped: {list of verifications left unchecked, if any}
- FAILURE: {what went wrong}
```

### Code Review Sub-agent

```text
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

```text
You are fixing issues found in Phase {N}.

Plan path: {plan_path}
Issues to fix:
{list of issues from verification/review}

Instructions:
1. Read the relevant files
2. Fix ONLY the listed issues
3. Do not refactor or improve other code
4. Run the failing verification command(s) after fixing
5. If tests pass, mark the checkbox in the plan file:
   - Change `- [ ]` to `- [x]` for the now-passing verification

Return format:
- FIXED: {summary of fixes}
  - Verified: {checkboxes you marked after successful re-run}
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

## Design Decisions

1. **Test command detection**: ✅ RESOLVED
   - Commands are parsed dynamically from each phase's "Automated Verification" section
   - No hardcoded commands - each phase specifies exactly what to run
   - Supports complex test matrices (unit, integration, e2e) per-phase

2. **Exit strategy**: ✅ RESOLVED
   - Single completion promise: `ORCHESTRATION_STOPPED`
   - Context in output explains why (success, blocked, needs input)
   - Allows loop to exit cleanly in all scenarios

3. **Two-step workflow**: ✅ RESOLVED
   - `/setup_orchestrate` prepares and shows the ralph-loop command
   - User verifies before running
   - Prevents accidental long-running automation

4. **Avoiding duplicate test runs**: ✅ RESOLVED
   - Plan file checkboxes are the source of truth
   - Sub-agents mark `- [x]` for tests they run successfully
   - Orchestrator only runs UNCHECKED verification items
   - Prevents slow tests (e2e) from running twice
   - Sub-agents have discretion to skip slow tests if not strictly needed
   - Trust model: fully trust sub-agent checkmarks (they ran the tests with fresh context)

## Open Questions

1. **Phase dependency parsing**: How to detect parallelizable phases?
   - Could require explicit markers in plan format (e.g., `depends_on: [Phase 1]`)
   - Could assume sequential by default
   - For now: assume sequential, parallel is future enhancement

2. **Commit granularity**: One commit per phase or squash on completion?
   - Current design: per-phase commits (enables bisecting)

3. **Manual verification steps**: How to handle phases with manual verification?
   - Current plans have "Manual Verification" sections
   - Could skip those and note them in exit output
   - Could prompt for human confirmation (adds complexity)

## Answers

1. don't parallelizable for starters
2. one commit per phase
3. skip them for now.
