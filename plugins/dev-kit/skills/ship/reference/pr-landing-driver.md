# The PR-landing driver

The idempotent loop behind ship's **`land`** verb: drive an open PR from "review-ready" to
"merged + cleaned up" without a human babysitting it. This is the procedure you (the agent)
run by hand each time you'd otherwise stand up a one-off "watch CI then merge" cron — encoded
once so it's consistent.

`land` is **opt-in and explicit** — it is the *only* path where ship merges. Default ship
still hands off and stops. Never start this loop unless the user invoked `land` (e.g. "land
the PR", "land this", "land #N", or "ship and land it").

## Two entry points, one loop

Both reach the same loop below; they differ only in how the PR is located.

- **Mid/after a ship run** — ship just opened (or already handed off) the PR for the current
  worktree's branch. The PR number is known from Phase 8. Run the loop on it.
- **Standalone** ("land the PR" / "land #N" with no active ship run) — resolve the PR first:
  - given `#N`, use it;
  - else find the open PR for the current branch: `gh pr view --json number,state,headRefName`
    (or `gh pr list --head "$(git branch --show-current)" --state open --json number`);
  - if there's no open PR for this branch, say so and stop — there's nothing to land.
  Then run the loop. (Standalone land has no worktree of its own to tear down; the post-merge
  cleanup still reconciles the primary checkout.)

## The loop

Pin every check to the PR's **current head SHA** — re-read it after each push, never poll a
stale head. **Reads must use the GitHub MCP, not `gh`**: PR state, checks, and reviews via
`mcp__github__pull_request_read` / `get_check_runs` / `get_status`, and remote file
contents via `mcp__github__get_file_contents`. The **only** read for which `gh` is the right tool is a live
`--watch` stream (`gh pr checks --watch`, `gh run watch`) that delivers a terminal
notification when checks reach a terminal state; for every other read, including polling CI
status, run an MCP `get_check_runs` loop instead of `gh --watch`. For **writes** — merging,
commenting, resolving threads — prefer the MCP (`mcp__github__merge_pull_request` and
siblings); the `gh` porcelain used in the numbered steps below (e.g. `gh pr merge`) is an
acceptable equivalent where it reads cleaner.

1. **Make sure the branch can merge.** If the PR is behind its base, update it
   (`gh pr update-branch <#>`, or rebase onto the base and force-push). A branch-protection
   "branches must be up to date" rule otherwise blocks the merge.
2. **Watch CI on the current head.** Kick off a *harness-tracked* background watch that exits
   when the checks reach a terminal state and **re-invokes you on completion** (a backgrounded
   poll loop, or a Monitor). Set `state` to `waiting:ci` so the Stop hook lets the session rest
   meanwhile (see ship Phase 0); when the watch fires, re-arm the active `phase-*` token and
   continue. Don't set `waiting:ci` with nothing watching — a bare stop strands the loop, since
   nothing would resume it.
3. **On red, fix and re-watch.** Triage the failing check like any reviewer: reproduce, fix,
   commit, push to the same branch, then go back to step 1 against the new head. **Bound it** —
   after ~3 rounds with no progress on the same failure, stop and surface it for the human
   rather than thrashing. Don't paper over a real failure to force the merge.
4. **Converge the automated review.** Run ship's Phase 8 Copilot convergence loop to
   completion, parking as `waiting:copilot` between rounds the same way — backed by a watch
   that resumes you, never a bare stop. If Copilot is **unavailable** (Phase 8 state (a) —
   rejected, or assigned-but-silent past the bounded window), that **counts as converged** for
   the gate below: `land` does not block a green PR on a review that can't happen — surface
   that Copilot didn't review, and proceed.
5. **Merge — the one place ship merges.** Once CI is green on the current head **and** the
   review has converged (or was skipped as unavailable per step 4), mark the PR ready
   (`gh pr ready`) and **rebase-merge** it:
   `gh pr merge <#> --rebase`. Rebase-merge (not squash, not a merge commit) is deliberate —
   it keeps the per-commit Conventional Commit history release-please reads and matches the
   repo's merge strategy. Confirm the merge actually landed (`gh pr view <#> --json state,mergedAt`).
6. **Clean up.** Fall straight into ship's **Post-merge** steps — no "tell me when it merged"
   wait, because ship just merged it: ExitWorktree(keep) if inside the worktree, run
   `/dev-kit:cleanup-locally` from the primary checkout, then reconcile the tracking issue(s)
   via `/dev-kit:handle-task-tracking` (verify `Closes #N` fired, clear any stale
   `status:in-*` label). Set `state` to `done`.

## What land is not

- **Not GitHub auto-merge.** ship holds the merge decision and merges on green + converged —
  it does not hand the trigger to GitHub's `--auto` / branch-protection machinery and walk
  away. (If you *want* GitHub to merge later on its own, that's a different, non-`land`
  request.)
- **Not a force-merge.** A failing check that can't be fixed in the bounded rounds, an
  unresolved review, or a merge GitHub refuses (conflicts, failing required checks) stops the
  loop with the reason surfaced. land never overrides a red gate to get the merge through.
- **Not a background cron that merges.** The only background job is a *watch* that notifies you
  when CI or a review lands; it never merges. ship runs in-session and makes every merge
  decision itself when the watch resumes it — there's no detached job
  left merging after the session ends.
