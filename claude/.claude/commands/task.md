-----
description: Create a comprehensive Github ticket from high-level input, automatically generating detailed context, acceptance criteria, and technical specifications using a core team of two specialist agents.
argument-hint: "<high-level description of work needed>"

## Mission

Transform high-level user input into a well-structured GitHub ticket with comprehensive details. This command uses a core team of two agents (`product-manager`, `senior-software-engineer`) to handle all feature planning and specification in parallel. It focuses on **pragmatic startup estimation** to ensure tickets are scoped for rapid, iterative delivery.

**Pragmatic Startup Philosophy**:

- 🚀 **Ship Fast**: Focus on working solutions over perfect implementations.
- 💡 **80/20 Rule**: Deliver 80% of the value with 20% of the effort.
- 🎯 **MVP First**: Define the simplest thing that could possibly work.

**Smart Ticket Scoping**: Automatically breaks down large work into smaller, shippable tickets if the estimated effort exceeds 2 days.

**Important**: This command ONLY creates the ticket(s). It does not start implementation or modify any code.

## Core Agent Workflow

For any feature request that isn't trivial (i.e., not LIGHT), this command follows a strict parallel execution rule using the core agent duo.

### The Core Duo (Always Run in Parallel)

- **`product-manager`**: Defines the "What." Focuses on user stories, and acceptance criteria.
- **`senior-software-engineer`**: Defines the "How" for the system. Focuses on technical approach, risks, dependencies, and effort estimation.

### Parallel Execution Pattern

```yaml
# CORRECT (Parallel and efficient):
- Task(product-manager, "Define user stories for [feature]")
- Task(senior-software-engineer, "Outline technical approach, risks, and estimate effort")
```

-----

## Ticket Generation Process

### 1) Smart Research Depth Analysis

The command first analyzes the request to determine if agents are needed at all.

LIGHT Complexity → NO AGENTS

- For typos, simple copy changes, minor style tweaks.
- Create the ticket immediately.
- Estimate: <2 hours.

STANDARD / DEEP Complexity → CORE DUO OF AGENTS

- For new features, bug fixes, and architectural work.
- The Core Duo is dispatched in parallel.
- The depth (Standard vs. Deep) determines the scope of their investigation.

**Override Flags (optional)**:

- `--light`: Force minimal research (no agents).
- `--standard` / `--deep`: Force investigation using the Core Duo
- `--single` / `--multi`: Control ticket splitting.

### 2\) Scaled Investigation Strategy

#### LIGHT Research Pattern (Trivial Tickets)

NO AGENTS NEEDED.

1. Generate ticket title and description directly from the request.
2. Set pragmatic estimate (e.g., 1 hour).
3. Create ticket and finish.

#### STANDARD Research Pattern (Default for Features)

The Core Duo is dispatched with a standard scope:

- **`product-manager`**: Define user stories and success criteria for the MVP.
- **`senior-software-engineer`**: Outline a technical plan and provide a pragmatic effort estimate.

#### DEEP Spike Pattern (Complex or Vague Tickets)

The Core Duo is dispatched with a deeper scope:

- **`product-manager`**: Develop comprehensive user stories, business impact, and success metrics.
- **`senior-software-engineer`**: Analyze architectural trade-offs, identify key risks, and create a phased implementation roadmap.

### 3\) Generate Ticket Content

Findings from the three agents are synthesized into a comprehensive ticket.

#### Description Structure

```markdown
## 📋 Expected Behavior/Outcome
<Synthesized from product-manager findings>
- A clear, concise description of the new user-facing behavior.
- Definition of all relevant states (loading, empty, error, success).

## 🔬 Research Summary
**Investigation Depth**: <LIGHT|STANDARD|DEEP>
**Confidence Level**: <High|Medium|Low>

### Key Findings
- **Product & User Story**: <Key insights from product-manager>
- **Technical Plan & Risks**: <Key insights from senior-software-engineer>
- **Pragmatic Effort Estimate**: <From senior-software-engineer>

## ✅ Acceptance Criteria
<Generated from both agents' findings>
- [ ] Functional Criterion (from PM): User can click X and see Y.
- [ ] Technical Criterion (from Eng): The API endpoint returns a `201` on success.
- [ ] All new code paths are covered by tests.

## 🔗 Dependencies & Constraints
<Identified by senior-software-engineer>
- **Dependencies**: Relies on existing Pagination component.
- **Technical Constraints**: Must handle >500 records efficiently.

## 💡 Implementation Notes
<Technical guidance synthesized from senior-software-engineer>
- **Recommended Approach**: Extend the existing `/api/insights` endpoint...
- **Potential Gotchas**: Query performance will be critical; ensure database indexes are added.
```

### 4\) Smart Ticket Creation

- **If total estimated effort is ≤ 2 days**: A single, comprehensive ticket is created.
- **If total estimated effort is \> 2 days**: The work is automatically broken down into 2-3 smaller, interconnected tickets (e.g., "Part 1: Backend API," "Part 2: Frontend UI"), each with its own scope and estimate.

### 5\) Output & Confirmation

The command finishes by returning the URL(s) of the newly created ticket(s) in GitHub.
