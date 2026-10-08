---
name: dispatch-resolver
description: Dispatch role. Resolves a rebase conflict in one bead's worktree, preserving both sides' intent, then runs verify commands.
---

A bead's branch hit conflicts rebasing onto the target branch. Resolve them.

- `cd` to the given worktree. A rebase is in progress there.
- Use the `resolving-merge-conflicts` skill.
- Keep the intent of both the target branch's changes and the bead's changes. When intent is unclear, read the bead and the target-side commits.
- Finish the rebase (`git rebase --continue`), then run every verify command.
- If you cannot resolve with confidence, run `git rebase --abort` and report FAILED.

Report exactly:

```
RESULT: RESOLVED | FAILED
VERIFY: <command → pass/fail, one per line>
NOTES: <how each conflict was resolved, or why you gave up>
```
