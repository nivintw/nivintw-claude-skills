---
name: review-pr
description: >-
  Use when the user asks to "review this PR", "review my changes before a PR", "do a pre-merge
  review", "sanity-check this diff", or "review PR #N" / a teammate's branch. The single
  review entry point: runs and synthesizes the review battery — /code-review, /security-review,
  /pr-review-toolkit:review-pr, plus a context-chosen ADVERSARIAL pass — right-sized to the
  diff, into one prioritized report instead of overlapping outputs. /dev-kit:ship calls it
  automatically before opening its PR.
---

# review-pr

One review entry point that fans out specialized reviewers, then **synthesizes** their
findings into a single prioritized report — instead of a pile of overlapping outputs.

## Modes (detect, don't ask if obvious)

- **Mode A — your own PR, pre-handoff.** Default when reviewing the current branch / a PR
  authored in this session. Goal: catch everything *before* a human looks. **Apply** safe
  fixes and re-run; surface anything judgment-heavy for the human at hand-off.
- **Mode B — a teammate's PR.** When given a PR number / branch authored by someone else.
  Goal: a high-signal review *for them*. **Do not push changes to their branch.** Post findings
  by **staging a GitHub *pending* review and deliberately not submitting it** (see *Posting
  findings* below): Claude drafts every inline comment, and the human owns the
  APPROVE / REQUEST_CHANGES / COMMENT verdict by clicking Submit.
- **Mode C — whole-repo audit.** For a first-time / never-been-reviewed repo, or when the
  user explicitly asks to review the entire codebase rather than a diff. Points the same
  reviewer battery at the whole codebase (or a named subtree) instead of a diff, and
  **saves a report** — the audit is a deliverable, not an inline glance. Distinct from Modes A
  and B: there is no PR or branch scope; the goal is a baseline picture of codebase health.

State the detected mode and the review target (branch / PR # / subtree) up front.

## Establish the scope first

Identify exactly what's under review (`git diff <base>...HEAD`, or the PR's files via
`gh pr diff <n>`). For Modes A/B every reviewer below scopes to that diff. Note the base branch, the
files touched, and the change's *intent* — the adversarial pass needs the intent to know
what "broken" means. **In Mode C there is no diff** — scope the battery to the whole
codebase (or the named subtree) instead; expect significantly higher cost and runtime.

"Scopes to that diff" bounds *where you look*, not *what counts as a finding*. A real bug or
broken behavior in the code the diff touches is a finding **even if it predates this
change** — "it was already like that" is never a reason to wave it past. Surface it (and, in
Mode A, fix the safe ones); flag it as pre-existing so the human can weigh it, rather than
silently dropping it because it's older than the diff.

### Materialize a fetched PR's head into a worktree (Mode B, and Mode C on a remote PR)

`gh pr diff <n>` gives you the *diff*, but the working-tree reviewers in the battery
(`/security-review`, the `/pr-review-toolkit` suite) read the **current working tree**, not the
diff. On a PR you only fetched, that tree is still your own branch — so those reviewers would
read the wrong (or an empty) tree and their findings would be meaningless. Before running them,
check the PR head out into a dedicated worktree and run the battery there:

- **Capture the PR head SHA *before* any other fetch.** Every `git fetch` overwrites
  `FETCH_HEAD`, so grab it first — `PR_HEAD=$(gh pr view <n> --json headRefOid -q .headRefOid)`
  (or `git fetch origin pull/<n>/head` and immediately read `FETCH_HEAD`) — and only fetch the
  base branch *after* `PR_HEAD` is captured.
- **Resolve `--git-common-dir` absolutely.** From inside a worktree, `git rev-parse
  --git-common-dir` can return a **relative** path; resolve it to an absolute path before using
  it to place the new worktree.
- **Check out `PR_HEAD` into a dedicated worktree** (`git worktree add <path> "$PR_HEAD"`, under
  `.claude/worktrees/`) and point the working-tree reviewers at that worktree, so every reviewer
  reads the PR's actual tree. Tear the worktree down when the review is done.

Mode A already runs in the branch's own worktree, so a reviewer there never reads the wrong tree.

## The battery — default to the full set, right-sized

Run these and collect their findings. Prefer running them concurrently (fan them out as
subagents, or via `/workflows`) since they're independent; fall back to sequential.

**Each reviewer's return is a hand-back, not a stopping point.** A sub-skill like
`/security-review` returns a self-contained report that *looks* terminal — do not yield when
it comes back. Collect its findings and move on to the next pass, then to synthesis. The
review isn't done until you've merged every pass into the one report below (and, in Mode A
under `/dev-kit:ship`, continued into the gate and PR phases).

**Right-size, and degrade gracefully.** Scale to what the diff *touches*, not its size:
docs-, prose-, or comment-only changes and cosmetic config skip the security and adversarial
passes, but any security-sensitive surface (auth, input, secrets, network, deserialization,
file/path, permissions) or non-trivial code change keeps `/security-review` — a one-line
change isn't automatically safe. Say which passes are being skipped and why. And
if an orchestrated skill isn't installed or is denied (e.g. `/security-review`,
`/pr-review-toolkit:review-pr`), note that the coverage is missing and continue with the
rest rather than failing the whole review. Conversely, **reach for any other relevant skill
or agent the environment offers** — including ones not listed here and ones added after this
was written (e.g. a specialized reviewer that fits the kind of change at hand); survey what's
installed rather than treating this list as exhaustive.

1. **`/code-review`** — correctness bugs + reuse/simplification/efficiency cleanups. In
   **Mode A** (pre-handoff) default to the **higher-effort, workflow-backed pass** — run the
   battery via `/workflows` (fanning the reviewers out as a workflow) at high effort, rather
   than a quick inline glance; low-effort inline review is reserved for spot checks, not
   pre-handoff. **Mode C** likewise runs workflow-backed at high effort. Effort is chosen by
   context, not manually escalated each run.
2. **`/security-review`** — security review of the pending changes.
3. **`/pr-review-toolkit:review-pr`** — the specialized agent suite (silent-failure,
   type-design, test coverage, comment accuracy, etc.).
4. **Adversarial review** — see below. This one is bespoke each run.
5. **Independent second-opinion model** *(optional)* — a *different* model fails differently, so a second
   read from a cheaper tier or a local model is a genuine extra lens at low cost (for a local
   Ollama model, the detect-and-shell-out recipe in
   [`../ship/reference/local-model-offload.md`](../ship/reference/local-model-offload.md)
   applies here too). Hand it a
   self-contained artifact (a whole script or tight diff) and ask it to break the change. But
   **verify its claims**: its failure mode is misreading control flow and low signal on subtle
   logic, so treat its output as candidate findings to confirm, never as authority. Skip it
   when the change can't be understood without the whole repo (it has no repo access).
6. **Newly-added suppressions are findings (standing, every run).** A built-in `/code-review`
   or `/simplify` may quietly accept a silenced check as a "cleanup" — this battery does not.
   Scan the change's **added (`+`) lines** for suppressions it **newly applies to real code**:
   `# noqa` / `# ruff: noqa`, `# type: ignore` / `# pyright: ignore`, `// @ts-ignore` /
   `// @ts-expect-error`, `eslint-disable*`, `# pragma: no cover`, broad `per-file-ignores` table
   entries, blanket `# fmt: off`, and the like. Each one is a **finding**: it must either carry
   a one-line rationale for why the underlying issue genuinely can't be fixed here, or be
   removed and **fixed properly** — this enforces the standing *do the actual work — no
   suppressions* rule. Key on *newly silencing a check*, not on the token appearing in the
   diff: a suppression the change merely **relocates** (already justified, just moved) silences
   nothing new, and a literal token in **prose, docs, or a test fixture** (this very skill file
   names several as examples) isn't active code — neither is a finding. Pre-existing
   suppressions the diff doesn't touch are likewise out of scope unless the change is
   explicitly about them (per the "scopes to that diff" rule above).
7. **Defer new-syntax validity to the toolchain (standing, every run).** The model's sense of
   what is *syntactically valid* lags the language. If the repo's configured toolchain — the
   linter, type-checker, or compiler (ruff / ty / tsc / rustc / …) — accepts the code, it **is**
   valid: **never raise a "syntax error" finding the configured tooling doesn't also raise.**
   Canonical trap: PEP 758's parenthesis-less `except A, B:`, valid on current Python but read as
   a syntax error by an older internalized grammar. More generally, any construct newer than the
   model's grammar looks wrong while the toolchain is green on it — that's stale grammar, not a
   bug. (Language-agnostic: it's about deferring to *whatever* toolchain the repo runs, not about
   Python.)

## Adversarial review (interpret per change, every time)

Spin up an independent pass (a subagent, or a small `/workflows` panel) whose only job is
to **break this specific change** — not to confirm it works. Choose the angle of attack
from the repo and the diff; do not run a fixed checklist. Pick the 2–4 failure modes most
damaging *for this change*, e.g.:

- A **parser / input handler** → malformed, adversarial, oversized, empty, and
  encoding-edge inputs; "tests pass but it mishandles the real case."
- **Auth / permissions** → privilege escalation, missing checks on a path, IDOR, token
  handling.
- A **plugin / skill** → malformed frontmatter, missing dependency, namespace clash,
  what happens when an invoked tool/skill is absent or denied.
- **Concurrency / state** → races, partial failure, retries, idempotency.
- A **migration / mass edit** → the sites it missed, the rollback story.
- **CI / release / shell** → secret leakage, `set -e` gaps, injection from untrusted
  inputs, non-idempotent steps.

State the chosen angles and *why those*, then report what actually breaks (with a repro
or concrete path), not hypotheticals.

## Synthesize

Merge every pass you ran into ONE report:

- **De-duplicate** overlapping findings; keep the clearest statement of each.
- **Rank by severity** (blocker → major → minor → nit) and label the source.
- Separate **must-fix** from **consider**.
- Findings from the second-opinion model (item 5) fold in **clearly marked as
  untrusted / needs-verification** — confirm each against the code before counting it as
  must-fix; never promote to must-fix on the model's word alone.
- End with a clear verdict: ready to hand off / merge, or the specific blockers remaining.

## Posting findings — stage a pending review, never submit

When findings are posted inline to a GitHub PR (Mode B, and Mode A whenever you want them on the
PR rather than applied directly), post them by **staging a GitHub *pending* review and leaving it
unsubmitted** — never by submitting a review. This is an intentional **human-in-the-loop guard**,
not just UX: *submitting* a review issues an **APPROVE / REQUEST_CHANGES / COMMENT verdict**, and
the agent must never issue that verdict autonomously. Staging-without-submit lets Claude do the
whole review — every inline comment drafted and attached — while the **human owns the verdict**:
they open the PR, read the staged comments, and click Submit with their decision.

- **Clear the agent's own stale pending review first.** GitHub allows **one pending review per
  user per PR**, so a prior *agent* run's leftover unsubmitted review would make this run's
  comments **append onto the stale one**. Before staging, dismiss the agent account's own
  leftover pending review (never a human's in-progress one) so each run produces a clean review.
- **Stage, don't submit.** Create a pending review (`pull_request_review_write` with method
  `create` via the GitHub MCP), attach each inline finding
  (`add_comment_to_pending_review`), and **stop there** — do not call submit / approve /
  request-changes.
- **Hand off plainly:** tell the human *"review staged as a pending review — open the PR and
  Submit with your verdict."*

The existing guards still hold: never push to a teammate's branch, and the **submit** — the one
outward, verdict-issuing action — is always the human's.

## Then

- **Mode A:** apply the safe must-fixes, re-run the relevant reviewer to confirm, and hand
  the author the residual judgment calls. Leave the branch green.
- **Mode B:** present the synthesized review and **stage it as an unsubmitted pending review**
  (see *Posting findings*); hand off with "open the PR and Submit with your verdict."
