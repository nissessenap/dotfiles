# Orchestrator + Sub-agents Workflow Implementation Plan

## Overview

Implement two commands that work with the existing ralph-loop plugin to automate multi-phase plan execution using sub-agents for context isolation.

Based on research: `thoughts/research/2026-01-01-orchestrator-subagent-workflow.md`

## Current State Analysis

- **Ralph-loop**: Existing plugin from awesomeclaude.ai that repeatedly feeds a prompt until completion promise is output
- **Existing commands**: `implement_plan.md` (manual, single-context), `code-reviewe.md` (review agent)
- **Existing agents**: `senior-software-engineer`, `code-reviewe`, various specialized agents
- **Missing**: Orchestration commands that leverage ralph-loop with sub-agents

## Desired End State

After implementation:

1. User runs `/setup_orchestrate thoughts/plans/feature.md --context "greenfield, breaking changes OK"`
2. Command creates state file and displays ralph-loop command to copy
3. User runs: `/ralph-loop "/orchestrate_plan" --completion-promise "ORCHESTRATION_STOPPED" --max-iterations 50`
4. Ralph-loop keeps re-invoking `/orchestrate_plan` until it outputs `ORCHESTRATION_STOPPED`
5. Each iteration: orchestrator reads state, spawns sub-agent for current phase, updates state
6. Sub-agents receive the custom context in their prompts

### Verification

- `/setup_orchestrate` creates valid state file with context
- `/orchestrate_plan` reads state, spawns sub-agents with context, outputs completion promise when done
- Full workflow completes a multi-phase plan automatically

## What We're NOT Doing

- Modifying ralph-loop (it's an existing plugin)
- Creating custom stop hooks (ralph-loop handles this)
- Parallel phase execution (future enhancement)
- Preset context flags - only `--context`

## Implementation Approach

Create two commands:

1. **`/setup_orchestrate`** - Parses plan, creates state file, outputs ralph-loop command
2. **`/orchestrate_plan`** - The orchestrator that ralph-loop repeatedly invokes

---

## Phase 1: Setup Orchestrate Command

### Overview

Create the setup command that validates a plan, creates state, and outputs the ralph-loop command for user to copy and run.

### Changes Required

**File**: `claude/.claude/commands/setup_orchestrate.md`

```markdown
---
description: Setup orchestration for a plan (generates ralph-loop command)
argument-hint: "<path-to-plan.md> [--context \"custom context\"] [--max-retries N] [--start-phase N]"
---

# Setup Orchestration

Prepares orchestration for a plan and outputs the ralph-loop command.

## Arguments

Parse from $ARGUMENTS:
- `plan_path` (required): Path to the implementation plan
- `--context "..."`: Custom context injected into all sub-agent prompts
- `--max-retries N`: Max fix attempts per phase (default: 3)
- `--start-phase N`: Start from specific phase (default: 1)

## Workflow

### 1. Parse Arguments

Extract plan_path, --context value, --max-retries, --start-phase from $ARGUMENTS.

### 2. Validate Plan

Read the plan file. Count phases by finding sections matching `## Phase \d+:` pattern.
Extract phase names for display.

If plan doesn't exist or has no phases, show error and stop.

### 3. Create State File

Write to `.claude/orchestrator-state.json`:

```json
{
  "plan_path": "<plan_path>",
  "total_phases": <N>,
  "current_phase": <start_phase>,
  "phase_status": "pending",
  "retry_count": 0,
  "max_retries": <max_retries>,
  "completed_phases": [],
  "commits": [],
  "last_error": null,
  "custom_context": "<context string or null>"
}
```

### 4. Output

Display:

```
✅ Orchestration prepared for: {plan_path}

Plan Summary:
- Total phases: {N}
- Starting from: Phase {start_phase}
- Max retries per phase: {max_retries}
- Custom context: {context or "None"}

Phases detected:
1. {Phase 1 name}
2. {Phase 2 name}
...

State file created: .claude/orchestrator-state.json

To start automated execution, copy and run:
────────────────────────────────────────────────────────────
/ralph-loop "/orchestrate_plan" --completion-promise "ORCHESTRATION_STOPPED" --max-iterations {phases * 5}
────────────────────────────────────────────────────────────

⚠️  Review the command before running. The loop will continue until
    all phases complete, an error requires human input, or max iterations.
```
```

### Success Criteria

#### Automated Verification

- [ ] Command file exists at `claude/.claude/commands/setup_orchestrate.md`
- [ ] Running `/setup_orchestrate thoughts/plans/test.md` creates `.claude/orchestrator-state.json`

#### Manual Verification

- [ ] Phase detection correctly identifies all phases
- [ ] `--context` argument stored correctly in state file
- [ ] Output displays correct ralph-loop command

---

## Phase 2: Orchestrate Plan Command

### Overview

Create the orchestrator command that ralph-loop repeatedly invokes. Each invocation processes one step (implement, verify, review, fix, or commit) then exits. Ralph-loop re-invokes until completion promise is output.

### Changes Required

**File**: `claude/.claude/commands/orchestrate_plan.md`

```markdown
---
description: Execute plan phases with sub-agents (called by ralph-loop)
---

# Orchestrate Plan Implementation

This command is invoked repeatedly by ralph-loop. Each invocation:
1. Reads state to determine what to do
2. Does ONE thing (spawn sub-agent, run verification, commit, etc.)
3. Updates state
4. Exits (ralph-loop re-invokes, or stops if completion promise output)

## Workflow

### 1. Read State

Read `.claude/orchestrator-state.json`. If missing:

```
⛔ No orchestration state found.
Run /setup_orchestrate <plan-path> first.

ORCHESTRATION_STOPPED
```

Also read the plan document from `state.plan_path`.

### 2. Route Based on Status

Check `state.phase_status` and route:

| Status | Action |
|--------|--------|
| `pending` | Start implementation of current phase |
| `implementing` | Check if implementation sub-agent is done, run verification |
| `verifying` | Run unchecked verification commands |
| `reviewing` | Spawn review sub-agent |
| `fixing` | Spawn fix sub-agent |
| `complete` | Output success message |
| `blocked` | Output blocked message |
| `needs_input` | Output question |

### 3. Implementation (status: pending → implementing)

Update state: `phase_status = "implementing"`

Spawn sub-agent with Task tool:

```
subagent_type: "senior-software-engineer"
prompt: |
  You are implementing Phase {current_phase} of a plan.

  Plan path: {plan_path}
  Phase: {current_phase} of {total_phases}

  {IF custom_context}
  **IMPORTANT CONTEXT**: {custom_context}
  {ENDIF}

  Instructions:
  1. Read the plan document at {plan_path}
  2. Find Phase {current_phase} section
  3. Implement ONLY what's described in that phase
  4. Run verification commands from "Automated Verification" section
  5. Mark checkboxes `- [x]` for tests you run successfully
  6. Leave unchecked if you skip slow tests
  7. Do NOT proceed to other phases

  Return:
  - SUCCESS: {summary} + which verifications you ran
  - FAILURE: {what went wrong}
```

After sub-agent returns, update state: `phase_status = "verifying"`

### 4. Verification (status: verifying)

Re-read the plan file. Find "Automated Verification" section for current phase.
For each unchecked item `- [ ]`:
1. Extract the command after the colon
2. Run it
3. If passes: mark `- [x]` in plan file
4. If fails: record error, increment retry_count

If all pass: update state `phase_status = "reviewing"`
If any fail and `retry_count <= max_retries`: update state `phase_status = "fixing"`, store error in `last_error`
If any fail and `retry_count > max_retries`: update state `phase_status = "blocked"`

### 5. Code Review (status: reviewing)

Spawn sub-agent:

```
subagent_type: "code-reviewe"
prompt: |
  You are reviewing code changes for Phase {current_phase}.

  {IF custom_context}
  **IMPORTANT CONTEXT**: {custom_context}
  {ENDIF}

  Run: git diff HEAD~1 (or git diff if not committed)

  Focus ONLY on blockers:
  - Security vulnerabilities
  - Critical logic bugs
  - Missing tests for new logic
  - Breaking API changes (unless context allows breaking changes)

  Return:
  - APPROVED: {brief summary}
  - BLOCKERS: {list of issues}
```

If APPROVED: proceed to commit
If BLOCKERS and `retry_count <= max_retries`: `phase_status = "fixing"`, store blockers
If BLOCKERS and `retry_count > max_retries`: `phase_status = "blocked"`

### 6. Fix (status: fixing)

Spawn sub-agent:

```
subagent_type: "senior-software-engineer"
prompt: |
  You are fixing issues in Phase {current_phase}.

  {IF custom_context}
  **IMPORTANT CONTEXT**: {custom_context}
  {ENDIF}

  Issues to fix:
  {last_error or blocker list}

  Instructions:
  1. Fix ONLY the listed issues
  2. Run the failing verification(s)
  3. Mark checkbox if now passing

  Return:
  - FIXED: {summary}
  - UNABLE: {what couldn't be fixed}
```

If FIXED: `phase_status = "verifying"` (re-run verification)
If UNABLE: `phase_status = "blocked"`

### 7. Commit and Advance

After review approved:

```bash
git add -A
git commit -m "Phase {current_phase}: {phase_description}"
```

Update state:
- Add phase number to `completed_phases`
- Add commit hash to `commits`
- Reset `retry_count = 0`
- `current_phase += 1`
- If `current_phase > total_phases`: `phase_status = "complete"`
- Else: `phase_status = "pending"`

### 8. Terminal States

**Complete:**
```
✅ All phases complete!

Completed:
{list of phases with commit hashes}

Ready to push and create PR.

ORCHESTRATION_STOPPED
```

**Blocked:**
```
⛔ Phase {N} blocked after {max_retries} attempts.

Error: {last_error}

To resume after fixing:
/setup_orchestrate {plan_path} --start-phase {N}

ORCHESTRATION_STOPPED
```

**Needs Input:**
```
🤚 Phase {N} needs your input.

Question: {question}

After deciding, run:
/setup_orchestrate {plan_path} --start-phase {N}

ORCHESTRATION_STOPPED
```
```

### Success Criteria

#### Automated Verification

- [ ] Command file exists at `claude/.claude/commands/orchestrate_plan.md`

#### Manual Verification

- [ ] Command reads state file correctly
- [ ] Sub-agents receive custom_context in prompts
- [ ] State transitions work correctly
- [ ] Outputs `ORCHESTRATION_STOPPED` on terminal states
- [ ] Commits created after successful phases

---

## Phase 3: Integration Testing

### Overview

Test the complete workflow with a simple test plan.

### Test Plan

Create temporary test plan with 2 simple phases, run setup with `--context`, verify state, run orchestrate manually once, verify sub-agent received context.

### Success Criteria

#### Manual Verification

- [ ] `/setup_orchestrate test-plan.md --context "test"` creates state with context
- [ ] `/orchestrate_plan` spawns sub-agent with context in prompt
- [ ] Ralph-loop integration works end-to-end
- [ ] Clean up test artifacts

---

## Testing Strategy

### Manual Testing Steps

1. Create simple 2-phase test plan
2. Run `/setup_orchestrate test-plan.md --context "this is a test"`
3. Verify `.claude/orchestrator-state.json` contains `custom_context`
4. Run `/orchestrate_plan` once manually
5. Verify sub-agent prompt includes the context
6. Run full ralph-loop to test automation

## References

- Research: `thoughts/research/2026-01-01-orchestrator-subagent-workflow.md`
- Ralph-loop: https://awesomeclaude.ai/ralph-wiggum
- Existing implement_plan: `claude/.claude/commands/implement_plan.md`
- Senior engineer agent: `claude/.claude/agents/senior-software-engineer.md`
- Code review: `claude/.claude/commands/code-reviewe.md`
