# dry-dock-overhaul: exhaustive, occasional, whole-repo audit

**Status:** design approved (brainstorming), implemented
**Date:** 2026-07-04
**Tracking issue:** [#100](https://github.com/nivintw/nivintw-claude-skills/issues/100)
**Plugin:** `dev-kit` · skill `dry-dock-overhaul`

## 1. Summary

A new `dev-kit` skill, invoked as `/dev-kit:dry-dock-overhaul`, that performs an exhaustive,
occasional, always-human-triggered audit of an entire repository: every tracked source file
is genuinely read and judged by some agent, not sampled — `.gitignore`-excluded and untracked
paths (generated, vendored, and binary artifacts) are out of scope — plus a "10,000-foot" pass
asking whether
the repo communicates well — is the docs site good UX, is the test suite well-architected, is
terminology used consistently — on top of the existing correctness/security/hygiene coverage
this marketplace already has. It produces one ephemeral, severity-ranked report; it does not
persist across runs and does not auto-apply fixes (with one deliberate exception — see §4,
row 10).

This is explicitly the most expensive skill in the marketplace by design: a "haul the whole
ship out of the water" operation the human runs rarely and on purpose, not something any other
skill invokes automatically.

## 2. Motivation

A survey of this marketplace's existing whole-repo-capable skills found three real gaps
nothing today fills:

- **No exhaustive, whole-repo, per-line code archaeology.** `review-pr`'s Mode C (whole-repo
  audit) reuses the same diff-shaped reviewer battery used for PRs — correctness, security,
  reuse/simplification/efficiency — at wider scope, but it isn't built for guaranteed,
  exhaustive per-file coverage or "why does this code exist" justification at repo scale.
- **No first-class test-suite architecture audit.** Test coverage appears today only as one
  dimension of a diff-scoped review (`pr-review-toolkit`'s test-coverage analyzer); nothing
  treats a whole test suite's structure, DRYness, and coverage shape as its own audit target.
- **No standalone "10,000-foot" communication/UX pass.** `generate-docs` asks "is this the
  best way to communicate this information?" as a side effect of fixing drift in a specific
  page — there is no independent judgment pass over documentation UX, or over any other
  cross-cutting communication concern (naming consistency, README-vs-site duplication, prose
  altitude), decoupled from a content-correctness trigger.

## 3. Core philosophy

1. **Repo-agnostic, always.** This skill must work on any repo, the same way `generate-docs`
   does — it classifies the target repo's kind (marketplace, Copier template, library/CLI,
   generic) rather than assuming anything about the repo it happens to be developed in. A
   "unit" of the exhaustive pass means a plugin in a marketplace, a package in a library, a
   module in a generic codebase — whatever that repo's own natural seams are.
2. **Exhaustive coverage is non-negotiable; cost-consciousness is about *how*, not *whether*.**
   Every file gets read and judged by some agent. Being "token-conscious" means routing
   mechanical work (inventory-building, dead-code candidate detection) to a cheap or local
   tier and reserving expensive reasoning for genuine judgment calls — not skipping coverage.
3. **Findings-only reporting for genuine judgment calls; the report is proof of thoroughness,
   not a to-do list the skill executes.** Nothing this skill newly judges (code
   justification, test-suite architecture, 10,000-foot communication) gets auto-fixed. The
   human triages every finding.
4. **Compose, don't reimplement.** The three existing whole-repo-capable skills
   (`review-pr` Mode C, `generate-docs`, `pre-public-hardening`) are invoked as sub-passes,
   always, in full — this skill adds the three net-new dimensions above it, it doesn't
   re-derive what they already do well.
5. **Discovery over enumeration for the 10,000-foot pass.** The specific holistic lenses
   (test-suite shape, docs UX, naming consistency, or whatever else) are not a fixed list
   baked into this skill's prose — they're proposed at run time based on what the target repo
   actually contains, so a repo with no docs site simply gets no docs-UX lens, and a
   differently-shaped repo can surface an entirely different lens.
6. **Ephemeral by design.** The report is a conversational deliverable, not a durable
   artifact — it is never committed. If a finding is worth tracking, the human files it via
   `/dev-kit:handle-task-tracking` themselves.

## 4. Key decisions (resolved during brainstorming)

| # | Decision | Choice |
|---|----------|--------|
| 1 | Literalness of "every line accounted for" | Literal, exhaustive — every file genuinely read by some agent, not sampled |
| 2 | Relationship to review-pr/generate-docs/pre-public-hardening | Orchestrate all three as sub-passes; add net-new dimensions on top |
| 3 | Action model for new dimensions | Report only — the human triages every finding, nothing auto-applied |
| 4 | Report persistence | Ephemeral — shown in-conversation, never committed |
| 5 | Scope | Whole repo by default; an optional path/subtree argument narrows scope |
| 6 | Justification-pass output shape | Exceptions only — clean, justified code produces no report entry |
| 7 | 10,000-foot lens set | Discovered at run time per repo, not a fixed enumerated list |
| 8 | Skill home & invocation | New skill in `dev-kit`, `/dev-kit:dry-dock-overhaul` |
| 9 | Which sub-passes always run | All three, always — no toggles |
| 10 | generate-docs's native write behavior | Preserved — it still writes fixes directly; the report notes what changed |
| 11 | Fan-out architecture | Adaptive (natural-seam units, not fixed chunking) + cost-tiering (cheap/local tier for inventory and mechanical detection, mid/top tier for judgment) |
| 12 | Working-tree isolation | Runs inside a dedicated worktree (like `ship`), since `generate-docs` writes to disk as part of the run |

## 5. Architecture — six phases

**Phase 0 — Classify & scope.** Confirm the cwd is a git repository. Resolve scope: the repo
root by default, or a human-supplied subtree/plugin path. Classify repo kind by sentinel
files, reusing `generate-docs`'s classification rather than redefining it. Detect the test
framework(s) in use and whether a docs site exists — both feed Phase 3's discovery step.

**Phase 1 — Inventory (cheap/local tier).** Build the unit map: for a marketplace, one unit
per plugin; for a library, top-level packages; generic repos fall back to a
language-appropriate directory heuristic. Only tracked files are in scope — `.gitignore`-excluded
and untracked paths (generated output, vendored dependencies, binary artifacts) sit outside the
exhaustive-coverage guarantee, the same boundary git itself already draws. For each unit,
gather its file list, rough size,
and cheap mechanical candidate-detection (files with zero inbound references, obvious dead
exports, TODO/FIXME density) via grep/reference-analysis, routed to a fast or local model.
Unlike Phase 2, this stage batches multiple units per agent rather than one agent per unit —
the work per unit is lightweight (grep-based, not a full read-and-judge), so a small number of
agents can cover many units each, keeping Phase 1's own agent count well below what Phase 2
needs. This stage's output is *candidates*, not findings — a "zero references" hit can be a
false positive (dynamic loading, plugin-discovery-by-convention), so Phase 2 confirms or
dismisses each one rather than the report trusting Phase 1's mechanical signal directly. Phase
1 runs to completion as one discrete stage before Phase 2 or Phase 3 begins — both need the
*whole* unit map (Phase 2 to assign one unit per agent, Phase 3 to reason about repo-wide
shape), so there is no streaming/partial hand-off between Phase 1 and what follows it.

**Phase 2 — Deep-dive per unit (pipelined, mid/top tier).** One agent per unit — this is the
one phase where per-unit granularity is worth the agent cost, since it's the phase doing the
actual exhaustive read-and-judge work. Each agent reads every file in its unit — the literal
exhaustive-coverage guarantee — and reports exceptions only: unjustified, dead, or redundant
code; unclear structure; Phase 1 candidates it confirms or dismisses. The same agent judges
its unit's own colocated tests (if any) for redundancy and its own code/comment/docstring
clarity, both scoped to that unit alone. Units are pipelined *relative to each other* — no
barrier between one unit's agent and the next, since they're independent — not relative to
Phase 1, which must have already completed (see above).

**Phase 3 — 10,000-foot discovery, then holistic passes (parallel with Phase 2).** A
discovery step first asks "what whole-repo-level questions actually matter for this specific
repo?", informed by Phase 0's classification and Phase 1's inventory — not from a fixed list.
Discovered lenses are concerns that only make sense judged holistically rather than per-unit:
whole-test-suite structure and cross-unit DRYness, docs-site UX as an independent second
opinion (not anchored to `generate-docs`'s own self-assessment of the same site), naming and
terminology consistency across the whole codebase, or whatever else the repo's shape actually
calls for — a repo with no docs site gets no docs-UX lens; a CLI-shaped repo might instead get
a lens on its flag/config surface's internal consistency. Each discovered lens becomes its own
agent, run in parallel with the rest.

**Phase 4 — Existing sub-passes (parallel, fully independent).** Invoke `review-pr` Mode C,
`generate-docs`, and `pre-public-hardening`, each via the `Skill` tool. When Phase 0 narrows
scope to a subtree, `review-pr` Mode C is invoked against that same subtree — it already
supports a named-subtree target natively. `generate-docs` and `pre-public-hardening` are
**not** narrowed even when the overall audit is: `generate-docs`'s whole-against-whole
philosophy reconciles the *entire* docs set every run by design (a partial reconciliation
would violate its own core principle), and `pre-public-hardening`'s secret/license posture is
inherently a whole-repo, whole-history concern that a subtree scope can't meaningfully bound.
Both continue to run at full native cost and behave exactly as they do standalone —
including `generate-docs` writing its fixes directly to the working tree. This means a
subtree-scoped run makes Phases 0–3 (and `review-pr`) cheap, but not Phase 4's other two
sub-passes — see §10 for what that implies for a first "cheap" dry run.

**Phase 5 — Synthesis.** Runs at the main-conversation level (see §6), after both the
Phase 0–3 `Workflow` script and the three Phase 4 `Skill` invocations have completed, since it
needs output from both. Phase 2's many per-unit results are rolled up mechanically (plain
aggregation, not another agent call) into one compact structure — this rollup happens inside
the `Workflow` script, as the last step before it returns, so the main-conversation driver
receives an already-curated structure rather than every unit's raw output. Synthesis then
merges that structure with Phase 3's lens findings (also returned by the same `Workflow`) and
Phase 4's three reports, dedupes overlap (e.g. a per-unit test note and a whole-suite finding
about the same redundancy), maps every finding onto the shared severity scale (§7), and
produces the final report — including an explicit callout of what `generate-docs` already
changed on disk, since that's the one place this run leaves the working tree different from
how it started.

## 6. Execution model

**Two-level orchestration**, mirroring the pattern already established by `ship` invoking
`review-pr` (which itself invokes `security-review` and `pr-review-toolkit:review-pr`): the
executing Claude instance invokes the three existing skills via the `Skill` tool at the
main-conversation level and dispatches whatever background work each one's own instructions
call for, while a dedicated `Workflow` script implements this skill's own net-new phases
(0 through 3) and returns its rolled-up result (per §5 Phase 5) when it completes. Both
levels' backgroundable work runs concurrently. **Synthesis itself runs at the
main-conversation level**, after both the `Workflow` script's return value and all three
`Skill` invocations' own output are in hand — it is not part of the `Workflow` script, since
it needs Phase 4's output, which the `Workflow` script has no access to.

**Worktree isolation.** The run branches into a dedicated worktree first, exactly like `ship`
does, because `generate-docs` writes to the working tree as part of its normal behavior. The
human reviews that diff afterward and decides whether to keep it, discard it, or take it
further (e.g. handing it to `/dev-kit:ship` to land as its own PR) — independently of how they
triage the rest of the report's findings.

## 7. Components

- **`plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md`** — the main skill.
- **`reference/lens-examples.md`** — supporting material kept out of the main file:
  illustrative (explicitly non-exhaustive) examples of what a 10,000-foot lens can look like.
  Reusing `generate-docs`'s repo-kind classification is handled as a direct link from Phase 0
  to `generate-docs`'s own SKILL.md rather than a separate notes file — one link stays
  current automatically; a duplicated summary would drift the moment `generate-docs`'s
  classification logic changes.
- **No dedicated mechanical-detection script.** Unlike `generate-docs`'s HTML validator
  (one fixed, language-agnostic format), "find files with zero inbound references" has a
  different answer in every language and framework. Phase 1's cheap-tier work is
  prompt-driven grep/search by a fast or local-model agent, not a bespoke script.
- **A durable progress file**, uncommitted, under the git dir, following `ship`'s pattern —
  necessary because this is the longest-running, most expensive skill in the marketplace by
  design, and a context compaction mid-run shouldn't lose the whole run. Scope: this covers
  the same-session case, where *this* session's context gets compacted while the run is still
  in flight — not a brand-new session rediscovering an old, abandoned run (`ship` doesn't
  solve that case either; it relies on the branch/PR itself as the resumption handle). The
  file records the `Workflow` tool's own `resumeFromRunId` (which handles resuming the
  Phase 0–3 fan-out itself) and which of Phase 4's three sub-skills have already completed.
  If `generate-docs` was interrupted mid-write, resuming simply re-invokes it — its own
  whole-against-whole reconciliation is idempotent by design (it re-derives truth from
  current code and docs state every run, regardless of what a prior partial run left behind),
  so no special partial-write recovery logic is needed here.
- **Report skeleton** — a fixed presentation contract in the spirit of `open-work`'s output
  contract and `review-pr`'s severity-ranked synthesis: a scope/tally header, findings ranked
  by severity across all phases with dimension labels, an explicit "already fixed by
  generate-docs" callout, and a closing verdict paragraph. Ephemeral — printed, never
  committed (§3.6, §4 row 4). Severity is a single shared scale across every phase and
  sub-pass — reusing `review-pr`'s existing blocker/major/minor/nit scale rather than
  defining a new one — so Phase 5 maps each source's native output onto it explicitly:
  `review-pr` and Phases 2/3's own findings already use this scale natively;
  `pre-public-hardening`'s checklist items map by whether they'd block going public
  (blocker) or are lower-stakes hygiene (minor/nit); `generate-docs`'s applied changes aren't
  findings at all and carry no severity — they're listed in the report as already-resolved,
  not ranked.

## 8. Data flow

Phase 0's output (repo kind, scope root, detected test framework(s), docs-site presence)
seeds every later phase. Phase 1 produces the unit map plus unconfirmed candidates tagged to
their unit; Phase 2 consumes both, confirming or dismissing each candidate using the full
context of the one unit it's reading. Phase 3 reads only Phase 0/1's context to decide which
lenses are worth running at all — it does not wait on Phase 2's per-unit output, so it runs
fully in parallel rather than behind a barrier. Phase 4's three sub-passes are independent of
everything else and produce their own native output. Synthesis (Phase 5) is the only stage
that reads across all of it.

## 9. Error handling & degradation

- **Not a git repository** — hard stop, matching `ship`.
- **Repo too large for exhaustive coverage within a sane agent budget.** `Workflow` caps
  total agents at 1000 per run, and that cap applies to the Phase 0–3 `Workflow` script
  specifically — Phase 4's three `Skill` invocations sit outside it, managing their own
  existing agent budgets independently (e.g. `review-pr`'s own workflow-backed battery).
  Phase 1's batched (multi-unit-per-agent) design keeps its own share of that budget small;
  Phase 2's one-agent-per-unit cost is what actually scales with repo size. If a repo's unit
  count would still risk the cap, that's surfaced plainly with a recommendation to scope to a
  subtree via the optional path argument, rather than silently doing a partial audit under
  the "exhaustive" banner.
- **A sub-skill unavailable or denied** — note the gap, continue with the rest, matching the
  resilience pattern already established in `ship`/`review-pr`.
- **No test framework, or no docs site** — not errors; inputs to Phase 3's discovery step.
  A repo with no docs site gets no docs-UX lens. A repo with no tests at all might itself
  surface as a finding ("no test suite exists") rather than the skill failing to audit tests
  that don't exist.
- **`generate-docs` fails partway through its own writes** — surfaced plainly in the final
  report; the human needs to know the working-tree diff might be incomplete before deciding
  whether to keep it.

## 10. Verification / testing

There is no code here to unit-test the way, say, a bats-tested script has — verification is
about proving the design's two hardest claims hold up in practice: genuine repo-agnosticism
(does Phase 3's discovery actually propose different lenses against a differently-shaped
repo, not just whichever repo it was built against?), and that exhaustive coverage doesn't
silently degrade at scale. Given cost, the practical verification path is staged: a first dry
run scoped to a single subtree (e.g. one plugin in a marketplace) to sanity-check phase
behavior and report shape cheaply, before ever running a genuine whole-repo pass. That "cheap"
framing applies to Phases 0–3 and `review-pr` — per §5 Phase 4, `generate-docs` and
`pre-public-hardening` always run at full native scope regardless, so even a subtree-scoped
dry run still pays their whole-repo cost; this should be stated plainly alongside the
staged-verification advice rather than left implicit. The staged approach itself should also
be stated directly in the skill's own prose, as advice to a human running it for the first
time against any given repo.

## 11. Out of scope

- **Auto-applying any of this skill's own findings.** Every new dimension (code
  justification, test-suite architecture, 10,000-foot communication) is report-only; only
  `generate-docs`'s own native write behavior is preserved, because it isn't this skill's
  finding to begin with.
- **Persisting reports across runs, or diffing against a prior run.** Each run is
  self-contained; there is no "did last quarter's dry-dock findings get fixed" tracking built
  into the skill itself. A human who wants that can file findings as issues via
  `/dev-kit:handle-task-tracking`.
- **Toggling individual sub-passes off.** All three existing skills run every time; there is
  no flag to skip `pre-public-hardening` or any other sub-pass for a lighter-weight run.
- **Auto-triggering from any other skill.** This is explicitly always human-invoked — no
  other skill in this marketplace should ever call `dry-dock-overhaul` on the human's behalf.
