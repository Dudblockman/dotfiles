---
# Copy to <repo>/.claude/dispatch.md. Delete any key you don't need; defaults are in SKILL.md.
parallelism: 3
max_fix_rounds: 2
select:
  labels: []
  max_priority: null
verify:
  - npm test
  - npm run lint
land: merge   # or: pr
target: null
stages: []
#  - agent: security-reviewer      # any agent type, e.g. from .claude/agents/
#    pass: "VERDICT: PASS"
---

Project context for every dispatch agent goes here: conventions, gotchas, which dirs are generated, etc.

To replace a role entirely, add `.claude/agents/dispatch-<role>.md` (planner, implementer, reviewer, resolver) and keep its output contract.
