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

- Formula: (total_phases - start_phase + 1) * (max_retries + 2) * 2
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
