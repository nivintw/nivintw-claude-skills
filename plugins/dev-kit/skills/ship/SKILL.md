---
name: ship
description: >-
  This skill should be used when the user asks to "ship this", "ship a change/feature/fix",
  "take this from idea to a PR", "open a PR for this", or "run the full dev workflow on
  this" — any real change worth a planned, reviewed pull request. It drives a change from
  idea to a review-ready PR through a disciplined Human + AI teaming workflow: an explicit
  planning step and sign-off first, work isolated in a dedicated worktree,
  implementation that fans out subagents and /workflows (delegating mechanical work to
  cheaper models to stay token-conscious), task tracking delegated to
  /dev-kit:handle-task-tracking across the lifecycle, then always /simplify, then refresh
  docs, then a full /dev-kit:review-pr pass, the local quality gate, a conventional-commit
  PR, and an automated Copilot review iterated to convergence before the change is handed
  off for human review. On explicit request it also **lands** an open PR ("land the PR",
  "land this", "land #N", "ship and land it"): it drives CI to green, converges the
  automated review, then rebase-merges and cleans up — the one path where ship merges. Not
  for a trivial one-off commit or a bare "push this". Never merges unless you explicitly
  invoke `land`.
---

# ship

The orchestrator for shipping a change well. Run the phases **in order**. The throughline:
keep the human in control at the ends (plan sign-off, and the merge decision) and do
rigorous, token-aware work in the middle. **By default ship never merges** — it hands off a
review-ready PR. The one exception is the explicit **`land`** verb (see *Land the PR*),
where you authorize ship to drive the PR all the way to merged; absent that, ship always
stops at hand-off.

## Start of run — reconcile local state (cleanup-locally)

Before anything else, run **`/dev-kit:cleanup-locally`** from the primary checkout. It
fetches, brings the default branch up to date (stashing/rebasing any local work forward,
never clobbering), and prunes branches and `.claude/worktrees/` worktrees whose work has
already merged. Two payoffs: the worktree this run creates in Phase 2 branches off a
*current* base, and the leftovers from previously-shipped work don't pile up. It's
conservative — anything unmerged, dirty, or checked out is kept — so this is always safe to
run first. If it isn't installed, note the gap and continue.

## Phase 0 — Continuity setup (do this first, maintain throughout)

Create a durable progress file at **`"$(git rev-parse --git-dir)/ship/progress.md"`** and
update it at **every phase boundary**: the plan, decisions made, what's done, what's next.
Keeping it under the git dir (not in the working tree) is deliberate — it's **uncommittable
by construction**: never in a working tree, never swept up by `git add -A`, never tripping
the repo's markdown/lint hooks, and needing **no `.gitignore` entry**, so nothing the change
under ship does to `.gitignore` can expose it. This is also what makes ship robust to context
compaction: ship cannot trigger `/compact` itself and cannot measure its own context, so
instead it (a) pushes heavy work into subagents whose context is discarded, (b) keeps this
file + checkpoint commits as durable state, and (c) at long phase boundaries, *advises* the
user "good moment to /compact — state is saved under the ship dir." After any compaction,
re-read this file to resume losslessly.

Alongside it, maintain a one-line **`state`** file in the same dir
(`"$(git rev-parse --git-dir)/ship/state"`) — a tiny state machine the dev-kit **Stop hook**
reads to keep ship from yielding mid-run after a delegated sub-skill hands back. It holds one
of:

- an **active-phase** token that **must start with `phase-`** (e.g. `phase-3-implement`,
  `phase-6-review`) while a phase is *executing* — bump it as you cross each boundary, the
  same moment you update the progress file. Set active tokens **only inside the worktree**
  (Phase 2 onward): the premature-halt this guards against happens once sub-skills run
  (Phases 4–6), all of which are inside the worktree.
- `gate:plan-signoff` while *parked* awaiting the user's sign-off (Phase 1) — the only `state`
  the primary checkout ever holds before the worktree exists.
- a **`waiting:*`** token while *parked on a harness-tracked async job that will re-invoke you
  when it finishes* — `waiting:ci` / `waiting:copilot` while a background CI or Copilot watch
  runs (Phase 8 and the `land` loop), or `waiting:agents` while a background subagent fan-out
  you dispatched is still running. The hook lets the session rest instead of nagging, and the
  job's own completion notification is what resumes you; re-arm the active `phase-*` token when
  it does. **Only park when something will actually resume you, and never set `waiting:*` in
  place of continuing after a sub-skill hands back** — a `/simplify` or `/security-review`
  return is a hand-back to act on *now*, not a wait, and is exactly the premature stop the
  `phase-*` block exists to catch.
- `done` once the change is *handed off* (Phase 8).

The hook blocks a stop **only** while `state` is a `phase-*` token; **every** other value —
`gate:*`, `waiting:*`, `done`, blank, a stale token, or a typo — lets the stop through. That
default-allow is deliberate: it can never trap you at a human gate, never nag while you're
legitimately parked waiting on CI or Copilot, and a forgotten or stale `state` fails safe. And because active tokens live only in the worktree's git dir, they
are torn down with the worktree and never orphaned in your primary checkout. So `gate:plan-signoff`
and `done` are the only points where a ship run legitimately stops (plan sign-off and hand-off);
keep `state` current as a courtesy to the backstop, but continuing past a hand-back is *your*
discipline — the hook is only a net.

Mind the CWD switch: Phase 2's EnterWorktree moves the session into a fresh worktree.
`$(git rev-parse --git-dir)` then resolves to **that worktree's own git dir**, so the path
above stays correct automatically and the filename never needs keying off the branch — but
the progress/state written *before* entering live under the original checkout's git dir, so
re-establish both in the worktree's ship dir right after entering.

## Phase 1 — Plan (explicit, required)

Never skip this. Understand the ask, then **fan out `Explore` subagents** (read-only) to map
the relevant code, patterns, and prior art — so the main context stays lean. Write a concrete
plan + checklist into the progress file: what changes, which files, the approach, risks, and
how it'll be verified. **Get the user's sign-off on the plan before implementing.** Surface
genuine decisions now (don't bury them).

Delegate task tracking to **`/dev-kit:handle-task-tracking`** — don't reinvent it here.
Find or open the GitHub issue that tracks this work, record its number in the progress file,
and capture the plan's key decisions on the issue. The ship progress file tracks
*this run's* mechanics; the **issue is the durable record of the work itself**, so it
outlives the branch and the session. Before you yield for sign-off, set `state` to
`gate:plan-signoff` (the hook never blocks a gate, so the session rests here); you arm the
first active `phase-*` token from *inside* the worktree in Phase 2, not before.

## Phase 2 — Worktree + branch (always)

Work inside a **dedicated worktree** on a fresh feature branch — never on `main` or the
user's primary checkout. Create it with the **EnterWorktree** tool (not a bare
`git worktree add`):

```text
EnterWorktree({ name: "<type>/<short-name>" })
```

EnterWorktree is *not* a drop-in for `git worktree add` — account for each difference:

- **It switches the session's CWD** into the new worktree (a fresh checkout). Anything
  written before this — including the Phase 0/1 ship progress/state files — lives under the
  *original* checkout's git dir and is **absent** from this worktree's git dir. Re-establish
  them in the worktree's ship dir right after entering (see Phase 0), and use worktree paths
  from now on. This is where you first arm an active `phase-*` token (e.g. `phase-2-worktree`)
  — active state belongs to the worktree's git dir, never the primary checkout's.
- **It names the branch itself** — typically a sanitized, `worktree-`-prefixed form of
  `name`, not literally `<type>/<short-name>`. Never assume the branch name: read the real
  one with `git branch --show-current`, and key the PR off *that* (the ship progress/state
  filenames no longer depend on it — the per-worktree git dir already isolates them).
- **The base ref is config-governed** (`worktree.baseRef`: `fresh` → `origin/<default-branch>`
  by default, `head` → local HEAD). If the work depends on unpushed local commits, push them
  first or confirm the base includes them — don't assume a clean origin base.
- **It refuses to nest** — if the session is *already* in a worktree, EnterWorktree errors.
  Then don't create a new one: continue in the current worktree, or `ExitWorktree` out first
  and re-enter.

This isolates the in-progress change (the user keeps their main checkout) and lets parallel,
file-mutating subagents run in **per-agent worktree isolation** without clobbering each
other. The worktree **survives hand-off** and is torn down only **post-merge** (the section
after Phase 8), when `/dev-kit:cleanup-locally` removes it once its branch is verified merged.
On abort *before* hand-off, remove it directly with `ExitWorktree({ action: "remove",
discard_changes: true })` — but only once you've confirmed nothing in the worktree is worth
keeping.

A good companion here is the **`worktree-guard`** plugin (this marketplace): a `PreToolUse`
hook that blocks an accidental write to the *primary* checkout while you're working in the
worktree, so a stray absolute path can't edit `main`'s copy instead of the worktree's. It's
optional — ship doesn't depend on it — and it already allows the worktree's own git dir,
where this run's progress/state live.

## Phase 3 — Implement (fan out; delegate by cost)

Do the work. Be **thorough but token-conscious** — that balance is a first-class goal, not an
afterthought. **Route each chunk to the cheapest tier that fits**, judged by *stakes ×
verification-cost × reasoning-depth* — not by file count (a three-file mechanical rename is
trivial; a one-file safety fix is not). "Keep it on Claude" is not "keep it on the top tier":

- **Cheapest / mechanical** — grep/inventory, renames, file moves, formatting, boilerplate,
  repetitive edits, running the gate, regenerating docs. A faster tier (e.g. Haiku) or a
  separate/local model fits; a local model is also a cheap **generation** lane for
  self-contained scaffolding you'll review anyway. When a local model (Ollama) is available,
  **shell out to it** for batchable mechanical work to keep that work off the token budget
  entirely — detect it, route, verify, and log the routing per
  [`reference/local-model-offload.md`](reference/local-model-offload.md); it degrades silently
  to the tiers above when absent.
- **Mid** — contained, well-specified work: a focused implementation, writing tests, a scoped
  refactor, a codegen script with a clear spec (e.g. Sonnet).
- **Top** — hard reasoning, design, cross-cutting changes, and the adversarial/verification +
  **synthesis** work (e.g. Opus).

`/workflows` is orthogonal to the tiers: reach for it to pipeline or fan out independent work
(one agent per file/module/dimension, each at whatever tier fits) whenever the task
decomposes — not only for the hardest work.

Two rules keep this honest:

- **Delegate the work down, keep the judgment up.** Push mechanical and well-scoped chunks to
  cheaper tiers, but the final synthesis — what's right, what's done, what to ship — stays
  with the driver. Don't hand judgment to a weaker tier to save tokens.
- **Don't atomize.** A subagent round-trip for a two-line edit costs more than it saves; the
  win is on *chunks*, not every micro-edit. When in doubt, do the small thing inline.

**Surface the routing**: for any non-trivial chunk, say in one line where it went and why
(e.g. "scaffolding → Sonnet; the safety-critical logic → kept here") rather than silently
defaulting everything to the driver. And **draw on whatever relevant skills and agents the
environment offers** — including ones not named in these phases and ones added after this was
written — at your discretion; survey what's installed rather than following a fixed list.

Update the progress file and make **checkpoint commits** as coherent pieces land. As work
starts, flip the tracking issue to `status:in-progress` (via `/dev-kit:handle-task-tracking`)
and log notable decisions on it as they're made.

## Phase 4 — Simplify (always)

Run **`/simplify`** on the change before any review. Quality-only cleanup (reuse,
simplification, efficiency, altitude) while everything is fresh.

## Phase 5 — Docs (default; skip only if no docs site)

Run **`/dev-kit:generate-docs`** so the docs never drift from the change. It reconciles the
whole docs set against the whole codebase and shapes the site to the repo kind (marketplace,
Copier template, library/CLI, or generic), so it applies to any repo — only skip if the repo
genuinely has no docs to maintain. Default to keeping docs current.

## Phase 6 — Review (always)

Run **`/dev-kit:review-pr`** (Mode A — your own change). That runs the full battery
(`/code-review`, `/security-review`, `/pr-review-toolkit:review-pr`) **plus a context-chosen
adversarial pass**, then synthesizes one prioritized report. Apply the must-fixes; re-run as
needed; leave the branch green. Flip the tracking issue to `status:in-review` (via
`/dev-kit:handle-task-tracking`) once the change is up for review.

**`/dev-kit:review-pr` and the reviewers under it return *hand-backs*, not stopping points.**
`/security-review` is the most frequent trap: it returns a self-contained markdown report
that *looks* like a terminal deliverable, so the pull is to yield. Don't. When the review pass
returns, synthesize it and continue straight to Phase 7 — the only stops in a default ship
run are plan sign-off (Phase 1) and hand-off (Phase 8); under `land` the run continues past
hand-off through merge to cleanup. The dev-kit Stop hook backstops this while `state` names an
active phase, but the discipline is yours.

## Phase 7 — Local gate

Infer the repo's checks from its config (pre-commit/prek, test runner, linters, type
checker) and run them — don't wait to be told. Fix what they flag. Match the project's
existing quality bar.

## Phase 8 — Commit + PR (hand off, don't merge)

Commit in **Conventional Commit** style (and gitmoji if the repo enforces it — match the
history). Push the branch and open the PR **as a draft** (`gh pr create --draft`) — it stays
a draft while ship iterates below, so no human reviews it prematurely. Give it a body that
explains the *why*, the verification done, and any flagged trade-offs or decisions. Reference
the tracking issue with `Closes #N` so the merge closes it (the linking conventions live in
`/dev-kit:handle-task-tracking`). **Do not add AI attribution.**

### Converge an automated review before handing off

With the draft PR open, request an **automated Copilot review** (GitHub's `request_copilot_review`
via the GitHub MCP or `gh`) and **iterate to convergence**:

1. Wait for Copilot's review to land on the current PR head. While parked on that wait, set
   `state` to `waiting:copilot` so the Stop hook lets the session rest without nagging; re-arm
   the `phase-*` token once the review lands and you pick the work back up.
2. Triage its findings like any reviewer — apply the real ones (commit + push to the same
   branch).
3. **Resolve each thread once you've handled it** — reply with how it was addressed (the
   commit) or, for a declined one, why, then mark the thread resolved (GitHub's
   `resolveReviewThread`). Leaving handled threads open makes the next round and the human's
   final pass ambiguous about what's left.
4. **Re-request the review** so Copilot re-runs against the new head.
5. Repeat until it **converges**: Copilot approves, or its only remaining comments are
   non-actionable (nits already judged, or false positives). Bound the loop — after ~3
   rounds with nothing substantive left, stop and summarize the residue for the human
   rather than chasing nits forever.

This catches what the Phase 6 battery missed on the *actual* PR diff and keeps the branch
green before a person looks. If Copilot review isn't enabled on the repo, note that and skip
— don't block the hand-off on it.

### Hand off

Once the review has converged, **mark the PR ready for review** (`gh pr ready`), set `state`
to `done`, and **hand off** — that flip from draft to ready *is* the hand-off signal. Ship
stops here by default; merging is the human's call. If you instead want ship to take it the
rest of the way, invoke **`land`** (see *Land the PR* below) — at hand-off or any time after
— and ship drives the PR to merged rather than stopping.

**Leave the worktree in place at hand-off.** The change isn't done until it merges: review
feedback may land, and addressing it means more commits *in this worktree*. Tearing it down
now would strand that work and force you to recreate it. Just confirm everything is committed
and pushed (the PR holds all the work) before you stop. The worktree's teardown is the
**post-merge** step below — not hand-off.

## Land the PR (on demand — the one path where ship merges)

`land` is an **explicit, opt-in** verb, never auto-chosen: ship runs it only when the user
asks ("land the PR", "land this", "land #N", "ship and land it"). It is invocable two ways,
neither decided at `/ship`-invocation time:

- **Mid or after a ship run** — the PR for this worktree's branch is already open; "land it"
  drives that PR.
- **Standalone** — with no active ship run, "land the PR" / "land #N" attaches to the current
  branch's open PR (or the named one) and drives it cold.

Both run the same idempotent loop: bring the branch up to date with its base → **watch CI on
the current head, and on any red check fix it, push, and re-watch until green** (bounded —
surface a failure you can't clear rather than thrashing) → run the Phase 8 Copilot
convergence loop → then, instead of stopping at hand-off, **rebase-merge the PR itself**
(`gh pr merge --rebase`, the one place ship merges) → fall straight into Post-merge cleanup
below. The full procedure, including how to locate the PR and the `waiting:ci`/`waiting:copilot`
park states to set while watching, lives in
[`reference/pr-landing-driver.md`](reference/pr-landing-driver.md).

This is **not** GitHub auto-merge — ship holds the merge decision and merges only on green +
converged (the reference spells out what `land` deliberately is *not*).

## Post-merge — clean up (after the merge — land's tail, or when the human reports it)

ship cleans up once the change is merged — whether **`land`** just merged it, or the human
did and says so (e.g. "merged", "I merged it"). Reconcile local state via
**`/dev-kit:cleanup-locally`**:

1. If the session is still inside the ship worktree, **ExitWorktree (`action: "keep"`)**
   first — this returns the session to the primary checkout *without* deleting anything.
   (Don't use `action: "remove"` here: the local default branch hasn't been updated yet, so
   the worktree's commits look un-merged and removal would balk or need force.)
2. From the primary checkout, run **`/dev-kit:cleanup-locally`**. In one verified pass it
   updates the default branch to include the just-merged change (so it now *sees* the merge,
   squash-merge included), removes this change's now-merged worktree, and prunes the merged
   local branch.

Ship's progress/state files lived under the worktree's git dir, so removing the worktree
takes them with it — there's no separate ship-state teardown, and nothing was ever in the
working tree to untrack.

Running keep-then-cleanup — rather than `ExitWorktree({ action: "remove" })` — is what makes
the order work: cleanup-locally refreshes the default branch *before* judging the worktree, so
a squash-merged branch is correctly recognized as merged and torn down. If cleanup-locally
**keeps** the worktree or branch (reports it unmerged, dirty, or still checked out), don't
force it: surface *why* it was kept.

Then **reconcile the tracking issue via `/dev-kit:handle-task-tracking`** — don't assume
`Closes #N` did it. Verify the issue actually closed (a squash that drops the keyword, a
typo'd reference, or an epic with no direct PR can leave it open), close it with a resolution
if not, and **clear its now-stale `status:in-*` progression label** so a closed or
just-merged issue isn't left wearing `status:in-review`. That leftover label is the stale
state that makes `/dev-kit:open-work` misread finished work as still in flight.

## Guardrails

- Plan sign-off (Phase 1) is always the human's, and so is the merge **unless** they
  explicitly invoke **`land`**; everything between is ship's to execute rigorously. By
  default merge happens *after* hand-off and is never a ship phase — `land` is the one
  opt-in path where the human authorizes ship to do the merge itself.
- **A delegated sub-skill's return is a hand-back, not a stop.** When `/simplify`,
  `/dev-kit:generate-docs`, `/dev-kit:review-pr`, or any reviewer under it (`/code-review`,
  `/security-review`, `/pr-review-toolkit:review-pr`) returns, that output reads like
  end-of-turn but is **not** — synthesize it and proceed to the next phase instead of
  yielding. By default the only stops in a ship run are plan sign-off (`gate:plan-signoff`)
  and hand-off (`done`); `land` carries the run past hand-off to the merge before `done`. Keep
  `state` current so the dev-kit Stop hook can backstop a slip.
- Task state is GitHub's job — delegate it to **`/dev-kit:handle-task-tracking`** throughout
  (establish the issue at Phase 1, `in-progress` at Phase 3, `in-review` at Phase 6,
  `Closes #N` at Phase 8, and **reconcile to closed with the `status:in-*` label cleared
  post-merge**). Don't duplicate that lifecycle inside ship.
- If real scope turns out much larger than the ask, stop and check in rather than silently
  ballooning or downgrading the change.
- The phases lean on skills this plugin doesn't ship (`/simplify`, `/dev-kit:generate-docs`,
  `/dev-kit:review-pr`, and the reviewers it calls). If one isn't installed or is denied,
  note the gap and continue — don't fail the whole ship over a missing optional step.
- Keep the ship progress file (`"$(git rev-parse --git-dir)/ship/progress.md"`) and its
  `state` sibling current — the progress file is the resume point if context is compacted,
  and `state` is what the Stop hook reads to tell an active phase from a human gate.
