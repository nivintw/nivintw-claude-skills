---
name: ship
description: >-
  Use when the user asks to "ship this", "ship a change/feature/fix", "take this to a PR",
  "open a PR for this", or "run the full dev workflow" — any change worth a planned, reviewed
  PR. Drives idea → review-ready PR through a disciplined workflow: plan + sign-off, an
  isolated worktree, token-conscious implementation (fans out subagents/`/workflows`,
  delegates mechanical work to cheaper tiers), then /simplify, docs, and review. Stops at
  hand-off and never merges unless `land` is granted.
---

# ship

The orchestrator for shipping a change well. Run the phases **in order**. The throughline:
keep the human in control at the ends (plan sign-off, and the merge decision) and do
rigorous, token-aware work in the middle. **By default ship never merges** — it hands off a
review-ready PR. The one exception is the explicit **`land`** verb (see *Land the PR*), where
you authorize ship to drive the PR all the way to merged; absent that, ship always stops at
hand-off. Granting `land` up front also folds Phase 1's plan sign-off into that same grant —
the human still controls both ends, just via one decision instead of two.

## Start of run — reconcile local state (cleanup-locally)

Before anything else, confirm the session is inside a git repository (`git rev-parse
--git-dir`); if not, stop immediately and report that the cwd isn't inside a git repo
(name the path) rather than proceeding — every step below assumes a repo.

Run **`/dev-kit:cleanup-locally`** from the primary checkout. It
fetches, brings the default branch up to date (stashing/rebasing any local work forward,
never clobbering), and prunes branches and `.claude/worktrees/` worktrees whose work has
already merged. Two payoffs: the worktree this run creates in Phase 2 branches off a
*current* base, and the leftovers from previously-shipped work don't pile up. It's
conservative — anything unmerged, dirty, or checked out is kept — so this is always safe to
run first. If it isn't installed, note the gap and continue.

Also **reconcile the tracker** for the issue(s) this run is about — `handle-task-tracking`'s
reconcile pass, kept cheap and scoped to the issues in play — so a stale `status:blocked` (its
blocker already closed) or a `status:in-*` outliving a merged PR is corrected before the run
starts rather than discovered later. The post-merge cleanup reconciles again once the PR lands.

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

## Phase 1 — Plan (the plan itself is never skipped; the sign-off is conditional)

Never skip writing the plan. Understand the ask, then **fan out `Explore` subagents**
(read-only) to map the relevant code, patterns, and prior art — so the main context stays
lean. Write a concrete plan + checklist into the progress file: what changes, which files,
the approach, risks, and how it'll be verified. **Get the user's sign-off on the plan before
implementing** — unless `land` was already granted, in which case that grant *is* the
sign-off (see next). Surface genuine decisions now (don't bury them).

**When the ask itself already says "ship and land it," "land these," or similar** — not
bare `ship` — that grant satisfies the sign-off above, for the plan and for every
design/approach choice made while executing it. Still write the plan into the progress file
exactly as above (and the batch-grouping proposal, if this is a batch — see below), but don't
block on it: skip past `gate:plan-signoff` and
proceed straight to Phase 2. Treat every decision that would otherwise need a check-in the
same way for the rest of the run — pick the reasonable default, log it (see *Decisions made
without asking* under Phase 8), and keep going, including when a delegated sub-flow would
normally surface its own approach question (e.g. a plan-execution choice) — decide it
yourself and log it rather than passing the question along. This carve-out is scoped to
*how* to build the agreed plan, never to *whether* the plan itself still fits: it doesn't
relax destructive/irreversible actions (force-push, hard resets, deletions), and it doesn't
relax **"Confirm scope before you build it"** below or the Guardrails' **"if real scope
turns out much larger than the ask, stop and check in"** — discovering the ask is actually
bigger, or conflicts with itself in a way no default resolves, isn't a design choice to log
and proceed past; it's the same "genuinely blocked, still ask" category destructive actions
fall into, just for scope instead of git safety.

### Batching multiple items into minimal PRs

When the request names more than one discrete item (several issue numbers, "these five," "the
batch"), auto-detect it as a batch — no special phrasing needed beyond that, and independent of
whether `land` was granted. Whether one PR vs. several is the right split is a
**release/repo-topology question, not a merge-authority question** — decide it the same way
either way: check the repo's own release/version tooling and merge convention first (this
repo's per-item conventional commits + rebase-merge already let release-please attribute
version bumps correctly across multiple plugin paths inside one PR, so combining rarely costs
anything real *here*; a repo with a single-package release process, a different release tool,
or squash-only merges may genuinely lose something by combining — weigh that before
defaulting). Default to **one PR for the whole batch** when that weighing comes out clean;
split out a piece only for a concrete risk-isolation reason — a change unusually large, risky,
or hard to revert relative to the rest of the batch — never for mere topical variety, and never
because `land` was or wasn't granted.

`land` governs one thing only: whether ship drives the resulting PR(s) to merge, never whether
they're batched together in the first place. A bare `ship` batch (no `land`) can still land on
one combined PR when the criteria above call for it — propose the grouping, including any split
and why, as part of the Phase 1 plan and get sign-off on it like any other plan decision, rather
than silently defaulting to one PR per item. A `land`-granted batch of unrelated items can just
as validly land on several separate PRs when the criteria call for that: log the grouping
choice, including any split and why, as a decision made without asking (Phase 8) in **each**
resulting PR's body (not just one — a batch that splits into several PRs means several bodies
to keep in sync), and — since a grouping choice spans the whole batch, not a single issue —
mirror it onto **every tracking issue involved**, not just one, rather than silently combining
into one just because `land` was granted.

**Confirm scope before you build it.** A description of a desired end-state is not a license
to build everything around it. In the plan, separate what the user is **describing as
requirements** ("here's what needs to work") from the **work to do now**, and confirm the
change that actually fits the ask before fanning out implementation — don't wrap validation,
config scaffolding, or speculative machinery around a request the user wanted kept small. When
the user says they'll wire it up, configure it, or edit it themselves, leave the relevant
files as **editable scaffolding** rather than fully implementing them. This is the global
*match the change to the request's real scope* rule applied at plan time, and it cuts **both**
ways: size the change to the *true* breadth of the ask, **not its literal minimum** —
over-building a small request and silently downgrading a broad one (a docs refresh, an audit,
a "make this right" that should also fix the in-domain mess) are equally failures. When unsure
which side of the line something falls on, ask rather than assume.

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

This is the phase where a delegated sub-flow is most likely to surface its own approach
question (e.g. a plan-execution choice) — Phase 1's `land` carve-out already covers it.

**Strip conversation-only comments.** Comments that only make sense given this session's
conversation — justifications aimed at the reviewer-in-the-moment (e.g. "no hardcoded key
name as we discussed") — do not belong in shipped code; they are noise to a future reader.
Write comments that stand on their own without this session as context.

Update the progress file and make **checkpoint commits** as coherent pieces land. As work
starts, flip the tracking issue to `status:in-progress` (via `/dev-kit:handle-task-tracking`)
and log notable decisions on it as they're made.

**Re-read the working tree at phase boundaries — the user may have edited it.** ship runs in
a worktree the user can open and change too. At each phase boundary (the same moment you
update the progress file), check both the working tree **and the branch's commits** *before*
acting — `git status` and `git diff HEAD` catch *uncommitted* edits (staged or not), but the
user may have *committed* their work, so also diff the branch against its base
(`git diff <base>...HEAD` / `git log <base>..HEAD`) or you'll read a clean tree and wrongly
conclude nothing changed. Then
**reconcile to whatever the user changed** rather than regenerating from your own plan — a
plan is a starting point, not a contract that outranks the user's own edits. When the user
says *"take a look at what I did"* / *"look at what I changed,"* their files in the worktree
are **authoritative**: read them, build on top of them, and never overwrite them with your
version of the same work. If their edits change the shape of the task, update the plan and the
progress file to match instead of pushing your original through.

## Phase 4 — Simplify (always)

Run **`/simplify`** on the change before any review. Quality-only cleanup (reuse,
simplification, efficiency, altitude) while everything is fresh. **A suppression is not a
cleanup**: if the change (or `/simplify` itself) adds a `# noqa`, `# type: ignore`, a broad
`per-file-ignores` entry, or similar to quiet a check instead of fixing it, treat that as a
finding — justify it with a one-line rationale or remove it and fix the underlying issue.
Likewise, **conversation-only comments** left over from the implement phase should be removed
here — they are not documentation; the `comment-analyzer` agent (from `pr-review-toolkit`,
invoked inside Phase 6's battery, not a slash command) can enforce this. Separately, Phase
6's `/dev-kit:review-pr` enforces the same standing no-suppressions rule on the PR diff.

## Phase 5 — Docs (default; skip only if no docs site)

Run **`/dev-kit:generate-docs`** so the docs never drift from the change. It reconciles the
whole docs set against the whole codebase and shapes the site to the repo kind (marketplace,
Copier template, library/CLI, or generic), so it applies to any repo — only skip if the repo
genuinely has no docs to maintain. Default to keeping docs current.

## Phase 6 — Review (always; breadth scaled to the diff)

Run **`/dev-kit:review-pr`** (Mode A — your own change). The review itself never skips, but
its **breadth scales to what the diff touches** — judged in the same *stakes ×
verification-cost × reasoning-depth* terms as Phase 3, **not by file count**.
`/dev-kit:review-pr` already right-sizes internally; Phase 6's job is to hand it an honest
read of the diff's risk surface and hold this floor:

- **Always:** `/code-review` plus `/dev-kit:review-pr`'s own core pass. Every change is
  reviewed — the gate scales *which extra passes run*, never *whether* review happens.
- **`/security-review`:** always for any diff touching a security-sensitive surface — auth,
  input handling, secrets, network, deserialization, file/path, permissions — **or** any
  non-trivial code change. Skip it **only** for docs-, prose-, or comment-only changes and
  cosmetic config. A one-line change is *not* automatically safe: gate on what it touches,
  not how big it is.
- **Context-chosen adversarial pass:** reserved for cross-cutting, higher-risk, or
  non-trivial logic changes. Skip it for docs-only and tiny, localized edits that can't
  change behavior.

Then synthesize one prioritized report. Apply the must-fixes; re-run as needed; leave the
branch green. Flip the tracking issue to `status:in-review` (via
`/dev-kit:handle-task-tracking`) once the change is up for review.

**`/dev-kit:review-pr` and the reviewers under it return *hand-backs*, not stopping points.**
`/security-review` is the most frequent trap: it returns a self-contained markdown report
that *looks* like a terminal deliverable, so the pull is to yield. Don't. When the review pass
returns, synthesize it and continue straight to Phase 7 — the only stops in a default ship
run are plan sign-off (Phase 1) and hand-off (Phase 8); under `land` granted up front, Phase
1's stop doesn't happen at all (its own carve-out), and the run continues past hand-off
through merge to cleanup instead of stopping there either. The dev-kit Stop hook backstops
this while `state` names an
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

### Decisions made without asking (under `land`)

When Phase 1's `land` carve-out was in effect for this run, the PR body gets a **required,
fixed section: `## Decisions made without asking`.** This is the retrieval point — a
brand-new session, days later, must be able to answer "what did you decide and why" from the
PR (or the tracking issue) alone, with no dependency on this conversation. Rules:

- **Always present**, even when there was nothing to decide — write "None — every choice
  matched the plan already discussed" rather than omitting the heading. Its absence must
  never be ambiguous between "nothing happened" and "forgot to document."
- **Built up incrementally** as decisions happen during the run (checkpoint commits already
  touch the PR description in-flight) — not authored once at hand-off from memory.
- **One bullet per decision**: what was decided, why (including any rejected alternative),
  and what's worth double-checking.
- **Mirrored on the tracking issue** — each decision gets a `Decision:`-prefixed bullet in an
  issue comment, so it's greppable via `gh issue view <N> --json comments` without reading
  full history. Multiple decisions from the same checkpoint can share one comment (several
  `Decision:` bullets in it) rather than one round-trip each — the requirement is that every
  decision is logged there, not one API call per decision. Posting the comment at all builds
  on `/dev-kit:handle-task-tracking`'s existing "post a comment when a decision is made"
  habit; the `Decision:` prefix and the hard (not soft) requirement to log *every* decision
  are new here, specific to `land`. **When a PR closes more than one
  tracking issue** (a batch, per the section above), post batch-level decisions — the
  grouping choice, what got split out — on **every** issue the PR closes, not just one:
  each issue is a place someone might look, and the retrieval guarantee (any one of them,
  alone, must answer "what did you decide and why") fails if the record only lives on one.

### Converge an automated review before handing off

> **This section and *Hand off* run unconditionally — in *every* ship run, `land` or not.**
> Converging the review and flipping draft → ready are Phase 8 steps that always happen; `land`
> only changes what happens *after* hand-off (continue to merge vs. stop). Don't pause to ask
> permission before these steps just because `land` was granted — the section that follows
> (*Land the PR*) describes the tail past hand-off, not a gate on these steps. The **only**
> expected reason to pause mid-Phase-8 under `land` is a tool/permission-system block (e.g. an
> auto-mode classifier denying a specific `gh pr merge`); when that happens, surface that
> specific block rather than turning it into a standing "ask before this class of action" habit
> for the rest of the run. A routine draft→ready flip (`gh pr ready`) is reversible and is not
> that pause.

With the draft PR open, request an **automated Copilot review** (GitHub's `request_copilot_review`
via the GitHub MCP or `gh`) and **iterate to convergence**. Before you touch the API, read
[`reference/watch-and-review.md`](reference/watch-and-review.md) for the request/detection traps
that make this silently fail regardless of state — `gh pr edit --add-reviewer copilot` is a
**silent no-op** (use `request_copilot_review`); the posted review is authored by
`copilot-pull-request-reviewer[bot]` (a *different* login from the one Copilot holds in
`requested_reviewers`); GraphQL `reviewRequests` omits the bot; and a review has **two parts**
(summary body + inline comments) — parse both. The request resolves into one of
three states — tell them apart by two signals: whether Copilot is in the PR's
**`requested_reviewers`** (a PR-level flag, not tied to a head), and whether a **review**
exists *for the current head SHA* — not by "did a review show up yet":

- **(a) Copilot can't review this PR** — either the request to add Copilot as a reviewer is
  **rejected** (a lapsed subscription, or the feature is off for the repo), *or* it's accepted
  but **no review ever posts within the bounded window** below (org policy, an unsupported or
  oversized diff, a bot-side error). Both are "unavailable." Surface it plainly — *"Copilot
  review isn't available — check your Copilot access for this repo"* — and **skip the loop**:
  don't poll for a review that won't arrive, and don't block hand-off (or, under `land`, the
  merge) on it.
- **(b) Copilot is a requested reviewer but hasn't posted on the current head yet** — the one
  state you wait in, but **bound it**: keep a harness-tracked watch on the current head for a
  finite window (a few rounds), not an open-ended busy-loop. If the window elapses with no
  review, fall through to (a) — assigned-but-silent is just unavailability you detect by
  timeout.
- **(c) a review is present *on the current head*** — confirm the review's commit matches the
  current head SHA (a review left on a previous push is **stale**, not convergence), then parse
  it and proceed to triage.

**Never declare "unavailable" until you've checked the PR's `requested_reviewers` *and*
confirmed no review exists for the current head SHA, with the bounded window elapsed.** The
*reviews* list being empty fits both (a) and (b), so it can't separate them on its own — the
signal that tells "assigned, still pending" from "can't review" is whether Copilot is a
requested reviewer (and whether the request call succeeded), backed by the bounded-window
timeout above. A review *on the current head* means state (c), not unavailable — so confirm
its absence before you skip. Then iterate:

1. While parked waiting for a review to land on the current head (state b), set `state` to
   `waiting:copilot` **only once a self-resuming background watch is actually running** — the
   same "never a bare stop" rule the land loop states. The mechanism is
   [`scripts/wait-for-copilot-review.sh`](scripts/wait-for-copilot-review.sh) run with
   `run_in_background: true` (the review-side parallel to `gh pr checks --watch` for CI); its
   exit re-invokes the session. A timed **`ScheduleWakeup` is explicitly ruled out** — it does
   not generate a completion event and has stranded a merge-ready PR for hours; see
   [`reference/watch-and-review.md`](reference/watch-and-review.md) for the wait-primitive table
   and the silence-≠-success / wake-≠-verdict rules. Re-arm the `phase-*` token once the review
   lands and you pick the work back up.
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
green before a person looks (state a above is where you skip it cleanly when Copilot can't
review at all).

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
asks ("land the PR", "land this", "land #N", "ship and land it"). Most often it's granted
**up front, at `/ship`-invocation time** ("ship and land it") — see Phase 1's carve-out for
what that changes about the run itself. It can also be granted later, independently of when
`ship` started:

- **Mid or after a ship run** — the PR for this worktree's branch is already open; "land it"
  drives that PR.
- **Standalone** — with no active ship run, "land the PR" / "land #N" attaches to the current
  branch's open PR (or the named one) and drives it cold.

The "decide it, log it, don't ask" principle applies here too, however `land` was invoked —
including standalone, after the fact: CI fixes, review triage, and any other call this loop
has to make get decided and logged (Phase 8's *Decisions made without asking*), not asked
about. (Phase 1's plan-sign-off folding specifically only applies when `land` was granted
up front, before Phase 1 ran — a standalone invocation happens after the plan already
shipped, so there's no sign-off left to fold; the logging discipline is what carries over.)
If the PR predates this run (a standalone
`land #N` on a PR ship never authored, or one from before this convention existed) and has no
`## Decisions made without asking` section yet, **create it** rather than assuming it's
already there — the logging requirement doesn't depend on how the PR was opened.

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

**Optional — release-gated merges only:** if the PR that just merged was a **release-please
Release PR** (`chore(main): release …` / `chore(<pkg>): release …`), optionally **watch the
release**: poll for the new `<plugin>-v<version>` tag + GitHub Release that `main.yml` cuts
asynchronously, report the version and release notes when it lands, then confirm the closed
issues via `/dev-kit:handle-task-tracking`. The full mechanic — including how to set up a
self-deleting poll cron so the session doesn't block — lives in
[`reference/release-watch.md`](reference/release-watch.md). Skip this for all normal
feature/fix merges: release-please cuts no tag then, and the poll would run indefinitely.

## Guardrails

- Plan sign-off (Phase 1) and the merge are both the human's **unless** they explicitly
  invoke **`land`** — that single grant covers both (see Phase 1's carve-out). Everything
  between is ship's to execute rigorously. By default merge happens *after* hand-off and is
  never a ship phase; `land` is the one opt-in path that changes that.
- **A delegated sub-skill's return is a hand-back, not a stop.** When `/simplify`,
  `/dev-kit:generate-docs`, `/dev-kit:review-pr`, or any reviewer under it (`/code-review`,
  `/security-review`, `/pr-review-toolkit:review-pr`) returns, that output reads like
  end-of-turn but is **not** — synthesize it and proceed to the next phase instead of
  yielding. By default the only stops in a ship run are plan sign-off (`gate:plan-signoff`)
  and hand-off (`done`); `land` granted up front skips the first stop entirely (Phase 1's
  carve-out) and carries the run past the second, through to the merge, before `done`. Keep
  `state` current so the dev-kit Stop hook can backstop a slip.
- Task state is GitHub's job — delegate it to **`/dev-kit:handle-task-tracking`** throughout
  (establish the issue at Phase 1, `in-progress` at Phase 3, `in-review` at Phase 6,
  `Closes #N` at Phase 8, and **reconcile to closed with the `status:in-*` label cleared
  post-merge**). Don't duplicate that lifecycle inside ship.
- If real scope turns out much larger than the ask, stop and check in rather than silently
  ballooning or downgrading the change.
- **The user's edits in the worktree are authoritative.** From Phase 3 onward (inside the
  worktree), at each phase boundary re-read both the working tree and the branch's commits
  (`git status` / `git diff HEAD` / `git diff <base>...HEAD`) and reconcile to the user's
  changes instead of regenerating your own; "look at what I did" means treat their files as the
  source of truth, not your plan.
- The phases lean on skills this plugin doesn't ship (`/simplify`, `/dev-kit:generate-docs`,
  `/dev-kit:review-pr`, and the reviewers it calls). If one isn't installed or is denied,
  note the gap and continue — don't fail the whole ship over a missing optional step.
- Keep the ship progress file (`"$(git rev-parse --git-dir)/ship/progress.md"`) and its
  `state` sibling current — the progress file is the resume point if context is compacted,
  and `state` is what the Stop hook reads to tell an active phase from a human gate.
