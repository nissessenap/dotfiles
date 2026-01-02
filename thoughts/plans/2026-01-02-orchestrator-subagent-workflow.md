# Orchestrator + Sub-agents Workflow Implementation Plan

## Overview

Implement an automated plan execution system that uses ralph-loop to keep an orchestrator running, which delegates implementation and review work to sub-agents with isolated contexts. This enables executing 7+ phase plans automatically while maintaining fresh context per phase.

Based on research: `thoughts/research/2026-01-01-orchestrator-subagent-workflow.md`

## Current State Analysis

- **Existing commands**: `implement_plan.md` (manual, single-context), `code-reviewe.md` (review criteria)
- **Existing agents**: `senior-software-engineer.md`, various specialized agents
- **Missing**: No ralph-loop infrastructure, no orchestration commands, no stop hooks

### Key Discoveries

- Commands use YAML frontmatter with `description`, optional `model`, `argument-hint`
- Agents use YAML frontmatter with `name`, `description`, `model`
- No existing hook infrastructure in `claude/.claude/`

## Desired End State

After implementation:

1. User runs `/setup_orchestrate thoughts/plans/feature.md --context "greenfield, breaking changes OK"`
2. System creates state file and displays ralph-loop command
3. User runs the ralph-loop command
4. Orchestrator automatically executes phases using sub-agents
5. Each sub-agent receives the custom context in their prompt
6. System commits after each phase, stops on completion/error/need-input

### Verification

- Run `/setup_orchestrate` on a test plan and verify output format
- Verify state file is created with correct structure including context
- Verify sub-agents receive the custom context in prompts

## What We're NOT Doing

- Parallel phase execution (future enhancement)
- Preset context flags (`--greenfield`, `--breaking`) - only `--context`
- MCP workflow server integration
- Claude Agent SDK integration
- Git worktree support

## Implementation Approach

Create two commands and a stop hook script:

1. `/setup_orchestrate` - Prepares state and shows ralph-loop command
2. `/orchestrate_plan` - The orchestrator that coordinates sub-agents
3. Stop hook script - Keeps Claude running until completion promise

## Phase 1: Setup Orchestrate Command

### Overview

Create the setup command that validates a plan, creates state, and outputs the ralph-loop command for user verification.

### Changes Required

#### 1. Setup Orchestrate Command

**File**: `claude/.claude/commands/setup_orchestrate.md`

```markdown
---
description: Setup orchestration for a plan (generates ralph-loop command)
argument-hint: "<path-to-plan.md> [--context \"custom context\"] [--max-retries N] [--start-phase N]"
---

# Setup Orchestration

Prepares orchestration for a plan and outputs the ralph-loop command for verification.

## Arguments
- `plan_path` (required): Path to the implementation plan
- `--context "..."`: Custom context injected into all sub-agent prompts
- `--max-retries N`: Max fix attempts per phase (default: 3)
- `--start-phase N`: Start from specific phase (default: 1, or resume from state)

## Workflow

1. **Parse arguments** from $ARGUMENTS
2. **Read and validate the plan document**
   - Verify file exists
   - Count phases (sections starting with `## Phase N:`)
   - Extract phase names
3. **Create/update state file**: `.claude/orchestrator-state.json`
4. **Output the ralph-loop command** for user to verify and run

## State File Structure

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
  "last_error": null,
  "custom_context": "<context string or null>"
}
```

## Output Format

After creating state file, output EXACTLY this format:

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

To start automated execution, run:
────────────────────────────────────────────────────────────
claude --resume "{session_id}" "/orchestrate_plan {plan_path}"
────────────────────────────────────────────────────────────

The stop hook at claude/.claude/hooks/stop-orchestrator.sh will keep
Claude running until all phases complete or an error requires human input.

⚠️  Review the above command before running.
```

## Implementation Notes

- Parse $ARGUMENTS to extract plan_path, --context, --max-retries, --start-phase
- Use Read tool to read the plan file
- Count phases by matching `## Phase \d+:` pattern
- Write state file using Write tool
- The stop hook handles the loop logic (not ralph-loop command)

```

### Success Criteria:

#### Automated Verification:
- [ ] Command file exists at `claude/.claude/commands/setup_orchestrate.md`
- [ ] Running `/setup_orchestrate` with a valid plan creates state file
- [ ] State file contains all required fields including `custom_context`

#### Manual Verification:
- [ ] Output format is clear and readable
- [ ] Phase detection correctly identifies all phases in plan
- [ ] `--context` argument is correctly stored in state file

---

## Phase 2: Stop Hook Script

### Overview
Create the stop hook that intercepts Claude exit and re-prompts with orchestrate_plan until completion.

### Changes Required:

#### 1. Stop Hook Script
**File**: `claude/.claude/hooks/stop-orchestrator.sh`

```bash
#!/bin/bash
# Stop hook for orchestrator - keeps Claude running until completion
#
# This hook:
# 1. Checks if orchestration is active (state file exists with active status)
# 2. If active, blocks exit and re-injects the orchestrate prompt
# 3. If complete/error/needs-input, allows exit

STATE_FILE=".claude/orchestrator-state.json"

# Check if state file exists
if [ ! -f "$STATE_FILE" ]; then
    exit 0  # Allow exit - no orchestration active
fi

# Read state using jq
PHASE_STATUS=$(jq -r '.phase_status' "$STATE_FILE" 2>/dev/null)

# Check if orchestration should continue
case "$PHASE_STATUS" in
    "pending"|"implementing"|"reviewing"|"fixing")
        # Orchestration in progress - block exit and re-prompt
        PLAN_PATH=$(jq -r '.plan_path' "$STATE_FILE")
        CURRENT_PHASE=$(jq -r '.current_phase' "$STATE_FILE")

        # Output to stderr (shown to Claude)
        echo "Orchestration in progress (Phase $CURRENT_PHASE). Continuing..." >&2
        echo "" >&2
        echo "Continue executing: /orchestrate_plan $PLAN_PATH" >&2

        # Block exit
        exit 2
        ;;
    "complete"|"blocked"|"needs_input")
        # Orchestration finished - allow exit
        exit 0
        ;;
    *)
        # Unknown status - allow exit
        exit 0
        ;;
esac
```

#### 2. Hook Configuration

**File**: `claude/.claude/settings.json` (create if not exists)

```json
{
  "hooks": {
    "stop": [
      {
        "command": "bash claude/.claude/hooks/stop-orchestrator.sh",
        "timeout": 5000
      }
    ]
  }
}
```

### Success Criteria

#### Automated Verification

- [ ] Hook script exists at `claude/.claude/hooks/stop-orchestrator.sh`
- [ ] Hook script is executable: `chmod +x claude/.claude/hooks/stop-orchestrator.sh`
- [ ] Settings file exists with hook configuration

#### Manual Verification

- [ ] Hook correctly blocks exit when state is "implementing"
- [ ] Hook allows exit when state is "complete"
- [ ] Hook output is shown to Claude (via stderr)

---

## Phase 3: Orchestrate Plan Command

### Overview

Create the main orchestrator command that coordinates sub-agents for plan execution.

### Changes Required

#### 1. Orchestrate Plan Command

**File**: `claude/.claude/commands/orchestrate_plan.md`

```markdown
---
description: Execute plan phases with sub-agents (works with stop hook for automation)
argument-hint: "<path-to-plan.md>"
---

# Orchestrate Plan Implementation

Executes plan phases using sub-agents for context isolation. The stop hook keeps this running automatically.

## Overview

This command is designed to be called repeatedly by the stop hook until all phases complete. Each invocation:
1. Reads state to determine current phase
2. Spawns sub-agent for implementation
3. Runs verification (only unchecked items)
4. Spawns sub-agent for code review
5. Commits on success, updates state
6. Exits (stop hook re-invokes if more phases remain)

## Workflow

### 1. Initialize

Read state file: `.claude/orchestrator-state.json`
Read plan document from state's `plan_path`

If no state file exists:
```

⛔ No orchestration state found.
Run /setup_orchestrate <plan-path> first.

```
Exit normally (stop hook won't block).

### 2. Check Current State

Based on `phase_status`:
- `"pending"` → Start implementation of `current_phase`
- `"implementing"` → Continue/retry implementation
- `"reviewing"` → Continue code review
- `"fixing"` → Spawn fix sub-agent
- `"complete"` → Output success and exit
- `"blocked"` → Output blocked status and exit
- `"needs_input"` → Output question and exit

### 3. Implementation Sub-agent

Update state: `phase_status = "implementing"`

Build sub-agent prompt including custom context:

```

You are implementing Phase {N} of a plan.

Plan path: {plan_path}
Phase: {N} of {total}
{IF custom_context}
IMPORTANT CONTEXT: {custom_context}
{ENDIF}

Instructions:

1. Read the plan document completely
2. Find the section for Phase {N}
3. Implement ONLY what's described in that phase
4. Run verification commands from the "Automated Verification" section
5. Mark checkboxes in the plan file for tests you run successfully:
   - Change `- [ ]` to `- [x]` for each passing verification
   - Leave unchecked if you skip a test (e.g., slow e2e tests)
6. Do not proceed to other phases
7. When done, summarize what you implemented

Return format:

- SUCCESS: {summary of changes}
  - Verified: {list of checkboxes you marked}
  - Skipped: {list of verifications left unchecked, if any}
- FAILURE: {what went wrong}

```

Spawn using Task tool with `subagent_type: "senior-software-engineer"`

### 4. Verification (Orchestrator Runs Unchecked Items)

After sub-agent returns:
1. Re-read the plan file to see which checkboxes are marked
2. Find items in "Automated Verification" that are still `- [ ]`
3. Run each unchecked command
4. If passes, mark checkbox `- [x]` in plan file
5. If any fails:
   - Increment `retry_count`
   - If `retry_count <= max_retries`: set `phase_status = "fixing"`, exit
   - If `retry_count > max_retries`: set `phase_status = "blocked"`, exit

### 5. Code Review Sub-agent

Update state: `phase_status = "reviewing"`

Build sub-agent prompt:

```

You are reviewing code changes for Phase {N}.
{IF custom_context}
IMPORTANT CONTEXT: {custom_context}
{ENDIF}

Review the diff: `git diff HEAD~1` (or unstaged if not committed yet)

Focus ONLY on blockers:

- Security vulnerabilities
- Critical logic bugs
- Missing tests for new logic
- Breaking API changes (unless context says breaking changes OK)

Return format:

- APPROVED: {brief summary}
- BLOCKERS: {list of blocking issues}

```

Spawn using Task tool with `subagent_type: "code-reviewe"`

If blockers found:
- Increment `retry_count`
- If `retry_count <= max_retries`: set `phase_status = "fixing"`, exit
- If `retry_count > max_retries`: set `phase_status = "blocked"`, exit

### 6. Fix Sub-agent (if needed)

When `phase_status = "fixing"`:

```

You are fixing issues found in Phase {N}.
{IF custom_context}
IMPORTANT CONTEXT: {custom_context}
{ENDIF}

Plan path: {plan_path}
Issues to fix:
{list of issues from verification/review}

Instructions:

1. Read the relevant files
2. Fix ONLY the listed issues
3. Run the failing verification command(s) after fixing
4. If tests pass, mark the checkbox in the plan file

Return format:

- FIXED: {summary of fixes}
- UNABLE: {what couldn't be fixed and why}

```

After fix sub-agent returns:
- If FIXED: go back to verification step
- If UNABLE: set `phase_status = "blocked"`, exit

### 7. Commit and Proceed

If all verification passed and review approved:
1. Run: `git add -A && git commit -m "Phase {N}: {phase_description}"`
2. Update state:
   - Add phase to `completed_phases`
   - Add commit info to `commits`
   - Reset `retry_count = 0`
   - Increment `current_phase`
   - If `current_phase > total_phases`: set `phase_status = "complete"`
   - Else: set `phase_status = "pending"`
3. Exit (stop hook re-invokes for next phase)

### 8. Exit Outputs

**Success (all phases complete):**
```

✅ All phases complete!

Completed phases:

1. Phase 1: {description} (commit: abc123)
2. Phase 2: {description} (commit: def456)
...

Ready for you to push and create PR.

ORCHESTRATION_COMPLETE

```
Update state: `phase_status = "complete"`

**Blocked (retries exhausted):**
```

⛔ Phase {N} blocked after {max_retries} attempts.

Last error:
{error details}

Attempted fixes:

1. {first attempt summary}
2. {second attempt summary}
...

To resume after fixing manually:

1. Fix the issue
2. Run: /setup_orchestrate {path} --start-phase {N}

ORCHESTRATION_BLOCKED

```
Update state: `phase_status = "blocked"`

**Needs Human Input:**
```

🤚 Phase {N} needs your input.

Question: {what the orchestrator is unsure about}

After deciding:

1. Update the plan or answer the question
2. Run: /setup_orchestrate {path} --start-phase {N}

ORCHESTRATION_NEEDS_INPUT

```
Update state: `phase_status = "needs_input"`

## State Transitions

```

pending → implementing → reviewing → (commit) → pending (next phase)
                ↓              ↓
             fixing ←──────────┘
                ↓
            blocked (if retries exhausted)

```
```

### Success Criteria

#### Automated Verification

- [ ] Command file exists at `claude/.claude/commands/orchestrate_plan.md`
- [ ] Syntax is valid markdown with correct frontmatter

#### Manual Verification

- [ ] Command correctly reads state file
- [ ] Sub-agents receive custom context in prompts
- [ ] State transitions work correctly
- [ ] Commits are created after successful phases
- [ ] Stop hook integration works (re-invokes on exit)

---

## Phase 4: Integration Testing

### Overview

Test the complete workflow end-to-end with a simple test plan.

### Changes Required

#### 1. Create Test Plan

**File**: `thoughts/plans/2026-01-02-test-orchestrator.md` (temporary)

```markdown
# Test Orchestrator - Simple Two-Phase Plan

## Overview
A minimal plan to test the orchestrator workflow.

## Phase 1: Create Test File

### Changes Required:
Create a file `test-orchestrator-output.txt` with content "Phase 1 complete"

### Success Criteria:

#### Automated Verification:
- [ ] File exists: `test -f test-orchestrator-output.txt`
- [ ] Content correct: `grep -q "Phase 1" test-orchestrator-output.txt`

---

## Phase 2: Update Test File

### Changes Required:
Append "Phase 2 complete" to `test-orchestrator-output.txt`

### Success Criteria:

#### Automated Verification:
- [ ] Content includes Phase 2: `grep -q "Phase 2" test-orchestrator-output.txt`
```

### Test Steps

1. Run `/setup_orchestrate thoughts/plans/2026-01-02-test-orchestrator.md --context "test context"`
2. Verify state file created with `custom_context: "test context"`
3. Run the orchestrate command manually once
4. Verify sub-agent received context
5. Clean up test files

### Success Criteria

#### Automated Verification

- [ ] State file created correctly
- [ ] Test plan phases detected correctly

#### Manual Verification

- [ ] Full workflow executes correctly
- [ ] Custom context appears in sub-agent prompts
- [ ] State transitions happen correctly
- [ ] Clean up test artifacts after testing

---

## Testing Strategy

### Unit Tests

- N/A (markdown command files don't have unit tests)

### Integration Tests

- Test `/setup_orchestrate` argument parsing
- Test state file creation
- Test `/orchestrate_plan` state reading
- Test stop hook exit code behavior

### Manual Testing Steps

1. Create a simple 2-phase test plan
2. Run `/setup_orchestrate` with `--context`
3. Verify state file contents
4. Run `/orchestrate_plan` manually
5. Verify sub-agent prompt includes context
6. Verify phase completion and commit

## Performance Considerations

- Sub-agents have isolated contexts, preventing context bloat
- State file is small JSON, fast to read/write
- Stop hook has 5-second timeout to prevent hangs

## Migration Notes

N/A - New feature, no migration needed.

## References

- Original research: `thoughts/research/2026-01-01-orchestrator-subagent-workflow.md`
- Existing implement_plan: `claude/.claude/commands/implement_plan.md`
- Senior engineer agent: `claude/.claude/agents/senior-software-engineer.md`
- Code review command: `claude/.claude/commands/code-reviewe.md`
