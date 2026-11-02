---
name: pr-description
description: Write or rewrite a pull request title and body. Use when opening a PR, when asked to "write the PR description", or to improve an existing one.
---

Write for a reviewer who has not seen the issue or the code. They should understand why, what changes and how risky it is within a minute. The diff shows the details; the description gives what the diff can't: intent, behaviour change, risk, where to look.

Budget: about 300 words for a normal PR. Go longer only for one-way doors or behaviour changes that need examples. Say each fact once.

## Structure

If the repo has a GitHub PR template, keep its headings and order. Drop checklist-only sections (e.g. "Merge Checklist") and optional sections you have nothing for. Otherwise use:

```markdown
## Why
## Idea
## Before / After
## Risk
## Tests
## Code health
```

Fold the content below into whichever headings exist (template "What's changed" = Idea; "Previous/New behaviour" = Before / After; "Note to Reviewer" = Risk + Code health).

## Content

- **Why**: the problem in one or two sentences, plus a link to the issue. If the solution deviates from what the issue proposed, say so and why.
- **Idea**: how the change solves the problem, in 2-4 bullets at the concept level ("X now does Y instead of Z"). No signatures, type or field names, file lists or doc updates; the diff has those. Name things only in the reading order. End with a reading order: the 2-3 places to open first.
- **Before / After**: show the difference with a concrete example when there is an observable one: a request and response, a CLI call and its output, a config snippet, a log line, an error message. Real values, not placeholders. This is usually the most valuable section: behaviour changes are hard to spot in a diff. Skip it for pure refactors and say "no behaviour change".
- **Diagram**: add one only when the change alters flow, structure or ownership and prose would take a paragraph to explain it. Use Mermaid for flow between components, or a `diff` code block of a call tree, file tree or state flow. Keep it to the nodes that changed plus their immediate neighbours. One diagram at most; none for small or local changes.
- **Tests**: 1-3 bullets on which kinds of cases are covered (including failure and edge cases), not a list of test names. Say what you could not run locally.
- **Risk**:
  - *Door*: two-way (cheap to revert) or one-way (data migrations, deleted data, public API or contract changes, anything consumers depend on). For one-way doors, say what makes it irreversible and how it was made safe.
  - *Blast radius*: who or what is affected if this is wrong (one service, every consumer of a library, one customer flow).
  - Call out the one or two things a reviewer should actually verify (accepted trade-offs, assumptions about other systems). If Before / After already shows it, point to that row instead of restating it.
- **Code health**: will the next person find this code easy to change? Be honest about whether the change leaves it better or worse. Name added complexity, duplication or workarounds. List refactors that would help, each with its value and cost. Say whether it was done here, should be a follow-up issue (link it if created), or is not worth doing. Write "No concerns" if there are none.

## Style

- Short bullets, short sentences, plain words. No preamble, no restating the title, no marketing language.
- Bold the one or two things a reviewer must not miss (behaviour changes, one-way doors).
- Link issues and PRs as `#123` or `owner/repo#123`. Reference code as `path/file.ext` or `Type.method`.
- Title: Conventional Commits, describing the outcome, not the mechanics.
