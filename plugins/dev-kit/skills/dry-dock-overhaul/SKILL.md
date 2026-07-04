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
is genuinely read and judged by some agent, not sampled — `.gitignore`-excluded and untracked
paths (generated, vendored, and binary artifacts) are out of scope — plus a "10,000-foot" pass
that asks
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
  report-only (see *Report-only for every new dimension* under Core philosophy below). The
  report itself is never committed; a human who wants a finding tracked files it themselves
  via `/dev-kit:handle-task-tracking`.

## Core philosophy

These are operating rules for every run, not history:

- **Repo-agnostic, always.** Never assume this skill is auditing this specific marketplace —
  it classifies whatever repo it's pointed at (see Phase 0 below for how).
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
  into this file** — they're proposed at run time from what the target repo actually contains
  (see Phase 3 below).
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
grep/reference-analysis, routed to a fast or local model. This is the same batched,
cheap-tier subsystem fan-out `generate-docs` already uses in its own Stage 1 (see
[`../generate-docs/SKILL.md`](../generate-docs/SKILL.md)) to cover a whole codebase without
blowing context — this phase's "unit" is that same slice, just gathering candidates instead
of documentable facts. **Batch multiple units per agent here, do not spin up one agent per
unit**: this stage's work is lightweight and grep-based,
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

## Phase 3 — 10,000-foot discovery, then holistic passes (parallel with Phase 2)

Start with a discovery step that asks **"what whole-repo-level questions actually matter for
this specific repo?"**, informed by **Phase 0's classification** and **Phase 1's inventory**
(the unit map) — never from a fixed list baked into this file. Phase 3 needs only that
context, not Phase 2's per-unit output, so it starts as soon as Phase 1 completes and runs
fully in parallel with Phase 2 rather than behind a barrier on it.

Discovered lenses are concerns that only make sense judged **holistically**, across the whole
repo, not per unit: whole-test-suite structure and cross-unit DRYness (distinct from Phase
2's per-unit test judgment, which stays scoped to one unit's own colocated tests); docs-site
UX as an **independent second opinion** — judged fresh, not anchored to `generate-docs`'s own
self-assessment of that same site; naming and terminology consistency across the whole
codebase; or whatever else this specific repo's shape actually calls for (e.g. a CLI-shaped
repo might instead surface a lens on its flag/config surface's internal consistency). A repo
with no docs site simply gets no docs-UX lens — the absence of a lens is a correct outcome,
not a gap. Each discovered lens becomes its own agent, run in parallel with the rest.

See [`reference/lens-examples.md`](reference/lens-examples.md) for illustrative examples of
what a lens can look like. Treat that file strictly as inspiration for the *kind* of question
worth asking — **not** as a checklist to enumerate against; the discovery step must propose
lenses from what this repo actually contains, even when that means proposing something none
of the examples cover, or dropping a lens the examples show for a repo that doesn't have the
shape it applies to.

## Phase 4 — Existing sub-passes (parallel, fully independent)

Invoke the three existing whole-repo-capable skills — `review-pr` (Mode C), `generate-docs`,
and `pre-public-hardening` — always all three, with no toggle to skip any of them for a
lighter-weight run. All three are fully independent of Phase 0–3 and of each other: **prefer
dispatching them as concurrent background `Agent` invocations** (mirroring how `review-pr`
itself fans out its own reviewer battery) rather than three sequential `Skill` tool calls — a
bare `Skill` invocation is synchronous within the main conversation, so three of them back to
back would serialize the three most expensive parts of an already-expensive skill for no
reason. Fall back to sequential `Skill` invocations only where concurrent dispatch genuinely
isn't available.

When Phase 0 narrows scope to a subtree, invoke `review-pr` Mode C against that same
subtree — it already supports a named-subtree target natively, so no special-casing is
needed here. **`generate-docs` and `pre-public-hardening` are not narrowed, even when the
overall audit is**, for two distinct reasons: `generate-docs`'s whole-against-whole
philosophy reconciles the *entire* docs set every run by design, and a partial reconciliation
would violate that core principle rather than merely shrink it; `pre-public-hardening`'s
secret/license posture is inherently a whole-repo, whole-history concern that a subtree scope
cannot meaningfully bound. Both continue to run at full native cost and behave exactly as
they do standalone — including `generate-docs` writing its fixes directly to the working
tree, which is why this skill runs inside a worktree (see Execution model below).

## Phase 5 — Synthesis

Synthesis runs at the **main-conversation level**, not inside the Phase 0–3 `Workflow`
script — the script has no access to Phase 4's output, since Phase 4's three `Skill`
invocations are dispatched from the main conversation, alongside the `Workflow` script, not
from within it. Synthesis begins only once **both** the `Workflow` script and all three
Phase 4 `Skill` invocations have completed.

Phase 2's many per-unit results are rolled up mechanically — plain aggregation, not another
agent call — as the `Workflow` script's last step before it returns, so the main-conversation
driver receives an already-curated structure rather than every unit's raw output. Synthesis
merges that structure with Phase 3's lens findings (returned by the same `Workflow`) and
Phase 4's three reports, dedupes overlap (e.g. a per-unit test note and a whole-suite finding
about the same redundancy), maps every finding onto the shared severity scale (see
Components below), and produces the final report — including an explicit callout of what
`generate-docs` already changed on disk, since that's the one place this run leaves the
working tree different from how it started.

## Execution model

**Two-level orchestration**, mirroring the pattern `ship` already uses when it invokes
`review-pr` (which itself invokes `security-review` and `pr-review-toolkit:review-pr`): the
executing Claude instance dispatches the three existing skills at the main-conversation
level — preferably as concurrent background `Agent` invocations, per Phase 4 above — while a
dedicated `Workflow` script implements this skill's own net-new phases — 0 through 3 — and
returns its rolled-up result (Phase 5's structure) when it completes. The `Workflow` script
and the three sub-skill dispatches are independent of each other, so nothing here forces them
onto a single serial timeline. **Synthesis itself runs at the main-conversation level**,
explicitly *not* inside the `Workflow` script, exactly as Phase 5 states above — it needs
Phase 4's output, which the script has no way to see.

**This assumes a top-level session, not a subagent.** `Workflow` (with the `resumeFromRunId`
resumption handle and the agent-count cap this file cites) is a tool available to the main
Claude Code session — the one a human actually invokes `/dev-kit:dry-dock-overhaul` from —
but a subagent dispatched via `Agent`/`Task` has no nested access to it. This skill's Phase
0–3 orchestration must therefore run from the main conversation that received this skill's
instructions, never delegated wholesale to a subagent expecting to call `Workflow` itself.

**Worktree isolation.** Branch into a dedicated worktree first via `EnterWorktree`, exactly
like `ship` does, because `generate-docs` writes to the working tree as part of its normal
behavior. The human reviews that diff afterward and decides whether to keep it, discard it,
or hand it to `/dev-kit:ship` to land as its own PR — independently of, and on whatever
timeline they like relative to, how they triage the rest of the report's findings.

## Components

- **No dedicated mechanical-detection script.** Unlike `generate-docs`'s HTML validator (one
  fixed, language-agnostic format), "find files with zero inbound references" has a different
  answer in every language and framework. Phase 1's cheap-tier work is prompt-driven
  grep/reference-analysis by a fast or local-model agent, not a bespoke script.
- **A durable progress file**, uncommitted, under the git dir, following `ship`'s pattern —
  necessary because this is the longest-running, most expensive skill in the marketplace by
  design, and a context compaction mid-run shouldn't lose the whole run. State its scope
  precisely: it covers *this session's* context getting compacted while the run is still in
  flight — **not** a brand-new session rediscovering an old, abandoned run (`ship` doesn't
  solve that case either; it relies on the branch itself as the resumption handle). The file
  records the `Workflow` tool's own `resumeFromRunId` (which handles resuming the Phase 0–3
  fan-out itself) and which of Phase 4's three sub-skills have already completed. If
  `generate-docs` was interrupted mid-write, resuming simply re-invokes it — its own
  whole-against-whole reconciliation is idempotent by design (it re-derives truth from
  current code and docs state every run, regardless of what a prior partial run left behind),
  so no special partial-write recovery logic is needed here.
- **Report skeleton** — a fixed presentation contract, in the spirit of `open-work`'s output
  contract and `review-pr`'s severity-ranked synthesis: a scope/tally header, findings ranked
  by severity across all phases with dimension labels, an explicit "already fixed by
  generate-docs" callout, and a closing verdict paragraph. Ephemeral, per Core philosophy
  above — printed, never committed.
- **A single shared severity scale across every phase and sub-pass** — reuse `review-pr`'s
  existing **blocker → major → minor → nit** scale rather than defining a new one, so Phase 5
  maps each source's native output onto it explicitly: `review-pr` and Phases 2/3's own
  findings already use this scale natively; `pre-public-hardening`'s checklist items map by
  whether they'd block going public (blocker) or are lower-stakes hygiene (minor/nit);
  `generate-docs`'s applied changes aren't findings at all and carry no severity — list them
  in the report as already-resolved, not ranked.

## Data flow

Trace how each phase's output feeds the next, since that's what makes the parallelism above
safe rather than accidental: Phase 0's output (repo kind, scope root, detected test
framework(s), docs-site presence) seeds every phase after it. Phase 1 produces the unit map
plus unconfirmed candidates, each tagged to its unit. Phase 2 consumes both, confirming or
dismissing each candidate using the full context of the one unit it's reading — this is why
Phase 2 needs Phase 1 complete first, but nothing more than that. Phase 3 reads only Phase
0's and Phase 1's context to decide which lenses are worth running at all; it never waits on
Phase 2's per-unit output, which is exactly why it runs fully in parallel with Phase 2 rather
than behind a barrier on it. Phase 4's three sub-passes are independent of everything else in
this skill and produce their own native output on their own schedule. Synthesis (Phase 5) is
the only stage that reads across all of it — it is the sole consumer of the full picture.

## Error handling & degradation

- **Not a git repository** — hard stop, matching `ship`'s own hard stop, and the same check
  Phase 0 above performs.
- **Repo too large for exhaustive coverage within a sane agent budget.** The `Workflow` tool
  caps total agents at 1000 per run, and that cap applies to the Phase 0–3 `Workflow` script
  **specifically** — Phase 4's three `Skill` invocations sit outside it entirely, each
  managing its own existing agent budget independently (e.g. `review-pr`'s own
  workflow-backed battery). Within the Phase 0–3 script, Phase 1's batched (multi-unit-per-
  agent) design keeps its own share of that budget small; Phase 2's one-agent-per-unit cost is
  what actually scales with repo size. If a repo's unit count would still risk the cap,
  surface that plainly and recommend scoping to a subtree via the optional path argument
  (Phase 0) rather than silently doing a partial audit under the "exhaustive" banner. If the
  cap is hit mid-run rather than caught by this estimate beforehand — the `Workflow` tool
  itself errors or stops short — mark every phase it interrupted as incomplete in the final
  report rather than presenting whatever partial result came back as if it were the whole
  picture.
- **A Phase 1, 2, or 3 agent itself fails, times out, or is denied.** Before Phase 5
  synthesizes, reconcile the units that actually returned a result against Phase 1's unit
  map, and the lenses that actually returned against what Phase 3's discovery step
  dispatched. Any unit or lens missing a result gets named in the final report as a coverage
  gap — never silently dropped from the rollup. This is the one failure mode most directly in
  tension with *Exhaustive coverage is non-negotiable* (Core philosophy above): the skill's
  entire premise is that every file was genuinely read, so an undisclosed gap here is worse
  than not running the audit at all.
- **A sub-skill unavailable or denied** — note the gap in the final report and continue with
  the rest, matching the resilience pattern `ship` and `review-pr` already use for their own
  optional sub-steps. The same applies if a Phase 4 dispatch returns but its result isn't a
  genuine report (an error or refusal string rather than actual findings) — verify each of
  the three has real content before Synthesis treats it as a completed input, and route
  anything that looks like a tool failure into this same "note the gap" path.
- **No test framework detected, or no docs site** — not errors; these are inputs to Phase 3's
  discovery step, not failures of Phase 0's detection. A repo with no docs site simply yields
  no docs-UX lens. A repo with no tests at all might itself surface as a finding ("no test
  suite exists") rather than the skill failing to audit tests that don't exist.
- **`generate-docs` fails partway through its own writes** — surface that plainly in the
  final report; the human needs to know the working-tree diff might be incomplete before
  deciding whether to keep it, discard it, or hand it to `/dev-kit:ship`.

## Verification / testing guidance

There is no code here to unit-test the way a bats-tested script has one — treat a first run
against any given repo as a staged dry run, not a leap straight to the genuine article. Scope
that first run to a single subtree (one plugin in a marketplace, one package in a library) via
Phase 0's optional path argument, and use it to sanity-check that each phase behaves as this
file describes and that the report renders the skeleton above — before ever running a
genuine whole-repo pass on a repo you actually care about auditing.

Be precise with the human about what "cheap" means for that staged dry run: it only applies
to Phases 0–3 and to `review-pr` (Phase 4), both of which do narrow to the subtree. It does
**not** apply to `generate-docs` or `pre-public-hardening` — per Phase 4 above, both always
run at full native, whole-repo scope regardless of what Phase 0 resolves, so even a
subtree-scoped dry run still pays their full whole-repo cost. Say so plainly before a human
runs their first dry run, rather than letting "scoped to a subtree" imply the whole run got
cheaper.
