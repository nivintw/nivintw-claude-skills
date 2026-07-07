---
name: land
description: >-
  This skill should be used when the user asks to "land" a change or PR — "land it", "land
  this", "land #N", or a bare "/land" — meaning: take a change all the way to merged without
  waiting for a human hand-off. It is a thin modifier on /dev-kit:ship: bare /land runs ship's
  full idea→PR workflow and then autonomously merges instead of handing off (functionally
  identical to "/ship … and land it"); "land it" mid/after a ship run lands that run's PR; and
  "land #N" attaches to an existing PR and drives it to merged. It does NOT change the quality
  bar — all required CI checks and (usually) Copilot convergence still gate the merge; land only
  removes the human-wait. The landing loop itself is NOT duplicated here — this skill delegates
  to ship's own "Land the PR" verb and its pr-landing-driver reference. Reach for it whenever the
  user wants a change merged autonomously ("I'm walking away — get this live").
---

# land

`land` is a **first-class, discoverable entry point to ship's own merge verb**, invoked the way
`/ship` is. It is a **modifier on `/ship`, not a separate PR-lander**: `/ship` runs the full
idea→PR workflow and **hands off to a human** (draft → ready-for-review, then stops); `land`
says *"don't hand off — the moment you'd normally hand off, merge it yourself."* Intent: *"I'm
walking away; get this live without needing me."*

**It does not change the quality bar.** All required CI checks must pass, and Copilot
convergence still applies as usual (required *usually*, but situational — land neither forces
nor skips it). Land removes only the *human-wait*, never a gate.

## Invocation matrix

| Invocation | Meaning |
|---|---|
| **`/land`** (bare, no active ship run) | A `/ship` request **+ land** — functionally identical to `/ship … and land it`: run the full workflow, then autonomously merge instead of handing off. |
| `/land it` (mid/after a ship run) | Land *this* run's PR (the PR ship opened for the current worktree's branch). |
| `/land #N` | Attach to existing PR #N and drive it to merged (the standalone `pr-landing-driver` entry). |
| `/ship … and land it` | Land granted up front — the existing Phase 1 carve-out. |

## How it works — delegate, never duplicate

The landing **mechanics already exist** in ship's **Land the PR** section and
[`../ship/reference/pr-landing-driver.md`](../ship/reference/pr-landing-driver.md). This skill is
a thin front door to that verb — **do not restate or re-implement the loop.**

- **Bare `/land`** → treat exactly as `/ship … and land it`: invoke **`/dev-kit:ship`** with
  `land` granted up front, so Phase 1's carve-out applies (design/plan choices for the rest of
  the run get *decided and logged*, not re-confirmed) and, at the point ship would hand off, it
  merges instead.
- **`/land it`** (mid or after a ship run) → run ship's **Land the PR** loop on this run's PR.
- **`/land #N`** → run ship's **Land the PR** loop via its standalone entry, resolving PR #N
  (or the current branch's open PR when no number is given). If there's no open PR for the
  branch, say so and stop.

Everything else — CI-to-green, Copilot convergence, `waiting:ci`/`waiting:copilot` parking
backed by a real watch, rebase-merge, and Post-merge cleanup — is ship's, run unchanged. The
merge gate is **not** relaxed: land only removes the human hand-off wait.

`land` is **explicit and opt-in** — this skill runs only when the user asks for it. The bundled
[`../../commands/land.md`](../../commands/land.md) command is a thin forwarder to this skill, so
there's a single place the semantics live and no second copy to drift.
