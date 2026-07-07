---
description: Land an open PR (or ship-and-land) — drive CI to green, converge the automated review, rebase-merge, and clean up. Thin forwarder to the dev-kit land skill.
argument-hint: "[PR number]"
---

# Land

Invoke the **`/dev-kit:land`** skill against `$ARGUMENTS` and follow it in full.

This command is a **thin forwarder** — it holds no landing logic of its own. The `land` skill
owns the invocation matrix (bare land ≡ ship-and-land, `land it`, `land #N`) and delegates the
actual loop to `ship`'s **Land the PR** verb and its `pr-landing-driver` reference. Keeping the
semantics in one place (the skill) is deliberate: there's no second copy here to drift.
