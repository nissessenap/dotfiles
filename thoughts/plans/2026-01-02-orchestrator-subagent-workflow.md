# Orchestrator + Sub-agents Workflow Implementation Plan

## Overview

Implement two Claude Code skills that enable automated plan execution using the ralph-loop:

1. **`/setup_orchestrate`** - Prepares orchestration state and outputs the ralph-loop command
2. **`/orchestrate_plan`** - Thin orchestrator that executes phases using sub-agents (called by ralph-loop)

This enables hands-off execution of multi-phase implementation plans with fresh context per phase, automatic retries, and commits between phases.

## Current State Analysis

### Existing Infrastructure

- Ralph-loop plugin is installed and ready to use
- Existing agents available: `senior-software-engineer`, `code-reviewe`
- Existing `implement_plan.md` handles manual phase-by-phase execution
- Commands stored in `/home/edvin/projects/dotfiles/claude/.claude/commands/`
- Standard frontmatter format: `description`, `model`, `argument-hint`

### Key Discoveries

- `senior-software-engineer` agent (`claude/.claude/agents/senior-software-engineer.md:1-23`) - TDD-first, small commits, clean boundaries
- `code-reviewe` agent (`claude/.claude/commands/code-reviewe.md:1-86`) - Reviews for blockers only at Level 1
- Command format uses `---` delimiters with YAML frontmatter

## Desired End State

After implementation:

1. User runs `/setup_orchestrate thoughts/plans/my-plan.md`
2. Skill creates state file and outputs verified ralph-loop command
3. User reviews and runs the ralph-loop command
4. Orchestrator executes all phases automatically:
   - Sub-agent implements each phase
   - Verification commands run (if present in plan)
   - Code review sub-agent checks for blockers
   - Commits after each phase
   - Retries on failure (max 3)
5. Loop exits with `ORCHESTRATION_STOPPED` and context explaining outcome

### Verification of Success

- `/setup_orchestrate` creates valid state file at `.claude/orchestrator-state.json`
- `/orchestrate_plan` can be called by ralph-loop and processes phases
- Sub-agents spawn with isolated context
- Checkbox-based verification works (sub-agents mark what they verified)
- Commits happen between phases
- Exits cleanly with appropriate context (success/blocked/needs-input)

## What We're NOT Doing

- Parallel phase execution (sequential only)
- Custom hooks (ralph-loop handles the outer loop)
- Manual verification step handling (skip them)
- New agent definitions (use existing `senior-software-engineer` and `code-reviewe`)

## Implementation Approach

Create two skill files that work together:

1. Setup skill parses the plan and prepares state
2. Orchestrator skill is called repeatedly by ralph-loop until it outputs the completion promise

The orchestrator stays thin - it reads state, determines what to do, spawns a sub-agent, processes the result, updates state, and either continues or exits.

---

## Phase 1: Create Setup Orchestrate Skill

### Overview

Create `/setup_orchestrate` skill that validates a plan, creates state file, and outputs the ralph-loop command.

### Changes Required

#### 1. Create setup_orchestrate.md

**File**: `claude/.claude/commands/setup_orchestrate.md`

```markdown
---
description: Setup orchestration for a plan (generates ralph-loop command)
argument-hint: "<path-to-plan.md> [--max-retries N] [--start-phase N]"
model: opus
---

# Setup Orchestration

Prepares orchestration for an implementation plan and outputs the ralph-loop command for verification.

## Arguments
- `plan_path` (required): Path to the implementation plan
- `--max-retries N`: Max fix attempts per phase (default: 3)
- `--start-phase N`: Start from specific phase (default: 1, or resume from state)

## Workflow

### 1. Validate Plan
- Read the plan document completely
- Verify it has numbered phases (look for `## Phase N:` headers)
- Count total phases
- Extract phase names/descriptions

### 2. Parse Arguments
Parse the provided arguments:
- Extract plan_path (first positional argument)
- Extract --max-retries if provided (default: 3)
- Extract --start-phase if provided (default: 1)

### 3. Check for Existing State
Check if `.claude/orchestrator-state.json` exists:
- If exists and matches this plan, offer to resume
- If exists for different plan, warn and confirm overwrite
- If not exists, create new

### 4. Create/Update State File
Create `.claude/orchestrator-state.json`:
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
  "last_error": null
}
```

### 5. Calculate Max Iterations

- Formula: (total_phases - start_phase + 1) *(max_retries + 2)* 2
- This accounts for: phases × (retries + impl + review) × safety margin

### 6. Output Results

Output this exact format:

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
/ralph-loop "/orchestrate_plan" --max-iterations {calculated} --completion-promise "ORCHESTRATION_STOPPED"
────────────────────────────────────────────────────────────

⚠️  Review the above command before running.
    The loop will run until completion, error, or max iterations.
```

## Error Handling

If plan cannot be parsed:

```
❌ Could not parse plan: {plan_path}

Issue: {what went wrong}

Expected format:
- Plan should have phases marked as "## Phase N: Description"
- Each phase should have clear implementation steps
```

```

### Success Criteria:

#### Automated Verification:
- [x] File exists: `claude/.claude/commands/setup_orchestrate.md`
- [x] File has valid YAML frontmatter with description
- [x] Can be invoked: Test with a sample plan file

#### Manual Verification:
- [x] Running `/setup_orchestrate` on a valid plan creates state file
- [x] Output shows correct phase count and ralph-loop command

---

## Phase 2: Create Orchestrate Plan Skill

### Overview
Create `/orchestrate_plan` skill - the thin orchestrator that ralph-loop calls repeatedly.

### Changes Required:

#### 1. Create orchestrate_plan.md
**File**: `claude/.claude/commands/orchestrate_plan.md`

```markdown
---
description: Execute plan phases with sub-agents (called by ralph-loop)
model: opus
---

# Orchestrate Plan Implementation

Thin orchestrator that executes plan phases using sub-agents for context isolation.
Called repeatedly by ralph-loop until it outputs `ORCHESTRATION_STOPPED`.

## Workflow

### 1. Read State
Read `.claude/orchestrator-state.json` to determine current status.

If state file doesn't exist:
```

<promise>ORCHESTRATION_STOPPED</promise>

❌ No orchestration state found.

Run /setup_orchestrate <plan-path> first to initialize.

```

### 2. Read Plan
Read the plan document from `state.plan_path`.

### 3. Determine Action

Based on `state.phase_status`:

- **"pending"**: Start implementing current phase
- **"implementing"**: Check if implementation succeeded, run verification
- **"verifying"**: Run remaining verification, then code review
- **"reviewing"**: Check review results, commit or retry
- **"fixing"**: Check fix results, re-verify

### 4. Execute Current Phase

#### 4.1 Implementation (phase_status: "pending")

Update state to `"implementing"`, then spawn sub-agent:

```

Use Task tool with:

- subagent_type: "senior-software-engineer"
- prompt: |
    You are implementing Phase {N} of a plan.

    Plan path: {plan_path}
    Phase: {N} of {total}

    Instructions:
    1. Read the plan document completely
    2. Find the section for Phase {N}
    3. Implement ONLY what's described in that phase
    4. If the phase has an "Automated Verification" section with checkboxes:
       - Run those verification commands
       - Mark checkboxes [x] in the plan file for tests you run successfully
       - Leave unchecked if you skip a test
    5. Do not proceed to other phases
    6. When done, summarize what you implemented

    Return format:
  - SUCCESS: {summary of changes}
  - FAILURE: {what went wrong}

```

After sub-agent returns:
- If SUCCESS: Update state to `"verifying"`
- If FAILURE: Increment retry_count, spawn fix agent or escalate

#### 4.2 Verification (phase_status: "verifying")

Read the plan and check for unchecked verification items in current phase.

If unchecked items exist:
- Run each unchecked command
- Mark checkbox if passes
- If any fail: increment retry_count, update last_error, spawn fix agent or escalate

If all checked or no verification section:
- Update state to `"reviewing"`

#### 4.3 Code Review (phase_status: "reviewing")

Spawn review sub-agent:

```

Use Task tool with:

- subagent_type: "code-reviewe"
- prompt: |
    Review the code changes for Phase {N}.

    Run: git diff HEAD~1 (or git diff if not committed)

    Focus ONLY on blockers (Level 1):
  - Security vulnerabilities
  - Critical logic bugs
  - Missing tests for new logic
  - Breaking API changes

    Ignore style suggestions and minor improvements.

    Return format:
  - APPROVED: {brief summary}
  - BLOCKERS: {list of blocking issues}

```

After review:
- If APPROVED: Commit and advance phase
- If BLOCKERS and retry_count <= max_retries: spawn fix agent
- If BLOCKERS and retry_count > max_retries: EXIT blocked

#### 4.4 Commit and Advance

```bash
git add -A && git commit -m "Phase {N}: {phase_description}"
```

Update state:

- Add to completed_phases
- Add commit info to commits array
- Increment current_phase
- Reset retry_count to 0
- Set phase_status to "pending"

If current_phase > total_phases: EXIT success

#### 4.5 Fix Attempts (phase_status: "fixing")

Spawn fix sub-agent:

```
Use Task tool with:
- subagent_type: "senior-software-engineer"
- prompt: |
    You are fixing issues found in Phase {N}.

    Plan path: {plan_path}
    Issues to fix:
    {last_error or review blockers}

    Instructions:
    1. Read the relevant files
    2. Fix ONLY the listed issues
    3. Do not refactor or improve other code
    4. Run failing verification commands after fixing
    5. Mark checkboxes [x] for now-passing verifications

    Return format:
    - FIXED: {summary of fixes}
    - UNABLE: {what couldn't be fixed and why}
```

After fix:

- If FIXED: Update state to "verifying"
- If UNABLE: EXIT blocked

### 5. Exit Conditions

Always exit with `<promise>ORCHESTRATION_STOPPED</promise>` followed by context.

#### Success Exit

```
<promise>ORCHESTRATION_STOPPED</promise>

✅ All phases complete!

Completed phases:
1. Phase 1: {description} (commit: abc123)
2. Phase 2: {description} (commit: def456)
...

Ready for you to push and create PR.
```

#### Blocked Exit

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

#### Needs Input Exit

```
<promise>ORCHESTRATION_STOPPED</promise>

🤚 Phase {N} needs your input.

Question: {what's unclear}

Options:
1. {option 1}
2. {option 2}

After deciding, update the plan and run:
/setup_orchestrate {path} --start-phase {N}
```

## State Machine

```
pending → implementing → verifying → reviewing → [commit] → pending (next phase)
                ↓              ↓           ↓
              fixing ←←←←←←←←←←←←←←←←←←←←←
                ↓
        (if retries exhausted)
                ↓
            STOPPED
```

## Important Notes

- Each ralph-loop iteration = one state transition
- Sub-agents get fresh context (no accumulated confusion)
- State file is the source of truth for progress
- Checkboxes in plan track what verification was run
- Always update state BEFORE spawning sub-agents

```

### Success Criteria:

#### Automated Verification:
- [ ] File exists: `claude/.claude/commands/orchestrate_plan.md`
- [ ] File has valid YAML frontmatter with description

#### Manual Verification:
- [ ] Running `/orchestrate_plan` without state file exits cleanly
- [ ] Orchestrator spawns implementation sub-agent correctly
- [ ] State transitions work as documented

---

## Phase 3: End-to-End Testing

### Overview
Test the complete workflow with a simple test plan.

### Changes Required:

#### 1. Create Test Plan
**File**: `thoughts/plans/2026-01-02-test-orchestrator.md`

A minimal 2-phase test plan to verify the orchestrator works.

### Testing Steps:

1. Create a simple test plan with 2 phases
2. Run `/setup_orchestrate thoughts/plans/2026-01-02-test-orchestrator.md`
3. Verify state file created correctly
4. Run the output ralph-loop command
5. Observe phases executing
6. Verify commits created
7. Verify clean exit with success message

### Success Criteria:

#### Automated Verification:
- [ ] State file created correctly by setup skill
- [ ] Ralph-loop command runs without error

#### Manual Verification:
- [ ] Both phases execute automatically
- [ ] Sub-agents spawn with correct prompts
- [ ] Commits created between phases
- [ ] Clean exit with success message
- [ ] Can resume from interrupted state

---

## Testing Strategy

### Unit Tests
Not applicable - these are prompt-based skills, not code.

### Integration Tests
- Test setup skill creates valid state
- Test orchestrator reads state correctly
- Test sub-agent spawning works

### Manual Testing Steps
1. Create a test plan with known phases
2. Run setup, verify output
3. Run ralph-loop, observe execution
4. Interrupt mid-execution, verify can resume
5. Test failure handling by creating a plan with a failing verification

## Performance Considerations

- Opus model used for both skills (complex orchestration)
- Sub-agents keep context lean
- State file enables resume without re-reading everything

## References

- Research document: `thoughts/research/2026-01-01-orchestrator-subagent-workflow.md`
- Existing implement_plan: `claude/.claude/commands/implement_plan.md`
- Senior engineer agent: `claude/.claude/agents/senior-software-engineer.md`
- Code review agent: `claude/.claude/commands/code-reviewe.md`
