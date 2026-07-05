# dry-dock-overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `/dev-kit:dry-dock-overhaul`, a new `dev-kit` skill that performs an
exhaustive, occasional, human-triggered whole-repo audit, per the approved design at
`docs/superpowers/specs/2026-07-04-dry-dock-overhaul-design.md` (referenced below as "the
spec"; section numbers below are spec section numbers unless stated otherwise).

**Architecture:** One new skill — `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` — plus a
small `reference/` directory. No scripts and no automated tests ship with this skill (spec
§10: there is no code here to unit-test); verification is gate-cleanliness, plugin-dev
reviewer sign-off, and an end-to-end smoke run against a real subtree of this repo.

**Tech Stack:** Markdown (skill prose), the `Skill` tool (to invoke `review-pr`, `generate-docs`,
`pre-public-hardening`), the `Workflow` tool (to implement Phases 0–3's fan-out), `EnterWorktree`
(worktree isolation).

## Global Constraints

- Repo-agnostic, always (spec §3.1): classify the target repo the same way `generate-docs`
  does; never assume this skill is auditing this specific marketplace.
- Exhaustive coverage of tracked, `.gitignore`-respecting source files is non-negotiable
  (spec §3.2, §1); cost-consciousness is about routing mechanical work to a cheap/local tier,
  never about skipping coverage.
- Every new dimension this skill judges (code justification, test-suite architecture,
  10,000-foot communication) is report-only (spec §3.3); `generate-docs`'s own native
  writes are the *one* documented exception (spec §4 row 10, §5 Phase 4).
- The report is ephemeral — shown in-conversation, never committed (spec §3.6).
- No other skill in this marketplace should ever invoke `dry-dock-overhaul` automatically
  (spec §11) — it is always human-triggered.
- Markdown files in this repo are licensed via `REUSE.toml`, not an inline SPDX header — do
  **not** add one to `SKILL.md` or `reference/*.md` (this repo's CLAUDE.md; already covered
  by the existing blanket `REUSE.toml` rule, verify with `reuse lint`, don't hand-edit
  `REUSE.toml` unless `reuse lint` actually fails).

## File Structure

- **Create:** `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` — the skill itself.
- **Create:** `plugins/dev-kit/skills/dry-dock-overhaul/reference/lens-examples.md` —
  illustrative (explicitly non-exhaustive) examples of a 10,000-foot lens (spec §7).
- **Modify:** `plugins/dev-kit/.claude-plugin/plugin.json` — add a sentence to `description`
  naming the new skill, matching the existing per-skill-sentence convention in that field.
- **Modify:** `.claude-plugin/marketplace.json` — same addition to the `dev-kit` entry's
  `description` (a separate, similarly-worded field from `plugin.json`'s — both need the edit).
- No scripts, no `tests/*.bats` file — spec §10 is explicit that there is no code here to
  unit-test the way `rank_issues.py` or `check_docs.py` have tests.

---

## Task 1: Scaffold the skill and register it

Get the skill directory in place with a minimal-but-valid frontmatter, registered in both
plugin manifests, and confirmed loadable — before writing the (large) body in Tasks 2–4. This
is independently reviewable: a reviewer can confirm the skill is correctly scaffolded and
registered without yet judging the body's content.

**Files:**

- Create: `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` (frontmatter + a one-line body
  placeholder, replaced in Task 2)
- Modify: `plugins/dev-kit/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**

- Consumes: nothing.
- Produces: the skill's `name` and `description` frontmatter fields, which Tasks 2–4 write
  the body underneath and which downstream tooling (plugin-validator, skill-reviewer, and any
  future skill that cross-references this one by name) rely on verbatim.
- [ ] **Step 1: Create the skill directory and frontmatter**

```bash
mkdir -p plugins/dev-kit/skills/dry-dock-overhaul/reference
```

Write `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` with exactly this frontmatter (do
**not** add an inline SPDX comment above it — see Global Constraints):

```markdown
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

(placeholder — full body written in Task 2-4)
```

- [ ] **Step 2: Register in `plugin.json`**

Open `plugins/dev-kit/.claude-plugin/plugin.json`. Its `description` field is one long
sentence-per-skill string ending in
`"... and inventories the plugins and their skills."`. Append one more clause before the
final period, following the exact style of the existing clauses (semicolon-separated,
`name` in backtick-free plain text since this is JSON, present tense, ends with what it
produces):

```text
; dry-dock-overhaul performs an exhaustive, occasional, human-triggered whole-repo audit — every tracked file read and judged, plus a per-repo-discovered "10,000-foot" pass on communication and UX — orchestrating review-pr, generate-docs, and pre-public-hardening alongside the net-new coverage
```

i.e. the field's final sentence changes from ending in
`"...inventories the plugins and their skills."` to
`"...inventories the plugins and their skills; dry-dock-overhaul performs an exhaustive, occasional, human-triggered whole-repo audit — every tracked file read and judged, plus a per-repo-discovered \"10,000-foot\" pass on communication and UX — orchestrating review-pr, generate-docs, and pre-public-hardening alongside the net-new coverage."`

Validate the JSON is still well-formed:

```bash
python3 -c "import json; json.load(open('plugins/dev-kit/.claude-plugin/plugin.json'))" && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Register in `marketplace.json`**

Open `.claude-plugin/marketplace.json`, find the `dev-kit` plugin entry's `description` field
(a separately-worded string from `plugin.json`'s, using `/dev-kit:<skill>` command-style
naming for each clause). It currently ends in
`"...checks installed plugin versions against the latest releases (flagging a stale cache
running an old skill) and inventories the plugins and their skills."`. Append, in the same
`/dev-kit:<skill>` style as the other clauses:

```text
; /dev-kit:dry-dock-overhaul performs an exhaustive, occasional, human-triggered whole-repo audit — every tracked file read and judged, plus a per-repo-discovered "10,000-foot" pass on communication and UX — orchestrating review-pr, generate-docs, and pre-public-hardening alongside the net-new coverage
```

Validate:

```bash
python3 -c "import json; json.load(open('.claude-plugin/marketplace.json'))" && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Verify the skill is discoverable and passes basic validation**

Dispatch the `plugin-dev:plugin-validator` agent against the `dev-kit` plugin.
Expected: no errors about the new skill's frontmatter, manifest JSON validity, or directory
structure. (Findings about the still-placeholder body are expected and will be resolved by
Task 2–4; don't fix those here.)

- [ ] **Step 5: Gate-clean and commit**

```bash
uvx prek run --files plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md plugins/dev-kit/.claude-plugin/plugin.json .claude-plugin/marketplace.json
```

Expected: green (hawkeye/reuse/rumdl/taplo-adjacent hooks all pass; JSON hooks pass since
Steps 2–3 already validated well-formedness).

```bash
git add plugins/dev-kit/skills/dry-dock-overhaul/ plugins/dev-kit/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(dev-kit): scaffold dry-dock-overhaul skill and register it"
```

---

## Task 2: Write the skill's framing and Phases 0–2

**Files:**

- Modify: `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` (replace the Task 1 placeholder
  body with real content, through Phase 2)

**Interfaces:**

- Consumes: the frontmatter from Task 1 (unchanged).
- Produces: the "What this is / isn't" framing and Phases 0–2 prose that Task 3 continues
  from and cross-references (Phase 3 reads "Phase 0's classification and Phase 1's
  inventory"; Phase 4's scope-narrowing text references "when Phase 0 narrows scope").
- [ ] **Step 1: Write the introduction and "what this is / isn't" framing**

Content source: spec §1 (Summary), §2 (Motivation), §3 (Core philosophy). Cover, in prose (not
copied verbatim from the spec — the spec explains *why* a decision was made during
brainstorming; the skill tells Claude what to *do* when it runs, in the same imperative voice
as `ship`/`open-work`/`pre-public-hardening`):

- What this skill does in one paragraph (exhaustive whole-repo audit, every tracked file
  read and judged, plus a per-repo-discovered 10,000-foot communication/UX pass, on top of
  the existing `review-pr`/`generate-docs`/`pre-public-hardening` coverage).
- The three gaps this fills (spec §2's three bullets) as brief motivation, framed as "this
  is not..." contrasts — mirror how `open-work`'s "What this is not" section is structured
  (three short bullets: not X, that's skill Y's job).
- Core philosophy as operating rules, not history: repo-agnostic always (classify by
  sentinel files, reuse `generate-docs`'s classification — link to
  `../generate-docs/SKILL.md` rather than redefining it); exhaustive coverage is
  non-negotiable, cost-consciousness is about routing tiers not skipping files; report-only
  for new dimensions (`generate-docs`'s writes are the one exception, explain why: it's not
  this skill's own finding, it's `generate-docs`'s already-established native behavior);
  compose don't reimplement (the three sub-passes always run in full); discovery over
  enumeration for the 10,000-foot pass (state plainly that the lens list is *not* fixed in
  this file — whatever examples appear later in `reference/lens-examples.md` are examples,
  not a checklist); ephemeral by design (never committed; a human who wants a finding tracked
  files it via `/dev-kit:handle-task-tracking` themselves).
- [ ] **Step 2: Write Phase 0 — Classify & scope**

Content source: spec §5 Phase 0. Cover: confirm cwd is a git repo (hard stop if not, matching
`ship`'s wording); resolve scope (repo root by default, or a human-supplied subtree/plugin
path argument); classify repo kind by reusing `generate-docs`'s classification (link to it,
don't redefine the sentinel-file logic here); detect test framework(s) in use and whether a
docs site exists, both feeding Phase 3.

- [ ] **Step 3: Write Phase 1 — Inventory**

Content source: spec §5 Phase 1 (as fixed by the adversarial-review pass — this is the
*current*, corrected text in the committed spec, not an earlier draft). Cover: build the unit
map (one unit per plugin for a marketplace, top-level packages for a library, a
language-appropriate directory heuristic for generic repos); only tracked,
`.gitignore`-respecting files are in scope; **batch multiple units per agent, not one agent
per unit** (Phase 1's work is grep-based and lightweight, unlike Phase 2 — state this
explicitly, since it's what keeps Phase 1's own agent count small); per unit, gather file
list, rough size, and cheap mechanical candidate-detection (zero-inbound-reference files,
obvious dead exports, TODO/FIXME density) routed to a fast or local model; the output is
*candidates*, not findings (a "zero references" hit can be a false positive — dynamic
loading, plugin-discovery-by-convention — Phase 2 confirms or dismisses); **Phase 1 runs to
completion as one discrete stage before Phase 2 or Phase 3 begins** — both need the whole
unit map, so there is no streaming/partial hand-off.

- [ ] **Step 4: Write Phase 2 — Deep-dive per unit**

Content source: spec §5 Phase 2. Cover: one agent per unit (the one phase where per-unit
granularity is worth the cost, since it's the actual exhaustive read-and-judge work); each
agent reads every file in its unit and reports exceptions only (unjustified/dead/redundant
code, unclear structure, confirmed-or-dismissed Phase 1 candidates); the same agent judges
its unit's own colocated tests for redundancy and its own code/comment/docstring clarity,
both scoped to that unit alone; units are pipelined *relative to each other* (no barrier
between one unit's agent and the next) but *not* relative to Phase 1, which must already have
completed.

- [ ] **Step 5: Read back Steps 1–4 for internal consistency**

Read the file you just wrote end to end. Confirm: the "batch per-unit" note in Phase 1 and
the "one-agent-per-unit" note in Phase 2 don't contradict each other (they describe two
different phases' granularity, not the same one); every forward reference (e.g. "feeding
Phase 3" in Phase 0, "Phase 2 confirms or dismisses" in Phase 1) actually gets addressed when
Task 3 writes those later phases — leave yourself a one-line note in the commit message if
anything here will need revisiting once Phase 3–5 exist, so Task 3's agent (a fresh subagent,
with no memory of this session) knows to check it.

- [ ] **Step 6: Gate-clean and commit**

```bash
uvx prek run rumdl --files plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md
uvx reuse lint
```

Expected: rumdl passes (or autofixes cleanly); reuse lint passes.

```bash
git add plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md
git commit -m "feat(dev-kit): write dry-dock-overhaul framing and Phases 0-2"
```

---

## Task 3: Write Phases 3–5, the execution model, components, and the lens-examples reference

**Files:**

- Modify: `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` (append Phases 3–5, Execution
  model, Components)
- Create: `plugins/dev-kit/skills/dry-dock-overhaul/reference/lens-examples.md`

**Interfaces:**

- Consumes: Task 2's Phase 0–2 prose (read the current file before appending — do not
  regenerate what Task 2 wrote); the "Phase 1's inventory" and "Phase 0's classification"
  terminology must match Task 2's wording exactly, since Phase 3 references both by name.
- Produces: the `reference/lens-examples.md` link that Phase 3's prose must point to; the
  severity scale and progress-file mechanics that Task 4's Error-handling section assumes
  exist.
- [ ] **Step 1: Read the current SKILL.md**

```bash
cat plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md
```

Confirm Phases 0–2 read as you expect before appending — this task's agent is fresh and must
ground itself in what Task 2 actually produced, not the plan's summary of it.

- [ ] **Step 2: Write Phase 3 — 10,000-foot discovery, then holistic passes**

Content source: spec §5 Phase 3. Cover: a discovery step first asks "what whole-repo-level
questions actually matter for this specific repo?", informed by Phase 0's classification and
Phase 1's inventory — **not from a fixed list**; discovered lenses are concerns that only
make sense judged holistically (whole-test-suite structure and cross-unit DRYness,
docs-site UX as an independent second opinion — not anchored to `generate-docs`'s own
self-assessment of the same site — naming/terminology consistency, or whatever else the
repo's shape calls for); a repo with no docs site gets no docs-UX lens; each discovered lens
becomes its own agent, run in parallel with the rest. Point to
`reference/lens-examples.md` (written in Step 6 below) for illustrative examples, and state
explicitly in this section that those examples are non-exhaustive — the discovery step must
not treat them as a checklist.

- [ ] **Step 3: Write Phase 4 — Existing sub-passes**

Content source: spec §5 Phase 4 (as fixed by adversarial review — the scope-narrowing
nuance is load-bearing, don't drop it). Cover: invoke `review-pr` Mode C, `generate-docs`,
and `pre-public-hardening`, each via the `Skill` tool; when Phase 0 narrows scope to a
subtree, `review-pr` Mode C is invoked against that same subtree (it natively supports a
named-subtree target); `generate-docs` and `pre-public-hardening` are **not** narrowed even
when the overall audit is — state the two distinct reasons (`generate-docs`'s
whole-against-whole philosophy would be violated by a partial reconciliation;
`pre-public-hardening`'s secret/license posture is inherently whole-repo/whole-history and
can't be meaningfully bounded to a subtree); both continue at full native cost, including
`generate-docs` writing its fixes directly to the working tree.

- [ ] **Step 4: Write Phase 5 — Synthesis**

Content source: spec §5 Phase 5 (as fixed by adversarial review). Cover: runs at the
main-conversation level (not inside the Phase 0–3 `Workflow` script — the script has no
access to Phase 4's output), after both the `Workflow` script and the three `Skill`
invocations have completed; Phase 2's many per-unit results are rolled up mechanically
inside the `Workflow` script as its last step before returning, so the main-conversation
driver receives an already-curated structure, not raw per-unit output; synthesis merges that
structure with Phase 3's lens findings (also returned by the same `Workflow`) and Phase 4's
three reports, dedupes overlap, maps every finding onto the shared severity scale (written in
Step 6 below), and produces the final report, including an explicit callout of what
`generate-docs` already changed on disk.

- [ ] **Step 5: Write the Execution model section**

Content source: spec §6 (as fixed by adversarial review). Cover: two-level orchestration —
mirror the pattern `ship` already uses invoking `review-pr` (which itself invokes
`security-review` and `pr-review-toolkit:review-pr`): the executing Claude instance invokes
the three existing skills via the `Skill` tool at the main-conversation level, while a
dedicated `Workflow` script implements Phases 0–3 and returns its rolled-up result;
synthesis itself runs at the main-conversation level, explicitly *not* inside the `Workflow`
script. Worktree isolation: branch into a dedicated worktree first via `EnterWorktree`,
exactly like `ship` does, because `generate-docs` writes to the working tree; the human
reviews that diff afterward and decides whether to keep it, discard it, or hand it to
`/dev-kit:ship` to land as its own PR — independently of how they triage the rest of the
report.

- [ ] **Step 6: Write the Components section, and `reference/lens-examples.md`**

Content source: spec §7 (as fixed by adversarial review). In `SKILL.md`, cover: no dedicated
mechanical-detection script (unlike `generate-docs`'s language-agnostic HTML validator,
"zero inbound references" has a different answer per language/framework — Phase 1's work is
prompt-driven, not a bespoke script); the durable progress file (uncommitted, under the git
dir, following `ship`'s pattern) — **state its actual scope precisely**: it covers *this
session's* context getting compacted mid-run, not a brand-new session rediscovering an old
abandoned run (`ship` doesn't solve that case either); it records the `Workflow` tool's
`resumeFromRunId` and which of Phase 4's three sub-skills have already completed; if
`generate-docs` was interrupted mid-write, resuming just re-invokes it — its own
whole-against-whole reconciliation is idempotent, so no special partial-write recovery logic
is needed; the report skeleton (scope/tally header, findings ranked by severity across all
phases with dimension labels, an explicit "already fixed by generate-docs" callout, a closing
verdict paragraph, ephemeral/never committed) and the **shared severity scale** — reuse
`review-pr`'s existing blocker/major/minor/nit scale rather than defining a new one:
`review-pr` and Phases 2/3's own findings already use it natively; `pre-public-hardening`'s
checklist items map by whether they'd block going public (blocker) or are lower-stakes
hygiene (minor/nit); `generate-docs`'s applied changes carry no severity at all — list them
as already-resolved, not ranked.

Then create `plugins/dev-kit/skills/dry-dock-overhaul/reference/lens-examples.md` with a
short header explaining these are illustrative, non-exhaustive examples of what a
10,000-foot lens can look like (not a list to enumerate), followed by concrete examples
spanning at least: a docs-heavy repo (docs-site UX as an independent second opinion), a
CLI-shaped repo (flag/config surface internal consistency), a test-heavy repo (whole-suite
DRYness and structure), and one example of a repo where *no* lens applies to something (e.g.
a repo with no docs site getting no docs-UX lens at all) — to make the "discovered, not
enumerated" principle concrete rather than abstract. Link to this file from Phase 3's prose
in `SKILL.md` using a relative markdown link: `[reference/lens-examples.md](reference/lens-examples.md)`.

- [ ] **Step 7: Read back the whole file for consistency**

Read `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` end to end, Task 2's sections
included. Confirm: Phase 3's reference to "Phase 0's classification and Phase 1's inventory"
matches those phases' actual content; Phase 4's scope-narrowing note doesn't contradict
anything in Phase 0's scope-resolution text; the Execution model's "Synthesis is not inside
the Workflow script" statement doesn't contradict Phase 5's own wording. Fix any drift found
— this step exists specifically because the spec's own first draft had exactly this kind of
cross-section drift, caught by an adversarial review pass; catching it here at draft time is
cheaper than catching it in Task 5.

- [ ] **Step 8: Gate-clean and commit**

```bash
uvx prek run --files plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md plugins/dev-kit/skills/dry-dock-overhaul/reference/lens-examples.md
```

Expected: green.

```bash
git add plugins/dev-kit/skills/dry-dock-overhaul/
git commit -m "feat(dev-kit): write dry-dock-overhaul Phases 3-5, execution model, components"
```

---

## Task 4: Write data flow, error handling, verification guidance; final coherence pass

**Files:**

- Modify: `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` (append the remaining sections;
  this completes the body)

**Interfaces:**

- Consumes: the full file as it stands after Task 3.
- Produces: the complete `SKILL.md`, which Task 5 validates and Task 6 smoke-tests.
- [ ] **Step 1: Read the current SKILL.md in full**

```bash
cat plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md
```

- [ ] **Step 2: Write a brief Data flow section**

Content source: spec §8. One short section (this doesn't need its own `##` heading if it
reads better folded into the end of the Architecture/Phases material Task 2/3 already wrote —
use your judgment on placement, but the content must appear somewhere): Phase 0's output
seeds every later phase; Phase 1 produces the unit map plus unconfirmed candidates; Phase 2
confirms/dismisses using full unit context; Phase 3 reads only Phase 0/1's context (not
Phase 2's per-unit output) so it runs fully in parallel; Phase 4 is independent of everything
else; Synthesis is the only stage that reads across all of it.

- [ ] **Step 3: Write Error handling & degradation**

Content source: spec §9 (as fixed by adversarial review). Cover, as a bulleted list matching
the style of `ship`'s Guardrails section: not a git repo → hard stop; repo too large for the
agent budget — **be precise that the 1000-agent `Workflow` cap applies to the Phase 0–3
script specifically**, Phase 4's three `Skill` invocations sit outside it with their own
existing budgets, Phase 1's batching keeps its own share small, Phase 2's one-agent-per-unit
cost is what scales — surface plainly and recommend subtree scoping rather than silently
doing a partial audit; a sub-skill unavailable or denied → note the gap, continue (matching
`ship`/`review-pr`'s resilience pattern); no test framework or no docs site → not errors,
inputs to Phase 3's discovery (a repo with no tests might itself surface as a finding); if
`generate-docs` fails partway through its writes → surface plainly in the final report, the
human needs to know the working-tree diff might be incomplete.

- [ ] **Step 4: Write Verification / testing guidance, as advice to the human running this**

Content source: spec §10 (as fixed by adversarial review) — this is the one place the spec
explicitly requires the skill's *own prose* to say something, not just the plan/spec: state
directly that a first run should be scoped to a single subtree (e.g. one plugin) to
sanity-check phase behavior and report shape cheaply, before a genuine whole-repo pass — and
say plainly that this "cheap" framing applies to Phases 0–3 and `review-pr`, **not** to
`generate-docs`/`pre-public-hardening`, which always run at full native scope per Phase 4 —
so even a subtree-scoped dry run still pays their whole-repo cost.

- [ ] **Step 5: Final whole-document self-review**

Read the entire `SKILL.md` fresh, top to bottom, as if you had not written it. Check:
placeholder scan (no "TBD", no "add appropriate handling", no unresolved brackets); every
spec §4 "Key decisions" row is reflected somewhere in the file (list any gap and fix it before
moving on); every cross-reference (`generate-docs`, `review-pr`, `pre-public-hardening`,
`handle-task-tracking`, `ship`, `reference/lens-examples.md`) resolves to something real —
grep for each name and confirm the surrounding sentence is accurate; the file reads in one
consistent imperative voice throughout, not as three differently-toned sections stitched
together (Tasks 2, 3, and 4 were three different fresh-subagent passes — this is exactly the
seam most likely to show).

- [ ] **Step 6: Gate-clean and commit**

```bash
uvx prek run --files plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md
```

Expected: green.

```bash
git add plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md
git commit -m "feat(dev-kit): complete dry-dock-overhaul with error handling and verification guidance"
```

---

## Task 5: Quality validation

**Files:**

- Modify: `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` and/or
  `reference/lens-examples.md`, as needed to address findings.

**Interfaces:**

- Consumes: the complete skill from Task 4.
- Produces: a validated skill ready for the end-to-end smoke test in Task 6.
- [ ] **Step 1: Run the plugin-dev reviewers**

Dispatch `plugin-dev:skill-reviewer` on `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md`
and `plugin-dev:plugin-validator` on the `dev-kit` plugin as a whole.
Expected: no blocking issues. Apply any must-fix feedback (triggering-description quality,
structural issues, frontmatter correctness).

- [ ] **Step 2: Run the full local gate**

```bash
uvx prek run --all-files
```

Expected: green.

- [ ] **Step 3: Commit any fixes from Steps 1-2**

```bash
git add plugins/dev-kit/skills/dry-dock-overhaul/
git commit -m "fix(dev-kit): address dry-dock-overhaul reviewer/gate findings"
```

(Skip this commit if Steps 1–2 found nothing to fix.)

---

## Task 6: End-to-end smoke test, then a scope checkpoint with the human

Prove the skill actually behaves sensibly by running it for real — this is the closest
equivalent to an integration test a prose-orchestration skill can have. **Decision
checkpoint, mirroring the precedent `generate-docs` plan's Task 5:** do not run a genuine
whole-repo pass against this marketplace without the human's explicit go-ahead first — a
whole-repo run is exactly the expensive, rarely-run operation this skill's own spec describes,
and the smoke test's job is just to prove the phases cohere, not to produce a real audit
deliverable yet.

**Files:**

- Modify: `plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md` and/or
  `reference/lens-examples.md`, if the smoke test surfaces prose that doesn't match reality.

**Interfaces:**

- Consumes: the validated skill from Task 5.
- Produces: a go/no-go on whether the skill is ready to hand off, and (if the human wants it)
  a genuine first run.
- [ ] **Step 1: Smoke-test against a small subtree of this repo**

Invoke `/dev-kit:dry-dock-overhaul` scoped to one small existing plugin in this marketplace
(e.g. `plugins/worktree-guard/` or `plugins/castify/` — pick whichever is smallest at the
time this task runs) rather than the whole repo. Follow the skill's own Phase 0–5 as written.
Expected: Phase 0 correctly classifies this repo as a marketplace; Phase 1 produces a
sensible unit map scoped to just that plugin; Phase 2 produces exceptions-only findings (or
none, if the plugin is clean) without crashing; Phase 3's discovery step proposes lenses that
actually fit what that subtree contains (e.g. no docs-UX lens if that plugin has no docs of
its own); Phase 4 correctly narrows `review-pr` to the subtree while `generate-docs` and
`pre-public-hardening` still run at full repo scope (per Phase 4's documented behavior); the
final report renders the fixed skeleton (tally header, severity-ranked findings, a
`generate-docs`-changes callout if any, a verdict paragraph) and is not committed anywhere.

- [ ] **Step 2: Fix anything the smoke test reveals**

If any phase's actual behavior doesn't match what `SKILL.md` says it should do, fix the prose
(not the smoke-test's expectations) — the smoke test is grounding truth here. Re-run Step 1
after any fix until it behaves as documented.

- [ ] **Step 3: Gate-clean and commit any smoke-test fixes**

```bash
uvx prek run --files plugins/dev-kit/skills/dry-dock-overhaul/SKILL.md
git add plugins/dev-kit/skills/dry-dock-overhaul/
git commit -m "fix(dev-kit): correct dry-dock-overhaul prose per smoke-test findings"
```

(Skip if Step 1 revealed nothing to fix.)

- [ ] **Step 4: Scope checkpoint with the human**

Present: "Skill implemented and smoke-tested against a subtree. A genuine whole-repo run
against this marketplace is the real, expensive deliverable this skill is for — want me to
run one now, or hand this off as-is and let you invoke it yourself when you're ready?" Proceed
per their answer; do not run a whole-repo pass unprompted.

---

## Self-Review (completed during planning)

**1. Spec coverage.** Walked every spec section (§1–§11) and confirmed a task step cites it
as a content source: §1/§2/§3 → Task 2 Step 1; §4 (key decisions table) → Task 4 Step 5's
explicit per-row check; §5 Phase 0–2 → Task 2 Steps 2–4; §5 Phase 3–5 → Task 3 Steps 2–4; §6
→ Task 3 Step 5; §7 → Task 3 Step 6; §8 → Task 4 Step 2; §9 → Task 4 Step 3; §10 → Task 4
Step 4 and Task 6 (the staged-subtree-first advice is both written into the skill's prose
*and* actually followed by this plan's own Task 6 Step 1); §11 (out of scope) is a set of
negative constraints, not content to write — verified none of Tasks 1–6 accidentally
implement any of it (no auto-fix machinery, no cross-run persistence, no sub-pass toggles, no
auto-triggering hook).

**2. Placeholder scan.** No "TBD"/"TODO" in this plan's own steps; every step names exact
files, exact commands, and exact spec sections as content sources rather than "write
appropriate content." The one placeholder that's deliberate and self-correcting is Task 1
Step 1's literal `(placeholder — full body written in Task 2-4)` line inside the *skill file
being created* — that's the point of Task 1 (scaffold before body), and Task 2 Step 1
overwrites it as its first action.

**3. Type/name consistency.** Checked that terms introduced in one task are used identically
later: "unit map" (Task 2 Step 3) is the exact term Task 3 Step 2 references; "Workflow
script" / "Skill invocations" (Task 3 Step 5) match how Task 3 Step 4 and Task 4 Step 3
describe the same two execution levels; the severity scale name
("blocker/major/minor/nit", Task 3 Step 6) is the one Task 3 Step 4 (Synthesis) and Task 4
Step 3 (error handling doesn't use it, correctly — errors aren't findings) both stay
consistent with. `reference/lens-examples.md`'s exact relative path is used identically in
Task 3 Steps 2 and 6.
