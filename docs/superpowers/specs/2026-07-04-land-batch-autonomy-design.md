# land batch autonomy: don't re-confirm, group into minimal PRs, persist every call

**Status:** design approved (brainstorming), implemented
**Date:** 2026-07-04
**Tracking issue:** [#104](https://github.com/nivintw/nivintw-claude-skills/issues/104)
**Plugin:** `dev-kit` · skill `ship` (+ its `land` command wrapper)

## 1. Summary

Change `/dev-kit:ship`'s `land` verb so that granting it up front — "ship and land this,"
"land these five issues" — stands as a one-time authorization for design and plan choices,
not just for the eventual merge. Today, granting `land` doesn't stop `ship`'s Phase 1 plan
sign-off gate from blocking, and it doesn't stop downstream sub-flows (like
`superpowers:writing-plans`' Subagent-Driven-vs-Inline question) from pausing mid-run to
re-ask something the user already implicitly settled by saying "land it." Three changes:

1. **Granting `land` implies design-autonomy for that run.** `ship` still writes its plan,
   still makes real choices, but never blocks waiting for a reply on a design/approach
   question — it picks a reasonable default, documents it, and keeps going.
2. **Every autonomous choice is persisted somewhere durable and greppable** — a fixed section
   in the PR body, mirrored as a tagged comment on the tracking issue — so a brand-new
   session, days later, can answer "what did you decide and why" from the PR/issue alone,
   with zero dependency on chat history.
3. **A batch of multiple items auto-detects and defaults to the fewest PRs that make sense**
   (bias toward exactly one, split only for concrete risk-isolation reasons), so review
   cycles aren't multiplied by how many issues happened to get worked in one sitting.

## 2. Motivation

A repo-spanning investigation of session transcripts (`~/.claude/projects/*/*.jsonl` across
`nivintw-claude-skills`, `dotfiles`, `copier-everything`, `scaffold`, and `repo-management`,
2026-06-26 through 2026-07-04) found both problems recurring, not isolated:

- **PR grouping was asked for at least 5 times across 4 repos and never once made durable.**
  Every time, `ship` posed a fresh "how should these be packaged into PRs?" question, the user
  answered "one combined PR," and that answer evaporated at session end — no skill file,
  CLAUDE.md, or memory entry ever captured it as a standing default.
- **"Stop asking me" frustration recurred at least twice in one session alone** (this
  session, 2026-07-04) plus milder instances in two other repos — each time triggered by
  `ship` or a sub-flow (`writing-plans`' execution-choice question) pausing for a decision
  the user considered already settled by granting `land`.

Both problems share one root cause: `ship`'s current design treats "the human decides" as the
default at every choice point, with `land` only relaxing the *merge* decision. The fix is to
make `land` also relax the *design/approach* decisions for that run, while keeping every
other standing safety rule (destructive actions) untouched.

## 3. Key decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Granting `land` (not bare `ship`) triggers design-autonomy | Bare `ship` still hands off for human review before merge, so the plan sign-off gate stays valuable there; `land` is the explicit "go all the way" signal |
| 2 | The plan is still written, just not gated on approval | Documentation and audit trail don't disappear — only the blocking wait does |
| 3 | Every autonomous decision gets a fixed PR-body section (`## Decisions made without asking`) **and** a tagged issue comment | User must be able to retrieve the full record from the PR/issue alone, in a brand-new session, per explicit requirement |
| 4 | The PR-body section is always present, even when empty ("None — every choice matched the plan already discussed") | Absence must never be ambiguous between "nothing to report" and "forgot to document" |
| 5 | Issue comments use a consistent prefix (`Decision:`) | Greppable via `gh issue view <N> --json comments` without reading full history |
| 6 | Batch detection is automatic — no special phrasing required | The user's stated intent: batching heuristics should "just work," unlike the "don't ask" behavior which is unconditional on `land` regardless of batch size |
| 7 | Default grouping is one PR for the whole batch, with judgment-based risk-isolation splits | Strong bias toward fewest PRs (saves review cycles/tokens per the user's stated goal), but a single bad, hard-to-revert change shouldn't force reverting the whole batch |
| 8 | Batch-level decisions (e.g. the grouping choice, or what got split out and why) live on the tracking issue, not any one PR | A grouping decision isn't scoped to a single PR when a batch produces more than one |
| 9 | Destructive/irreversible-action confirmation (force-push, hard reset, deletion) is untouched | Explicitly confirmed: this feature relaxes design/plan confirmation only, never the standing safety rules around hard-to-reverse actions |
| 10 | Sub-flows that would normally ask their own execution-approach question (e.g. `writing-plans`' Subagent-Driven vs Inline) don't surface it under `land` | The same "don't ask, decide and document" principle applies transitively — `land`'s grant doesn't stop at `ship`'s own gates if `ship` delegates to something that asks its own |
| 11 | Batching/no-questions behavior is scoped to when `land` is granted; bare `ship` for a batch is unchanged | Matches the literal scope of what was asked; extending the minimal-PR default to bare `ship` is a natural, easy follow-up, not built now |

## 4. What changes, and where

The behavioral change is prose in two already-existing files — no new component, no new tool
surface. It also surfaces (and fixes) docs-site and manifest coverage gaps that predate this
change but became conspicuous while making it: `/dev-kit:land` and `/dev-kit:template-reconcile`
had zero presence in `docs/dev-kit.html`, `docs/index.html`, `docs/search-index.js`,
`plugins/dev-kit/.claude-plugin/plugin.json`, and `.claude-plugin/marketplace.json` despite
being real, shipped commands — those get their own entries here too, alongside this change's
actual behavioral core:

- **`plugins/dev-kit/skills/ship/SKILL.md`**
  - **Phase 1 — Plan**: add the design-autonomy carve-out. When `land` was granted as part
    of the original request, the plan sign-off gate is satisfied by that grant — write the
    plan and the batch's PR-grouping proposal (if applicable) into the progress file as
    always, but proceed straight to Phase 2 rather than blocking on `gate:plan-signoff`.
  - **New subsection under Phase 1 — Batching multiple items**: auto-detect a multi-item
    request, propose a grouping (default: one PR, judgment-based risk-isolation splits),
    document the grouping rationale on the tracking issue's decision log, and proceed without
    gating — same as any other autonomous decision.
  - **Phase 3 — Implement**: one addition — under `land`, if a sub-flow would normally
    surface its own execution-approach question, don't surface it; pick the sensible default
    and log it as a decision instead.
  - **Phase 8 — Commit + PR**: the PR-body template gains a required
    `## Decisions made without asking` section (always present; "None" when empty), built up
    incrementally rather than written once at the end.
  - A general statement (near the top of the `Land the PR` section, since that's the natural
    cross-reference point) of the overall principle: granting `land` extends "the human
    decides" from *only the merge* to *design/approach choices for this run*, with the
    destructive-action carve-out stated explicitly right next to it.
- **`plugins/dev-kit/commands/land.md`** — a short added line stating the design-autonomy
  implication directly, since this is the crisper, more-discoverable entry point a user (or a
  future Claude re-reading it) is likelier to read first than `ship`'s full Phase 1.

## 5. Persistence mechanics (the retrieval guarantee)

This is the load-bearing part, per explicit requirement: **a brand-new session must be able
to answer "what did you decide and why" from the PR or the issue alone — no dependency on
this conversation's memory.**

- **PR body — `## Decisions made without asking`.** One bullet per decision: what was
  decided, why (including any rejected alternative), and what the user might want to
  double-check. Updated as decisions happen during the run (checkpoint commits already
  update the PR description in-flight), not authored once at hand-off. Always present, even
  if the answer is "none."
- **Tracking issue — tagged comments.** Each decision also becomes an issue comment prefixed
  `Decision:`, per `handle-task-tracking`'s existing (currently soft) "post a comment when a
  decision is made" convention — made a hard requirement under `land` rather than a norm.
  This is the channel for batch-level decisions that aren't scoped to one PR (the grouping
  choice, what got split out).
- **Retrieval test** (used during implementation verification): in a fresh session,
  `gh pr view <N> --json body` and `gh issue view <N> --json comments` must together fully
  answer what was decided and why.

## 6. Batching mechanics

- **Trigger**: within a `land`-granted request, `ship` is handed more than one discrete item
  (multiple issue numbers, "these N issues," "the batch"). No special phrasing required for
  the grouping itself — it's auto-detected from the request's shape. This detection logic is
  separate from what triggers design-autonomy (§3 decision #1, unconditional on batch size —
  a single-item `land` run gets design-autonomy too, just with nothing to group), but both
  still require `land` to be part of the request; see Key decision #11 and §8.
- **Default grouping**: one PR for the whole batch. `ship`'s existing per-item conventional
  commits already carry enough signal for this repo's release-please to attribute version
  bumps correctly across plugin paths within a single PR (already proven organically in this
  session's PR #101, which combined two unrelated features).
- **Splits**: allowed only for concrete risk-isolation reasons (a change unusually large,
  risky, or hard to revert relative to the rest of the batch) — never for mere topical
  variety. Each split is itself a decision, logged per §5.
- **Not gated**: since `land` covers the batch, the grouping plan gets written and documented
  like any other decision — not held for a sign-off, per Key decision #2.

## 7. Error handling & degradation

- **Genuinely blocked** (unclear direction, missing input, a decision only the human can
  make, per the standing global "Auto Mode" rule) still warrants a pause — this feature
  narrows what counts as needing to ask, it doesn't eliminate the category entirely.
- **Destructive/irreversible actions** (force-push, hard reset, branch/file deletion) keep
  requiring explicit confirmation exactly as today — unaffected by this change.
- **A sub-flow that has no sensible default to fall back on** (e.g. two genuinely
  incompatible valid approaches with no way to infer preference) is itself blocked, not
  autonomous — that's the "genuinely blocked" case above, not a design choice to paper over.

## 8. Out of scope

- Extending the minimal-PR-grouping default to bare `ship` (without `land`) — an easy,
  separate follow-up if wanted later.
- Any change to the destructive-action confirmation rules.
- A new dedicated script or tool — this is entirely prose guidance to the executing Claude
  instance, matching how the rest of `ship`'s phases are specified.
- Retroactively fixing the decision-logging convention for repos other than this one; the fix
  lives in `dev-kit`'s own `ship`/`land` skill files and propagates automatically to every
  repo where `dev-kit` is installed (confirmed installed at the user level in `~/.claude.json`,
  not per-repo).
