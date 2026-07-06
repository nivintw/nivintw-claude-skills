---
title: dev-kit open-work
---

# open-work

Answer "what should I pick up next?" from the repo's open GitHub issues — the durable task
ledger. Returns the full ranked, reasoned list of ready work, leading with your in-flight
work to resume, instead of you eyeballing the whole issue list.

## Usage

```text
/dev-kit:open-work    # rank the current repo's open issues
```

Natural-language forms work too: *"what should I work on next"*, *"what's in progress"*,
*"shortlist my ready work"*, *"rank my issues"*.

## What it does

A bundled script does the mechanical half — list open issues, partition by status label,
resolve each candidate's linked-PR merge state and `Blocked by #N` references, and apply the
priority × staleness sort. Judgment stays on top: issue bodies are read only where a one-line
*why this one* rationale is being written.

The output is a fixed five-part contract, the same shape every run:

1. **Tally line** — repo name plus `open · ready · in progress · untriaged` counts.
2. **Resume in progress** — your in-flight work first (usually, finish what you started),
   then others', with stalled rows flagged.
3. **Start next** — every `status:ready`, startable item, ranked and never capped to a
   top-N, with rationale lines for the standout picks.
4. **Needs attention** — the untriaged count, blocked items, and done-but-open issues whose
   linked PR already merged.
5. **Next action** — one paragraph naming the single best move.

On an unlabeled ledger (no `status:*` labels anywhere) it degrades rather than fails: same
skeleton, best-effort ranking from whatever signal exists, flagged plainly as such — with a
pointer to `handle-task-tracking` to establish the labels.

## When to reach for it

This is the **select** verb in the dev-kit loop — between grooming the ledger
(`handle-task-tracking`) and executing the pick (`ship`). Reach for it whenever you want a
recommendation of what to start or resume, not a raw issue dump. It is read-only: it never
mutates the ledger, and it works on a single repo (no cross-repo aggregation).

!!! note "Resume beats start"
    When one of *your* in-progress items stands out, the recommendation is to resume it —
    check out its branch or reopen its PR and keep going. `ship` starts fresh work; it does
    not resume an in-flight branch.

## Related

- [`handle-task-tracking`](handle-task-tracking.md) — owns the status-label model open-work
  reads; grooming (triage, relabel, close) happens there.
- [`ship`](ship.md) — executes the chosen pick, from idea to a review-ready PR.
