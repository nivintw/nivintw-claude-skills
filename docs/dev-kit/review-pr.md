---
title: dev-kit review-pr
---

# review-pr

The single review entry point. Fans out the full reviewer battery plus a bespoke adversarial
pass, then synthesizes everything into one prioritized report — instead of a pile of
overlapping outputs. Works on your own diff, a teammate's PR, or a whole repo.

## Usage

```text
/dev-kit:review-pr        # review the current branch / this session's PR
/dev-kit:review-pr 42     # review a teammate's PR by number (or branch)
```

Natural-language forms work too: *"review this PR"*, *"review my changes before I open a
PR"*, *"sanity-check this diff"*, *"review PR #42"*.

## What it does

Detects one of three modes (and states it up front):

| Mode | Target | Goal & key behavior |
| --- | --- | --- |
| **A** | Your own PR, pre-handoff | Catch everything before a human looks — applies safe fixes and re-runs. What `ship` runs before opening its PR. |
| **B** | A teammate's PR | A high-signal review *for them*. Never pushes to their branch; posts comments only with explicit confirmation. |
| **C** | Whole-repo audit | Points the same battery at the entire codebase (no diff) and saves a report — a baseline picture of codebase health. |

Then it fans out the battery — concurrently where possible — and collects every finding:

1. `/code-review` — correctness bugs plus reuse/simplification cleanups, workflow-backed at
   high effort in Modes A and C.
2. `/security-review` — security review of the pending changes.
3. `/pr-review-toolkit:review-pr` — the specialized agent suite (silent failures, type
   design, test coverage, comment accuracy).
4. A bespoke **adversarial pass** — picks the 2–4 failure modes most damaging for *this*
   change and actively tries to break it.
5. An optional **second-opinion model** — a different (cheaper or local) model as an extra
   lens; its claims are verified against the code, never trusted outright.

Everything is synthesized into **one prioritized report**: de-duplicated, ranked blocker →
nit with sources labeled, must-fix separated from consider, ending in a clear verdict.

## When to reach for it

Any diff or PR worth a real review — your own before hand-off, or a teammate's by number or
branch. It right-sizes itself: a one-file docs/typo PR skips the security and adversarial
passes, and it says which passes were skipped and why. Two rules are stricter than a plain
diff review:

- A real bug in code the diff touches counts **even if it predates the change** — it's
  flagged as pre-existing, never waved past.
- Newly added suppressions (`# noqa`, `# type: ignore`, `@ts-ignore`, and kin) are findings:
  each must carry a rationale or be removed and fixed properly.

!!! note "Mode C is a deliverable, not a glance"
    A whole-repo audit scopes every reviewer to the entire codebase — expect significantly
    higher cost and runtime than a diff review, with a saved report at the end.

## Related

- [`ship`](ship.md) — runs this automatically before opening its PR; Mode A is its
  pre-handoff pass.
- [`land`](land.md) — once the review converges and the PR is approved, drives it to
  merged.
- [`dry-dock-overhaul`](dry-dock-overhaul.md) — runs Mode C as one of its whole-repo audit
  passes.
