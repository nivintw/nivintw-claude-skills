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
  off for human review. Not for a trivial one-off commit or a bare "push this". Never
  auto-merges.
---

# ship

The orchestrator for shipping a change well. Run the phases **in order**. The throughline:
keep the human in control at the ends (plan sign-off, final merge) and do rigorous,
token-aware work in the middle. **ship never merges** — it hands off a review-ready PR.

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
- `done` once the change is *handed off* (Phase 8).

The hook blocks a stop **only** while `state` is a `phase-*` token; **every** other value —
`gate:*`, `done`, blank, a stale token, or a typo — lets the stop through. That default-allow
is deliberate: it can never trap you at a human gate, and a forgotten or stale `state` fails
safe instead of nagging. And because active tokens live only in the worktree's git dir, they
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
returns, synthesize it and continue straight to Phase 7 — the only stops in a ship run are
plan sign-off (Phase 1) and hand-off (Phase 8). The dev-kit Stop hook backstops this while
`state` names an active phase, but the discipline is yours.

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

1. Wait for Copilot's review to land on the current PR head.
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
stops here; merging is the human's call (or a later, explicitly-authorized step).

**Leave the worktree in place at hand-off.** The change isn't done until it merges: review
feedback may land, and addressing it means more commits *in this worktree*. Tearing it down
now would strand that work and force you to recreate it. Just confirm everything is committed
and pushed (the PR holds all the work) before you stop. The worktree's teardown is the
**post-merge** step below — not hand-off.

## Post-merge — clean up (when the human reports the merge)

ship doesn't merge, but it does clean up *after* the human does. When the user says the PR
landed (e.g. "merged", "I merged it"), reconcile local state via **`/dev-kit:cleanup-locally`**:

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
force it: surface *why* it was kept. Confirm the tracking issue closed (`Closes #N` usually
handles it on merge); close it explicitly if not.

## Guardrails

- Plan sign-off (Phase 1) and the final merge are the human's; everything between is ship's
  to execute rigorously. Merge happens *after* hand-off — it is never a ship phase.
- **A delegated sub-skill's return is a hand-back, not a stop.** When `/simplify`,
  `/dev-kit:generate-docs`, `/dev-kit:review-pr`, or any reviewer under it (`/code-review`,
  `/security-review`, `/pr-review-toolkit:review-pr`) returns, that output reads like
  end-of-turn but is **not** — synthesize it and proceed to the next phase instead of
  yielding. The only stops in a ship run are plan sign-off (`gate:plan-signoff`) and hand-off
  (`done`); keep `state` current so the dev-kit Stop hook can backstop a slip.
- Task state is GitHub's job — delegate it to **`/dev-kit:handle-task-tracking`** throughout
  (establish the issue at Phase 1, `in-progress` at Phase 3, `in-review` at Phase 6,
  `Closes #N` at Phase 8). Don't duplicate that lifecycle inside ship.
- If real scope turns out much larger than the ask, stop and check in rather than silently
  ballooning or downgrading the change.
- The phases lean on skills this plugin doesn't ship (`/simplify`, `/dev-kit:generate-docs`,
  `/dev-kit:review-pr`, and the reviewers it calls). If one isn't installed or is denied,
  note the gap and continue — don't fail the whole ship over a missing optional step.
- Keep the ship progress file (`"$(git rev-parse --git-dir)/ship/progress.md"`) and its
  `state` sibling current — the progress file is the resume point if context is compacted,
  and `state` is what the Stop hook reads to tell an active phase from a human gate.
