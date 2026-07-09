---
name: fleet-ship
description: >-
  Use when the user asks to "ship a batch across repos", "coordinate a fleet ship", or hands
  over issues living in more than one repository to drive together — especially a cross-repo
  chain like a copier-everything template change plus the downstream `copier update` adoptions
  it enables. The CROSS-REPO layer above /dev-kit:ship: where ship batches within ONE repo,
  fleet-ship coordinates a set spanning MULTIPLE — per-repo worktrees + PRs,
  dependency-ordered (upstream-before-downstream), and review-deduplicated (the source change
  is reviewed once; downstream PRs review only the adoption diff). Reuses ship's batching and
  HITL model. Not for a single-repo batch (that's ship's Phase 1).
---

# fleet-ship

The **cross-repo coordinator** above `ship`. `ship` already batches multiple issues in a single
repo into one worktree, one PR, one review pass (its *Batching multiple items into minimal PRs*,
Phase 1). `fleet-ship` is the layer above that: hand it a set of issues that spans **several
repos** and it drives the whole thing — per-repo worktrees and PRs, ordered by cross-repo
dependencies, with shared logic reviewed once instead of once per repo.

It **coordinates and sequences** per-repo `ship` runs; it does not reimplement them. Every
single-repo concern — the worktree, the plan, tiered implementation, `/simplify`, docs,
`/dev-kit:review-pr`, the gate, the PR, Copilot convergence, and (under `land`) the merge — is
`ship`'s, run per repo. fleet-ship owns only what's genuinely cross-repo: **grouping, ordering,
review-dedup, and continuation state.**

## When to reach for it (and when not)

- **Use it** when the issue set spans **2+ repos**, especially with real cross-repo chains — a
  `copier-everything` template change and the downstream repos' `copier update` adoptions; a
  fleet-wide migration that lands in an upstream repo and is then adopted everywhere.
- **Don't** use it for a batch that lives in one repo — that's `ship`'s own Phase 1 batching.
  fleet-ship with a single repo is just `ship`; the coordination overhead buys nothing.

## Flow

### 1. Scope + group by repo

Take the issue set and partition it by repo. For each repo, the issues destined for it become
one (or a few) `ship` single-repo batches — exactly what `ship` Phase 1 already decides. State
the grouping up front, per repo, as part of the fleet plan.

### 2. Order across repos by dependency (the load-bearing step)

Build the cross-repo dependency graph and **topologically order** the repos. The rule:
**upstream before downstream — never ship a downstream adoption before the thing it adopts
exists.** The canonical chain:

- A `copier-everything` **template change must land AND cut its release first**; only then can
  the downstream repos run their `copier update` adoption issues against a template version that
  actually contains the change.
- More generally: a shared source change lands (and, where a release/tag gates consumers, is
  released) **before** any repo that consumes it. Encode the "release the template, then adopt
  it" wait explicitly — a downstream repo's run must block until its upstream dependency is
  merged (and released, if release-gated), not merely opened.

Repos with no dependency between them run in parallel; a dependency edge serializes them.

### 3. Execute per repo, in order — reuse ship, don't duplicate

For each repo, in dependency order, run **`ship`'s single-repo batch** in that repo's **own
worktree**, producing that repo's **own PR** against its **own gate / CI / release-please**
(each repo keeps its independent per-repo release process). Nothing about a repo's own pipeline
changes — fleet-ship only decides *when* each repo's run starts, gated on its upstream
dependencies.

- **`ship`-only vs `land`-granted.** A fleet batch can hand off each PR for human merge
  (`ship` default) or, under **`land`**, drive each PR to a merged state in dependency order — the same
  `/dev-kit:land` verb, applied per repo. Under `land`, a downstream repo's run doesn't start
  until its upstream PR is **merged** (and released if release-gated); under `ship`-only, the
  human merges each in order and fleet-ship surfaces the ordering they must follow.

### 4. Deduplicate review across repos

Review the **source** change **once** — in the upstream repo's PR, via that run's normal
`/dev-kit:review-pr`. Downstream **adoption** PRs then review only the **adoption diff** (the
`copier update` result, the wiring, the local reconciliation), **not** the upstream logic again.
Re-reviewing identical logic in every downstream repo is the redundant cost fleet-ship exists to
remove — carry the upstream review's verdict forward and scope each downstream review to what's
actually new in that repo.

### 5. Continuation state — shard per arming-session token, ALWAYS

A cross-repo batch must survive **worktree teardown** (each repo's worktree is torn down as its
PR lands) and run **from any cwd** (it spans repos, so it can't key off one repo's git dir the
way `ship` keys its per-repo `state` to `$(git rev-parse --git-dir)/ship/`). That pushes any
continuation gate toward **user-global** scope (e.g. under `~/.claude`) — and **user-global
scope IS the collision surface.**

**Mandatory lesson (from the internal fork's DSAI-1754):** a prior cross-repo batch mechanism
*looked* sharded — its markers were named like `$state/$TOKEN.active` — but a **hardcoded
`TOKEN="batch"` collapsed every session's marker to one global `batch.active`**, so two
concurrent same-user sessions clobbered each other's batch. The per-session token existed (minted
for Stop-hook attribution) but **was never wired into the marker filenames** — a
"reads-as-parameterized, defeated-by-a-hardcoded-default" failure you cannot catch by scanning
the naming logic, only by resolving what the variable actually holds.

So, from day one:

- If a user-global continuation gate is used, **shard it per arming-session token**: the arming
  session mints a token and writes **only** that token's `batch.<token>.*` markers, never
  inheriting or clobbering another session's. **The token IS the owner.**
- **Never a hardcoded constant** in the marker path. Verify the token variable's *resolved
  value* varies per session, not just that the path *looks* parameterized.
- Record which repos' runs are pending / in-flight / merged in that per-token state, so a
  compaction or a walk-away can resume the fleet exactly where it paused.

### 6. Human-in-the-loop boundaries — preserved, not bypassed

fleet-ship coordinates; it does not lower the bar.

- **Plan sign-off** happens once, up front, for the **whole fleet plan** — the grouping, the
  cross-repo order, and (if requested) the `land` grant — the same explicit sign-off `ship`
  Phase 1 takes, lifted to the fleet level. `land` granted up front carries the same
  "decide-and-log, don't re-confirm" semantics `ship`/`land` already define, applied per repo.
- **Merge / `land` decisions** stay gated per the `ship`/`land` model. Under `ship`-only,
  fleet-ship never merges — it hands off each PR and tells the human the dependency order. Under
  `land`, it merges per repo, still only on green CI + converged review, exactly as
  `/dev-kit:land` does.

## What it reuses (never reimplements)

- **`ship` Phase 1** — the single-repo batch (issues → worktree → PR) is run per repo, unchanged.
- **`/dev-kit:land`** — the per-repo merge verb, for a `land`-granted fleet batch.
- **`/dev-kit:review-pr`** — each repo's review; fleet-ship only deduplicates *across* repos.
- **`/dev-kit:handle-task-tracking`** — issue lifecycle + cross-repo linking, per repo.

Relates to `repo-management`, which already reasons about the fleet as a whole (for settings);
fleet-ship is the *execution* counterpart for a coordinated cross-repo change.

## Scope note

This skill defines the **coordinator shape**. Concrete sub-mechanisms it implies — the exact
per-token continuation-state file format and its Stop-hook wiring, the release-gate wait
primitive for "template released, now adopt," and the review-carry-forward record — are worth
decomposing into their own sub-issues and landing incrementally, rather than building all at
once. The invariants above (dependency order, per-token sharding, review-dedup, preserved HITL)
are the non-negotiable parts any such build must hold.
