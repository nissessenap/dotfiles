---
description: Execute plan phases with sub-agents (called by ralph-loop)
model: opus
---

# Orchestrate Plan Implementation

Thin orchestrator that executes plan phases using sub-agents for context isolation.
Called repeatedly by ralph-loop until it outputs `ORCHESTRATION_STOPPED`.

## Available Specialized Agents

Choose agents based on what the phase requires:

| Agent | Use When |
|-------|----------|
| `golang-pro` | Go code, Go modules, Go testing |
| `typescript-expert` | TypeScript/JavaScript, Node.js, frontend |
| `python-pro` | Python code, pip, pytest, data processing |
| `sql-expert` | Database queries, migrations, schema design |
| `playwright-expert` | E2E tests, browser automation |

**Multi-agent approach encouraged**: For phases involving multiple domains (e.g., API + database), spawn multiple agents in parallel for better results for code-reviews.

## Orchestrator Log

All sub-agents MUST write to `.claude/orchestrator-log.md` to provide visibility into their reasoning and decisions. This file is NOT committed to git (add to .gitignore).

### Log Format

```markdown
## Phase {N} ({YYYY-MM-DD HH:MM})

### [{agent-type}] {Action}
{content}

---
```

### Logging Requirements by Agent

| Agent | When to Log | Verbosity |
|-------|-------------|-----------|
| Implementation agents | Key decisions, deviations from plan, reused code | Brief |
| `code-reviewe` | **ALWAYS** - even if no issues found | Verbose |
| Fix agents | What was fixed and how | Brief |

### Code Review Log Structure (Required)

The code-review agent must ALWAYS append a log entry with this structure:

```markdown
### [code-reviewe] Review
**Result:** {APPROVED | NEEDS_REVISION}

**Files reviewed:**
- {file1} ({lines changed})
- {file2} ({lines changed})

**Analysis:**
{Detailed reasoning about what was examined and why}

**Blockers found:**
- {issue}: {why it's a blocker, what could go wrong}

**High priority findings:**
- {issue}: {reasoning}

**Observations (not blocking):**
- {things noticed but not flagged, edge cases considered}

**What looked good:**
- {positive observations about the implementation}
```

## Workflow

### 1. Read State
Read `.claude/orchestrator-state.json` to determine current status.

If state file doesn't exist:
```
<promise>ORCHESTRATION_STOPPED</promise>

No orchestration state found.

Run /setup_orchestrate <plan-path> first to initialize.
```

### 2. Read Plan
Read the plan document from `state.plan_path`.

### 2.5 Check for Context
If `state.context` is set, include it in ALL sub-agent prompts as a "Project Context" section. This guidance affects how agents approach the implementation.

### 3. Determine Action

Based on `state.phase_status`:

- **"pending"**: Start implementing current phase
- **"implementing"**: Check if implementation succeeded, run verification
- **"verifying"**: Run remaining verification, then code review
- **"reviewing"**: Process review, let implementer respond
- **"responding"**: Check implementer's response to review
- **"fixing"**: Check fix results, re-verify

### 4. Execute Current Phase

#### 4.1 Implementation (phase_status: "pending")

**First, analyze the phase to select appropriate agents:**

Read the phase content and determine:
- What languages/technologies are involved?
- What domains does it touch (DB, API, frontend, tests)?
- Would multiple perspectives help?

**Then spawn implementation agent(s):**

Update state to `"implementing"`, then spawn sub-agent(s):

```
Use Task tool with:
- subagent_type: {selected agent based on phase content}
- prompt: |
    You are implementing Phase {N} of a plan.

    Plan path: {plan_path}
    Phase: {N} of {total}

    {IF state.context is set}
    ## Project Context
    {state.context}
    {END IF}

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

    Logging:
    Append a brief log entry to `.claude/orchestrator-log.md`:
    ```
    ### [{your-agent-type}] Implementation
    - {key decisions made}
    - {any deviations from plan and why}
    - {existing code/patterns you reused}
    ```

    Return format:
    - SUCCESS: {summary of changes}
    - FAILURE: {what went wrong}
```

**Example agent selection:**
- Phase touches Go API code → `golang-pro`
- Phase adds database migration → `sql-expert` + `golang-pro` (parallel)
- Phase adds E2E tests → `playwright-expert`
- Phase involves Python code → `python-pro`
- Phase touches TypeScript frontend → `typescript-expert`

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

    {IF state.context is set}
    ## Project Context
    {state.context}
    {END IF}

    Run: git diff HEAD~1 (or git diff if not committed)

    Provide feedback on ALL severity levels:

    Level 1 - Blockers (must fix):
    - Security vulnerabilities
    - Critical logic bugs
    - Missing tests for new logic
    - Breaking API changes

    Level 2 - High Priority (strongly recommend):
    - Architectural violations (SRP, DRY, leaky abstractions)
    - Serious performance issues (N+1 queries, hot path inefficiency)
    - Poor error handling

    Level 3 - Medium Priority (consider):
    - Clarity and readability improvements
    - Naming suggestions
    - Documentation gaps

    IMPORTANT - Logging:
    You MUST append a detailed log entry to `.claude/orchestrator-log.md`.
    This log is critical for debugging and understanding your reasoning.

    Log format (append to file):
    ```
    ### [code-reviewe] Review
    **Result:** {APPROVED | NEEDS_REVISION}

    **Files reviewed:**
    - {file1} ({lines changed})
    - {file2} ({lines changed})

    **Analysis:**
    {Explain what you examined, your reasoning process, and why you
    focused on certain areas. Be thorough - this helps debug issues.}

    **Blockers found:**
    - {issue}: {why it's a blocker, what could go wrong if not fixed}

    **High priority findings:**
    - {issue}: {your reasoning for flagging this}

    **Observations (not blocking):**
    - {things you noticed but chose not to flag}
    - {edge cases you considered}
    - {patterns you recognized}

    **What looked good:**
    - {positive observations about the implementation}
    - {good practices you noticed}
    ```

    Even if you find NO issues, you must still log:
    - What files you reviewed
    - What you checked for
    - Why the code passed review

    Return format:
    VERDICT: [APPROVED | NEEDS_REVISION]

    BLOCKERS:
    - {issue 1}
    - {issue 2}

    HIGH_PRIORITY:
    - {issue 1}

    MEDIUM_PRIORITY:
    - {suggestion 1}

    GOOD_PRACTICES:
    - {what was done well}
```

After review:
- If APPROVED with no blockers: Update state to `"responding"` with review results
- If NEEDS_REVISION: Update state to `"responding"` with review results

#### 4.4 Implementer Response (phase_status: "responding")

Give the implementation agent a chance to respond to the review:

```
Use Task tool with:
- subagent_type: {same agent(s) that implemented the phase}
- prompt: |
    A code review was performed on your Phase {N} implementation.

    {IF state.context is set}
    ## Project Context
    {state.context}
    {END IF}

    Review findings:
    {review results from previous step}

    For each issue raised, you must either:
    1. AGREE and fix it
    2. DISAGREE and explain why (with technical justification)

    You may disagree if:
    - The reviewer misunderstood the context
    - The suggestion would introduce other problems
    - The "issue" is intentional for valid reasons
    - The fix is out of scope for this phase

    Be honest - if the reviewer is right, fix it. If you have good reasons to disagree, explain them clearly.

    Logging:
    Append a log entry to `.claude/orchestrator-log.md`:
    ```
    ### [{your-agent-type}] Response to Review
    - {issue}: {FIXED | DISAGREE: brief reason}
    - {any interesting context about your decisions}
    ```

    Return format:
    RESPONSE:

    BLOCKERS:
    - {issue}: [FIXED | DISAGREE: {reason}]

    HIGH_PRIORITY:
    - {issue}: [FIXED | DISAGREE: {reason}]

    MEDIUM_PRIORITY:
    - {suggestion}: [FIXED | SKIPPED: {reason}]

    SUMMARY:
    - Fixed: {count}
    - Disagreed (with justification): {count}
    - Skipped (medium priority): {count}
```

After response:
- If all blockers are FIXED or have valid DISAGREE justification: Commit and advance
- If blockers remain unfixed without justification: INCREMENT retry_count, go to fixing
- If retry_count > max_retries: EXIT blocked

#### 4.5 Commit and Advance

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

#### 4.6 Fix Attempts (phase_status: "fixing")

Spawn fix sub-agent (use same specialized agent as implementation):

```
Use Task tool with:
- subagent_type: {same agent(s) that implemented the phase}
- prompt: |
    You are fixing issues found in Phase {N}.

    Plan path: {plan_path}

    {IF state.context is set}
    ## Project Context
    {state.context}
    {END IF}

    Issues to fix:
    {last_error or unresolved review blockers}

    Instructions:
    1. Read the relevant files
    2. Fix ONLY the listed issues
    3. Do not refactor or improve other code
    4. Run failing verification commands after fixing
    5. Mark checkboxes [x] for now-passing verifications

    Logging:
    Append a log entry to `.claude/orchestrator-log.md`:
    ```
    ### [{your-agent-type}] Fix Attempt
    - {issue fixed}: {how you fixed it}
    - {any complications or decisions made}
    ```

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

All phases complete!

Completed phases:
1. Phase 1: {description} (commit: abc123)
2. Phase 2: {description} (commit: def456)
...

Ready for you to push and create PR.
```

#### Blocked Exit

```
<promise>ORCHESTRATION_STOPPED</promise>

Phase {N} blocked after {max_retries} attempts.

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

Phase {N} needs your input.

Question: {what's unclear}

Options:
1. {option 1}
2. {option 2}

After deciding, update the plan and run:
/setup_orchestrate {path} --start-phase {N}
```

## State Machine

```
pending -> implementing -> verifying -> reviewing -> responding -> [commit] -> pending (next phase)
                |              |           |             |
              fixing <-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<
                |
        (if retries exhausted)
                |
            STOPPED
```

## Important Notes

- Each ralph-loop iteration = one state transition
- Sub-agents get fresh context (no accumulated confusion)
- State file is the source of truth for progress
- Checkboxes in plan track what verification was run
- Always update state BEFORE spawning sub-agents
- Use the same specialized agent(s) for implementation, response, and fixing
- Multi-agent parallel execution is encouraged for cross-domain phases
- Implementer can disagree with reviewer - requires clear technical justification
- If `state.context` is set, include it in every sub-agent prompt - it guides how agents approach the work (e.g., "greenfield project, breaking changes OK")
- All sub-agents log to `.claude/orchestrator-log.md` - review this file to understand agent reasoning
- Code-review logs are always verbose; implementation/fix logs are brief
