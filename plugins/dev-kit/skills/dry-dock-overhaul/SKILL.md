---
name: dry-dock-overhaul
description: >-
  This skill should be used when the user asks for a "dry dock overhaul", to "audit the whole
  repo", "deep audit this codebase", "review every line", "do a full repo review", "is this
  repo well organized", or wants an exhaustive, occasional health check of an entire
  repository rather than a diff. It reads every tracked source file and judges it, discovers
  and runs whatever "10,000-foot" communication/UX questions actually matter for this
  specific repo (docs-site UX, test-suite architecture, naming consistency, or whatever else
  the repo's shape calls for), and orchestrates /dev-kit:review-pr (Mode C),
  /dev-kit:generate-docs, and /dev-kit:pre-public-hardening alongside those net-new
  dimensions. Produces one ephemeral, severity-ranked report — nothing it newly finds gets
  auto-applied (generate-docs's own native writes are the one exception). Always
  human-triggered; no other skill should invoke it automatically. This is the most expensive
  skill in the marketplace by design — reach for it rarely, and on purpose.
---

# dry-dock-overhaul

Haul the whole repo out of the water and inspect every plank. This skill runs an exhaustive,
occasional, always-human-triggered audit of an entire repository: every tracked source file
(respecting `.gitignore` — generated, vendored, and binary artifacts are out of scope) is
genuinely read and judged by some agent, not sampled, plus a "10,000-foot" pass that asks
whether the repo *communicates* well — is the docs site good UX, is the test suite
well-architected, is terminology used consistently — discovered fresh for whatever this
specific repo actually is, not read off a fixed checklist. On top of that net-new coverage,
it orchestrates the three whole-repo-capable skills this marketplace already has —
`/dev-kit:review-pr` (Mode C), `/dev-kit:generate-docs`, and `/dev-kit:pre-public-hardening`
— so one run produces a single, severity-ranked report spanning correctness, security,
hygiene, code justification, test architecture, and communication together. This is
deliberately the most expensive skill in the marketplace — a "dry dock" operation the human
schedules rarely and on purpose, never something another skill reaches for automatically.

## What this is not

- **Not a PR review.** Judging a diff against a base branch is `/dev-kit:review-pr`. This
  skill judges the whole repo as it stands today, with no diff in sight — and it invokes
  `review-pr`'s own whole-repo Mode C as one of its four passes rather than re-deriving that
  logic.
- **Not a docs refresh.** Reconciling the docs set against the code and fixing drift is
  `/dev-kit:generate-docs`'s job, and it keeps doing that job natively here — this skill adds
  an independent second opinion on docs-site *UX*, judged holistically, on top of
  `generate-docs`'s own drift-and-omission reconciliation.
- **Not a to-do list, and not a tracker.** Every new dimension this skill judges is
  report-only — nothing gets auto-applied (`generate-docs`'s own native writes are the one
  exception, and they're its behavior, not this skill's finding — see Phase 4). The report
  itself is never committed; a human who wants a finding tracked files it themselves via
  `/dev-kit:handle-task-tracking`.

## Core philosophy

These are operating rules for every run, not history:

- **Repo-agnostic, always.** Never assume this skill is auditing this specific marketplace.
  Classify the target repo the same way `generate-docs` does — reuse its sentinel-file
  classification (see `generate-docs`'s [Stage 0 — Inventory &
  classify](../generate-docs/SKILL.md)) rather than redefining repo-kind detection here.
- **Exhaustive coverage is non-negotiable.** Every tracked, `.gitignore`-respecting file gets
  read and judged by some agent. Being cost-conscious means routing mechanical work (building
  the inventory, cheap candidate detection) to a fast or local tier and reserving expensive
  reasoning for genuine judgment — it never means sampling or skipping files.
- **Report-only for every new dimension.** Code justification, test-suite architecture, and
  the 10,000-foot communication pass are all findings-only; the human triages every one.
  `generate-docs` writing its own fixes directly to disk is not an exception to this rule —
  it's `generate-docs`'s own already-established native behavior, preserved as-is because it
  isn't this skill's finding to withhold.
- **Compose, don't reimplement.** `review-pr` Mode C, `generate-docs`, and
  `pre-public-hardening` always run in full as sub-passes (Phase 4) — this skill adds the
  net-new dimensions above and around them; it never re-derives what they already do well.
- **Discovery over enumeration for the 10,000-foot pass.** The specific holistic lenses (test
  suite shape, docs UX, naming consistency, or anything else) are **not a fixed list baked
  into this file**. They're proposed at run time from what the target repo actually contains.
  Anything in `reference/lens-examples.md` is an illustrative example, never a checklist to
  enumerate against.
- **Ephemeral by design.** The report is a conversational deliverable. It is never committed.
  If a finding is worth tracking past this conversation, the human files it themselves via
  `/dev-kit:handle-task-tracking`.

## Phase 0 — Classify & scope

Confirm the session is inside a git repository (`git rev-parse --git-dir`); if not, stop
immediately and report that the cwd isn't inside a git repo, matching `ship`'s own hard stop
— every phase below assumes a repo.

Resolve scope: the repo root by default, or a human-supplied subtree/plugin path argument
(e.g. `plugins/castify/`). Everything downstream — the unit map, the sub-passes that support
narrowing, the report's own scope header — is stated in terms of whatever this step resolves.

Classify the repo's kind by reusing `generate-docs`'s own sentinel-file classification
(marketplace, Copier template, library/CLI, or generic) rather than redefining that logic
here — see `generate-docs`'s Stage 0 in [`../generate-docs/SKILL.md`](../generate-docs/SKILL.md).
This classification is what later phases mean by "**Phase 0's classification**": it decides
what a "unit" is in Phase 1, and it's one of the two inputs Phase 3's discovery step reasons
from.

Also detect, once, up front: which test framework(s) the repo uses (if any), and whether a
docs site exists. Both are inputs to Phase 3's discovery step, not findings in their own
right — a repo with no docs site simply yields no docs-UX lens later, and a repo with no
tests at all is itself a candidate finding rather than a detection failure.

## Phase 1 — Inventory (cheap/local tier)

Build the **unit map** — the one artifact every later phase refers to by this name. A "unit"
is this repo's own natural seam, decided by Phase 0's classification: one unit per plugin in
a marketplace, one per top-level package in a library, a language-appropriate directory
heuristic in a generic repo. Only tracked, `.gitignore`-respecting files are in scope for the
unit map and everything built from it — generated output, vendored dependencies, and binary
artifacts sit outside the exhaustive-coverage guarantee, the same boundary git itself already
draws.

For each unit, gather its file list, a rough size, and cheap mechanical candidate-detection —
files with zero inbound references, obvious dead exports, TODO/FIXME density — via
grep/reference-analysis, routed to a fast or local model. **Batch multiple units per agent
here, do not spin up one agent per unit**: this stage's work is lightweight and grep-based,
not a full read-and-judge, so a small number of agents can each cover several units, keeping
Phase 1's own agent count well below what Phase 2 needs (contrast this deliberately with
Phase 2's one-agent-per-unit granularity below — the two phases are tuned differently on
purpose, not inconsistently).

This stage's output is **candidates, not findings**. A "zero inbound references" hit can be a
false positive — dynamic loading, plugin-discovery-by-convention — so nothing here is reported
as-is; Phase 2 confirms or dismisses every candidate using the full context of the unit it
belongs to.

**Phase 1 runs to completion as one discrete stage before Phase 2 or Phase 3 begins.** Both of
those need the *whole* unit map — Phase 2 to assign one unit per agent, Phase 3 to reason
about repo-wide shape — so there is no streaming or partial hand-off out of Phase 1.

## Phase 2 — Deep-dive per unit (pipelined, mid/top tier)

One agent per unit — the one phase where per-unit granularity is worth the agent cost, since
this is the actual exhaustive read-and-judge work the whole skill exists to guarantee. Each
agent reads **every file in its unit** and reports exceptions only: unjustified, dead, or
redundant code; unclear structure; and, for each of Phase 1's candidates that fall inside this
unit, a confirm-or-dismiss verdict. Clean, justified code produces no report entry — silence
is the expected outcome for a healthy unit, not a gap in coverage.

The same agent also judges its unit's own colocated tests (if any) for redundancy, and its own
code/comment/docstring clarity — both scoped strictly to that one unit, not the whole
repo's test suite (that's a Phase 3 lens, judged holistically, not duplicated here).

Units are pipelined **relative to each other** — no barrier between one unit's agent starting
and the next, since units are independent of one another — but **not** relative to Phase 1,
which must already have run to completion before any Phase 2 agent starts (see above): a
Phase 2 agent needs Phase 1's candidate list for its own unit before it can render each
candidate's confirm-or-dismiss verdict.
