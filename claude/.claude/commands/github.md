---
description: Manage GitHub issues - create, update, comment, and sync with thoughts/tickets
---

# GitHub - Issue Management

You are tasked with managing GitHub issues, including creating issues from thoughts documents, updating existing issues, and syncing them to/from the thoughts/tickets directory.

## Initial Setup

First, verify that GitHub MCP tools are available by checking if any `mcp__github__` tools exist. If not, respond:
```
I need access to GitHub tools to help with issue management. Please run the `/mcp` command to enable the GitHub MCP server, then try again.
```

If tools are available, respond based on the user's request:

### For general requests:
```
I can help you with GitHub issues. What would you like to do?
1. Create a new issue from a thoughts document
2. Sync an existing issue to thoughts/tickets
3. Add a comment to an issue (I'll use our conversation context)
4. Search for issues
5. Update issue status or details
```

### For specific create requests:
```
I'll help you create a GitHub issue from your thoughts document. Please provide:
1. The path to the thoughts document (or topic to search for)
2. Any specific focus or angle for the issue (optional)
```

Then wait for the user's input.

## Repository Detection

The command works with the current repository where it's run. To detect the repository:

1. **Get the remote URL:**
   ```bash
   git remote get-url origin
   ```

2. **Parse owner and repo:**
   - From `git@github.com:owner/repo.git` → extract `owner` and `repo`
   - From `https://github.com/owner/repo.git` → extract `owner` and `repo`

3. **Store for use in API calls:**
   - Use the extracted owner/repo in all GitHub API calls
   - Format: `owner/repo`

## Important Conventions

### Default Values
- **State**: Always create new issues as "open"
- **Labels**: No default labels applied (user can specify)
- **Assignees**: Ask user if they want to assign (can assign to themselves)

### Syncing to thoughts/tickets

When syncing GitHub issues to local files:

1. **File naming:** `thoughts/tickets/issue-{number}.md`
   - Example: `thoughts/tickets/issue-123.md`

2. **File format:**
   ```markdown
   ---
   github_issue: https://github.com/owner/repo/issues/{number}
   number: {number}
   state: {open|closed}
   created: {date}
   updated: {date}
   labels: [{label1}, {label2}]
   assignees: [{user1}, {user2}]
   ---

   # {Issue Title}

   {Issue body content}

   ## Comments

   ### {author} - {date}
   {comment content}

   ### {author} - {date}
   {comment content}
   ```

## Action-Specific Instructions

### 1. Creating Issues from Thoughts

#### Steps to follow after receiving the request:

1. **Locate and read the thoughts document:**
   - If given a path, read the document directly
   - If given a topic/keyword, search thoughts/ directory using Grep to find relevant documents
   - If multiple matches found, show list and ask user to select
   - Create a TodoWrite list to track: Read document → Analyze content → Draft issue → Get user input → Create issue

2. **Analyze the document content:**
   - Identify the core problem or feature being discussed
   - Extract key implementation details or technical decisions
   - Note any specific code files or areas mentioned
   - Look for action items or next steps
   - Identify what stage the idea is at (early ideation vs ready to implement)
   - Take time to think about distilling the essence of this document into a clear problem statement and solution approach

3. **Check for related context (if mentioned in doc):**
   - If the document references specific code files, read relevant sections
   - If it mentions other thoughts documents, quickly check them
   - Look for any existing GitHub issues mentioned

4. **Get repository context:**
   - Run `git remote get-url origin` to get the repository
   - Parse owner/repo from the URL

5. **Draft the issue summary:**
   Present a draft to the user:
   ```
   ## Draft GitHub Issue

   **Title**: [Clear, action-oriented title]

   **Description**:
   [2-3 sentence summary of the problem/goal]

   ## Key Details
   - [Bullet points of important details from thoughts]
   - [Technical decisions or constraints]
   - [Any specific requirements]

   ## Implementation Notes (if applicable)
   [Any specific technical approach or steps outlined]

   ## References
   - Source: `thoughts/[path/to/document.md]`
   - Related code: [any file:line references]
   - Parent issue: [if applicable]
   ```

6. **Interactive refinement:**
   Ask the user:
   - Does this summary capture the issue accurately?
   - What labels should we apply? (optional)
   - Should we assign it to anyone?
   - Any additional context to add?
   - Should we include more/less implementation detail?

7. **Create the GitHub issue:**
   ```
   mcp__github__create_issue with:
   - owner: [repository owner]
   - repo: [repository name]
   - title: [refined title]
   - body: [final description in markdown]
   - labels: [if specified]
   - assignees: [if requested]
   ```

8. **Post-creation actions:**
   - Show the created issue URL
   - Ask if user wants to:
     - Sync the issue to thoughts/tickets for local tracking
     - Add a comment with additional implementation details
     - Update the original thoughts document with the issue reference
   - If yes to syncing to thoughts/tickets:
     - Create `thoughts/tickets/issue-{number}.md` with frontmatter and content
   - If yes to updating thoughts doc:
     ```
     Add at the top of the document:
     ---
     github_issue: [URL]
     created: [date]
     ---
     ```

## Example transformations:

### From verbose thoughts:
```
"I've been thinking about how our resumed sessions don't inherit permissions properly.
This is causing issues where users have to re-specify everything. We should probably
store all the config in the database and then pull it when resuming. Maybe we need
new columns for permission_prompt_tool and allowed_tools..."
```

### To concise issue:
```
Title: Fix resumed sessions to inherit all configuration from parent

Description:

## Problem to solve
Currently, resumed sessions only inherit Model and WorkingDir from parent sessions,
causing all other configuration to be lost. Users must re-specify permissions and
settings when resuming.

## Solution
Store all session configuration in the database and automatically inherit it when
resuming sessions, with support for explicit overrides.
```

### 2. Syncing Issues to thoughts/tickets

When user wants to sync an issue locally:

1. **Get the issue details:**
   ```
   mcp__github__get_issue with:
   - owner: [repository owner]
   - repo: [repository name]
   - issue_number: [number]
   ```

2. **Get issue comments:**
   ```
   mcp__github__list_issue_comments with:
   - owner: [repository owner]
   - repo: [repository name]
   - issue_number: [number]
   ```

3. **Create local file:**
   - Write to `thoughts/tickets/issue-{number}.md`
   - Include frontmatter with metadata
   - Include full issue body
   - Append all comments with author and timestamp

4. **Confirm:**
   ```
   Synced issue #{number} to thoughts/tickets/issue-{number}.md
   ```

### 3. Adding Comments to Existing Issues

When user wants to add a comment to an issue:

1. **Determine which issue:**
   - Use context from the current conversation to identify the relevant issue
   - If uncertain, use `mcp__github__get_issue` to show issue details and confirm with user
   - Look for issue references in recent work discussed

2. **Format comments for clarity:**
   - Attempt to keep comments concise (~10 lines) unless more detail is needed
   - Focus on the key insight or most useful information for a human reader
   - Not just what was done, but what matters about it
   - Include relevant file references with backticks

3. **File reference formatting:**
   - Wrap paths in backticks: `thoughts/example.md`
   - Do this for both thoughts/ and code files mentioned

4. **Comment structure example:**
   ```markdown
   Implemented retry logic in webhook handler to address rate limit issues.

   Key insight: The 429 responses were clustered during batch operations,
   so exponential backoff alone wasn't sufficient - added request queuing.

   Files updated:
   - `src/webhooks/handler.go`
   - `thoughts/rate_limit_analysis.md`
   ```

5. **Create the comment:**
   ```
   mcp__github__create_issue_comment with:
   - owner: [repository owner]
   - repo: [repository name]
   - issue_number: [number]
   - body: [formatted comment with key insights and file references]
   ```

### 4. Searching for Issues

When user wants to find issues:

1. **Gather search criteria:**
   - Query text
   - State filters (open, closed, all)
   - Label filters
   - Assignee filters

2. **Execute search:**
   ```
   mcp__github__search_issues with:
   - query: [search text with filters]
   - owner: [repository owner]
   - repo: [repository name]
   ```

3. **Present results:**
   - Show issue number, title, state, assignee
   - Include direct links to GitHub
   - Group by label if filtering by labels

### 5. Updating Issue Status

When closing or reopening issues:

1. **Get current status:**
   - Fetch issue details
   - Show current state

2. **Update issue:**
   ```
   mcp__github__update_issue with:
   - owner: [repository owner]
   - repo: [repository name]
   - issue_number: [number]
   - state: [open|closed]
   ```

3. **Consider adding a comment** explaining the status change

## Important Notes

- Keep issues concise but complete - aim for scannable content
- All issues should include a clear "problem to solve" - if the user asks for an issue and only gives implementation details, you MUST ask "To write a good issue, please explain the problem you're trying to solve from a user perspective"
- Focus on the "what" and "why", include "how" only if well-defined
- Use proper GitHub markdown formatting
- Include code references as: `path/to/file.ext:linenum`
- Ask for clarification rather than guessing labels/assignees
- Remember that GitHub descriptions support full markdown including code blocks
- Remember - you must get a "Problem to solve"!

## Comment Quality Guidelines

When creating comments, focus on extracting the **most valuable information** for a human reader:

- **Key insights over summaries**: What's the "aha" moment or critical understanding?
- **Decisions and tradeoffs**: What approach was chosen and what it enables/prevents
- **Blockers resolved**: What was preventing progress and how it was addressed
- **State changes**: What's different now and what it means for next steps
- **Surprises or discoveries**: Unexpected findings that affect the work

Avoid:
- Mechanical lists of changes without context
- Restating what's obvious from code diffs
- Generic summaries that don't add value

Remember: The goal is to help a future reader (including yourself) quickly understand what matters about this update.
