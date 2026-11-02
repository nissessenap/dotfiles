export const meta = {
  name: 'ship-issue',
  description: 'Implement a GitHub issue, review it through 3 lenses, have a fresh skeptic judge the findings, fix, open a draft PR and get CI green',
  whenToUse: 'args: {issue: "<github issue url>", dry?: true (no push/PR), base?: "<git ref to branch from>"}',
  phases: [
    { title: 'Setup' },
    { title: 'Implement' },
    { title: 'Review', detail: 'correctness, spec+standards, ponytail in parallel' },
    { title: 'Judge', detail: 'fresh agent rules on every finding' },
    { title: 'Fix' },
    { title: 'PR', detail: 'draft PR + CI until green, max 2 fix attempts' },
  ],
}

const A = typeof args === 'string' ? { issue: args } : args
if (!A || !A.issue) throw new Error('args.issue (GitHub issue URL) required')

const RULES = `Hard rules: never deploy anything or touch prod/staging. Comments only where a maintainer needs them; no history of why/how (that goes in the PR description). Write idiomatic code for the language version the repo declares (go.mod go line, requires-python, scalaVersion, tsconfig target) and use its newest features and stdlib over older patterns or extra deps.`

phase('Setup')
const ws = await agent(`Prepare to work on ${A.issue}. Read the issue and all its comments, and any issue/PR it links.
Find the repo locally (see CLAUDE.md layout), \`git fetch\`, then create a NEW git worktree next to it on a new branch from ${A.base || 'the origin default branch'} (don't touch the existing checkout). `, {
  label: 'setup', model: 'sonnet',
  schema: { type: 'object', required: ['worktree', 'branch', 'issue_summary'], properties: {
    worktree: { type: 'string' }, branch: { type: 'string' },
    issue_summary: { type: 'string', description: 'what the issue asks for, incl. acceptance criteria and relevant comments' },
  } },
})
if (!ws) throw new Error('setup failed')
const CTX = `Issue: ${A.issue}\n${ws.issue_summary}\nWork ONLY in the worktree ${ws.worktree} (branch ${ws.branch}).\n${RULES}`

phase('Implement')
const impl = await agent(`${CTX}\n\nSolve the problem behind the issue. Implementation ideas in the issue are suggestions, not requirements: deviate when there is a better way, and note why in the commit message. Tests cover failure and edge cases (invalid input, errors, boundaries), not just the happy path. Run the repo's tests and linters locally until they pass. Commit (conventional commits). Don't push.`, {
  label: 'implement',
  schema: { type: 'object', required: ['summary', 'checks'], properties: {
    summary: { type: 'string' }, checks: { type: 'string', description: 'what you ran and the result' } } },
})
if (!impl) throw new Error('implement failed')

const FINDINGS = { type: 'object', required: ['findings'], properties: { findings: { type: 'array', items: {
  type: 'object', required: ['id', 'where', 'problem', 'suggestion'], properties: {
    id: { type: 'string' }, where: { type: 'string', description: 'file:line' }, problem: { type: 'string' }, suggestion: { type: 'string' } } } } } }
const DIFF = `Review the diff of ${ws.branch} against its merge-base with the default branch, in ${ws.worktree}. Read-only: don't modify files.`
const LENSES = [
  { key: 'correctness', p: `Find correctness bugs, security issues and missing tests, especially missing negative/edge-case tests. Use the built-in code-review skill if available.` },
  { key: 'spec', p: `Does the change solve the underlying problem the issue describes? The issue's proposed implementation is a suggestion; judge the outcome, not whether it was followed. Flag unrelated scope creep. Does it follow the repo's documented standards (CLAUDE.md, CONTRIBUTING, lint config)?` },
  { key: 'ponytail', p: `Find over-engineering: what can be deleted, replaced by stdlib, or simplified. Use the ponytail:ponytail-review skill if available.` },
]

phase('Review')
const reviews = await parallel(LENSES.map(l => () =>
  agent(`${CTX}\n\n${DIFF}\n${l.p}\nPrefix ids with "${l.key}-".`, { label: `review:${l.key}`, phase: 'Review', schema: FINDINGS })
    .then(r => r ? r.findings.map(f => ({ ...f, lens: l.key })) : [])))
const findings = reviews.filter(Boolean).flat()
log(`${findings.length} findings: ${LENSES.map(l => `${l.key} ${findings.filter(f => f.lens === l.key).length}`).join(', ')}`)

phase('Judge')
const judge = await agent(`${CTX}\n\n${DIFF}
Three reviewers looked at this change. Rule on EVERY finding below: accept, reject, or modify, with a concrete reason grounded in the code. Reviewers can be wrong, overkill, or contradict each other (e.g. correctness wants more code, ponytail wants less); you settle it. Disagreeing is fine with a reason. Also add anything they all missed.
${JSON.stringify(findings, null, 1)}`, {
  label: 'judge',
  schema: { type: 'object', required: ['verdicts', 'new_findings'], properties: {
    verdicts: { type: 'array', items: { type: 'object', required: ['id', 'verdict', 'reason'], properties: {
      id: { type: 'string' }, verdict: { type: 'string', enum: ['accept', 'reject', 'modify'] }, reason: { type: 'string' }, change: { type: 'string', description: 'what to actually do, if accept/modify' } } } },
    new_findings: FINDINGS.properties.findings,
  } },
})
if (!judge) throw new Error('judge failed')
const missing = findings.map(f => f.id).filter(id => !judge.verdicts.some(v => v.id === id))
if (missing.length) log(`judge skipped: ${missing.join(', ')}`)
const todo = [...judge.verdicts.filter(v => v.verdict !== 'reject'), ...judge.new_findings]

phase('Fix')
let fix = null
if (todo.length) {
  fix = await agent(`${CTX}\n\nApply these review outcomes, nothing else:\n${JSON.stringify(todo, null, 1)}\nRun tests and linters until green. Commit.${A.dry ? " Don't push." : ' Push the branch.'}`, {
    label: 'fix',
    schema: { type: 'object', required: ['done', 'checks'], properties: { done: { type: 'string' }, checks: { type: 'string' } } },
  })
}

let pr = null
if (!A.dry) {
  phase('PR')
  pr = await agent(`${CTX}\n\nPush the branch if not pushed. Open a DRAFT PR that closes the issue; write the body with the mattpocock-skills:pr skill if available. Then \`gh pr checks --watch\`. If CI fails, fix, commit, push, re-watch. Max 2 fix attempts, then stop and report what's failing.`, {
    label: 'pr',
    schema: { type: 'object', required: ['url', 'ci'], properties: { url: { type: 'string' }, ci: { type: 'string', enum: ['green', 'red', 'pending'] }, notes: { type: 'string' } } },
  })
}

return { worktree: ws.worktree, branch: ws.branch, implement: impl, findings, judge, fix, pr }
