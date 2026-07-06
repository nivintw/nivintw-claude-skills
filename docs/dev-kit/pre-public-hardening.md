---
title: dev-kit pre-public-hardening
---

# pre-public-hardening

A whole-repo, full-history readiness review before a private repo goes public. Once
visibility flips, every commit ever made is public — not just the current tree — so this
skill audits the entire history and hands you a go/no-go checklist to sign off before you
flip the switch.

## Usage

```text
/dev-kit:pre-public-hardening
```

Natural-language forms work too: *"make this repo public"*, *"is this repo safe to
open-source?"*, *"scan the git history for secrets"*, *"harden before publishing"*.

## What it does

Four audits, then a checklist:

1. **Full-history secret scan** — `gitleaks git --log-opts="--all"` walks every commit on
   every ref. This is the check a commit-time hook cannot do: the gate's gitleaks sees only
   the working tree, so a secret committed and later deleted is invisible to it but still
   fully present in `.git`. Any hit means rotate the secret, then physically remove it.
2. **`.gitignore` audit** — secret patterns (`.env`, keys, certs, local overrides) are
   present, and no overly-broad pattern silently hides files that should be tracked
   (cross-checked with `git ls-files --cached --ignored --exclude-standard`).
3. **Private-artifact flush** — docs, comments, and commit messages are scanned for
   private-context tells: session-transcript fragments, internal-audience TODOs, AI
   attribution boilerplate, unresolved scratch notes.
4. **License & SPDX completeness** — the intended license is present and correct (a root
   `LICENSE` suffices); if the repo uses REUSE/SPDX, `reuse lint` must pass.

The output is a **go/no-go checklist** — every item a hard gate — that the human signs off
before flipping visibility. The skill detects and prescribes; it never flips visibility or
rewrites history itself.

## When to reach for it

Whenever a private repo is about to be made public or open-sourced — and only then. This
sits deliberately outside `ship`'s loop: it's always human-triggered, never called
automatically, because going public is a deliberate, one-way decision. It complements the
gate's working-tree gitleaks scan rather than replacing it; for a security review of the
code itself, reach for `/security-review` instead.

!!! warning "Deleting a leaked secret is not removing it"
    A secret deleted in a later commit is still in every prior commit, every clone, and
    GitHub's object store. The only fix is to rotate it immediately, rewrite history with
    `git filter-repo` (or BFG), then force-push and have collaborators re-clone — and the
    human does the rewriting, not this skill.

## Related

- [`dry-dock-overhaul`](dry-dock-overhaul.md) — the exhaustive whole-repo audit that runs
  this skill as one of its passes.
- [`review-pr`](review-pr.md) — per-change review of a diff; this skill audits the whole
  repo and its full history instead.
- [`ship`](ship.md) — the everyday loop this deliberately sits outside of; ship never
  triggers it.
