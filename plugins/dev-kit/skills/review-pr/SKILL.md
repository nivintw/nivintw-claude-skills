---
name: review-pr
description: >-
  This skill should be used when the user asks to "review this PR", "review my changes
  before I open a PR", "do a pre-merge review", "sanity-check this diff", or "review PR #N"
  / a teammate's branch. It is the single review entry point: it runs and synthesizes the
  full battery — /code-review, /security-review, /pr-review-toolkit:review-pr — plus a
  context-chosen ADVERSARIAL pass that actively tries to break the change, then merges
  everything into one prioritized report instead of a pile of overlapping outputs. Reach
  for it on a PR authored in this session (pre-handoff) or a teammate's PR by number or
  branch, rather than invoking the individual review skills one at a time.
  /dev-kit:ship calls it automatically before opening its PR.
---

# review-pr

One review entry point that fans out specialized reviewers, then **synthesizes** their
findings into a single prioritized report — instead of a pile of overlapping outputs.

## Two modes (detect, don't ask if obvious)

- **Mode A — your own PR, pre-handoff.** Default when reviewing the current branch / a PR
  authored in this session. Goal: catch everything *before* a human looks. **Apply** safe
  fixes and re-run; list anything judgment-heavy for the author.
- **Mode B — a teammate's PR.** When given a PR number / branch authored by someone else.
  Goal: a high-signal review *for them*. **Do not push changes to their branch.** Posting review
  comments is an outward-facing action — draft the review, show it, and only post with
  explicit confirmation (`/pr-review-toolkit:review-pr` and `/code-review --comment` can
  post; use them only after the user says to).

State the detected mode and the review target (branch / PR #) up front.

## Establish the diff first

Identify exactly what's under review (`git diff <base>...HEAD`, or the PR's files via
`gh pr diff <n>`). Every reviewer below scopes to that diff. Note the base branch, the
files touched, and the change's *intent* — the adversarial pass needs the intent to know
what "broken" means.

## The battery — always all four

Run these and collect their findings. Prefer running them concurrently (fan them out as
subagents, or via `/workflows`) since they're independent; fall back to sequential.

**Right-size, and degrade gracefully.** Scale to the change: a one-file docs/typo PR
doesn't need the security or adversarial passes — say which passes are being skipped and why. And
if an orchestrated skill isn't installed or is denied (e.g. `/security-review`,
`/pr-review-toolkit:review-pr`), note that the coverage is missing and continue with the
rest rather than failing the whole review.

1. **`/code-review`** — correctness bugs + reuse/simplification/efficiency cleanups.
2. **`/security-review`** — security review of the pending changes.
3. **`/pr-review-toolkit:review-pr`** — the specialized agent suite (silent-failure,
   type-design, test coverage, comment accuracy, etc.).
4. **Adversarial review** — see below. This one is bespoke each run.

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

Merge all four sources into ONE report:

- **De-duplicate** overlapping findings; keep the clearest statement of each.
- **Rank by severity** (blocker → major → minor → nit) and label the source.
- Separate **must-fix** from **consider**.
- End with a clear verdict: ready to hand off / merge, or the specific blockers remaining.

## Then

- **Mode A:** apply the safe must-fixes, re-run the relevant reviewer to confirm, and hand
  the author the residual judgment calls. Leave the branch green.
- **Mode B:** present the synthesized review; post it only on explicit confirmation.
