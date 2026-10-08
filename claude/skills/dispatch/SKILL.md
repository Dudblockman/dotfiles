---
name: dispatch
description: Run beads through plan → implement → adversarial review → land, one or many in parallel, each in its own git worktree. Use when the user says "dispatch", "pull a bead and implement it", "work these beads", or names bead ids to get done. `/dispatch` auto-picks ready beads, `/dispatch N` picks up to N, `/dispatch id1 id2` runs exactly those.
---

# Dispatch

You are the orchestrator. You spawn role agents and move results between them. You never plan, implement, review, or resolve conflicts yourself.

## Roles

Each role is an agent type. A workspace replaces one by defining `.claude/agents/<name>.md` with the same name; project agents override the global ones. Overrides must keep the output contract, because you parse it.

| Agent | Contract you parse |
|---|---|
| `dispatch-planner` | `## Plan`, `## Acceptance criteria`, `## Files` |
| `dispatch-implementer` | `BRANCH:`, `WORKTREE:`, `VERIFY:`, `NOTES:` |
| `dispatch-reviewer` | `VERDICT: PASS\|FAIL`, `CRITERIA:`, `FINDINGS:` |
| `dispatch-resolver` | `RESULT: RESOLVED\|FAILED`, `VERIFY:`, `NOTES:` |

Give each agent only what its role needs: the bead, plan, criteria, worktree, diff range, findings, verify commands, project context. Never pass one agent's reasoning or self-assessment to another. In particular the reviewer never sees implementer `NOTES`.

## 0. Config

Read `.claude/dispatch.md` in the repo root if it exists. YAML frontmatter sets knobs. Missing keys take these defaults:

```yaml
parallelism: 3          # max beads in flight when auto-picking
max_fix_rounds: 2       # implementer retries after a failed gate
select:                 # filters applied to `bd ready` when auto-picking
  labels: []            # bead must carry all of these
  max_priority: null    # e.g. 1 = only P0/P1
verify: []              # shell commands implementer, reviewer and resolver must all run
land: merge             # merge = rebase onto target + fast-forward; pr = push branch + open PR
target: null            # branch to land on; null = branch checked out when dispatch started
stages: []              # extra gates after review, in order. Each: {agent: <type>, pass: <string in output meaning pass>}
```

The markdown body is **project context**. Append it to every role agent's prompt under `## Project context`.

## 1. Select

- Ids given: use them. N = number of ids.
- Otherwise: N = argument or `parallelism`. Run `bd ready --json`, apply `select` filters, take the top 2N by priority as candidates.

Record the target branch and its HEAD sha.

## 2. Plan

Spawn one `dispatch-planner` per candidate, all in one message, in parallel. Prompt: bead id + project context.

Pick:
- **Explicit ids:** keep all. If two plans share a path under `## Files`, warn the user which beads overlap and continue.
- **Auto:** walk candidates in priority order. Keep a bead only if its `## Files` is disjoint from every bead already kept. Stop at N. Tell the user which candidates were skipped and the overlapping paths.

For each kept bead, write the planner's whole output to a temp file and run:
- `bd comments add <id> -f <file>`
- `bd update <id> --claim`

## 3. Per-bead chain

Run every kept bead's chain concurrently: background agents, and advance each chain as its notifications arrive.

1. **Implement.** Spawn `dispatch-implementer` with `isolation: "worktree"`. Prompt: bead id, plan, acceptance criteria, verify commands, project context. Record `BRANCH` and `WORKTREE`.
2. **Gates, in order:** `dispatch-reviewer`, then each `stages[].agent`. Prompt: bead id, acceptance criteria, worktree path, diff range `<target-sha>..<branch>`, verify commands, project context. The reviewer passes on `VERDICT: PASS`; a stage passes when its output contains that stage's `pass` string. Stop at the first failing gate.
3. **Fix.** On a failure, if rounds used < `max_fix_rounds`, spawn a fresh `dispatch-implementer` without isolation. Prompt: bead id, plan, criteria, the failing gate's findings, "work in existing worktree `<WORKTREE>`", verify commands, project context. Then rerun all gates from the start.
4. **Give up.** When the cap is hit, add the last findings as a bead comment, set `bd update <id> --status blocked`, keep the worktree, and mark the bead failed.

## 4. Land

Land beads one at a time, in the order they passed.

**`land: merge`** (linear history, no merge commits):
1. In the worktree, run `git rebase <target>`.
2. On conflict, spawn `dispatch-resolver` with the worktree path, bead id, verify commands, and project context.
   - `RESOLVED`: run `dispatch-reviewer` on the rebased diff, with criteria plus "check that the conflict resolution preserved both sides". FAIL means `git rebase --abort` if a rebase is still in progress, then give up as in 3.4.
   - `FAILED`: give up as in 3.4.
3. From the main checkout, run `git checkout <target>`, then `git merge --ff-only <branch>`.
4. Run `git worktree remove <WORKTREE>`, then `git branch -d <branch>`.
5. Run `bd close <id> --reason "<one-line summary>"`.

**`land: pr`:** push the branch and open a PR/MR (`gh`, or `glab` on GitLab) with the bead title and the acceptance criteria. Add the link with `bd comments add`. Leave the bead open and keep the worktree.

## 5. Report

Show one table: bead · verdict · fix rounds · landed (sha / PR link / no) · notes. List any worktrees left behind.
