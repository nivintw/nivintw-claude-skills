# The completeness critic

A shared dev-kit primitive: a **final pass that asks "what's missing?"** after a
multi-stage run, so the run's honest bound is discovered rather than assumed. Built once here
and called by more than one skill — `generate-docs` (Stage 6) and `dry-dock-overhaul` (its
exhaustion pass) both invoke it — so the mechanism can't drift between them. Each caller
supplies its own domain-specific "what counts as missing"; the mechanism below is the same.

## Why it exists

A pipeline reports on what it *ran*. It is silent about what it never ran — the modality it
didn't search, the source it didn't read, the surface it didn't map, the claim it asserted but
never verified. Silence there reads as "covered," and that false sense of completeness is
exactly the failure a rare, expensive, or trust-bearing run must not ship. The critic's job is
to convert that silence into an explicit list.

## The mechanism

Run it as the **last** stage, after the main work is done but before the run is declared
complete. Give it the run's own outputs (the work-list, the pages/findings produced, the
sources consulted) and one question, framed for the calling skill:

> **What is missing?** Name every gap you can — a modality that wasn't run, a source that
> wasn't read, a surface/dimension that wasn't covered, a claim asserted but not verified, an
> altitude of finding the run never reached. For each, say why it matters and what the next
> unit of work is.

Then act on the result:

1. **Loud, not silent.** Whatever the critic surfaces is stated in the run's report — never
   dropped. A gap you choose not to close is recorded as a **known blind spot**, not omitted.
2. **Feed it back.** A gap the run *can* close becomes the next round of work (author the
   missing page, run the missing modality, verify the unverified claim), then re-run the critic —
   until it surfaces nothing new. A single critic pass that fires once is weaker than a short
   loop-until-dry.
3. **Independent lens.** Run the critic as its own pass (a fresh subagent), not as a
   self-review by the same context that just did the work — the context that missed something
   is the least likely to notice it missed it.

## What each caller supplies

- **`generate-docs`** — "what public surface has no page, what page covers a topic at the wrong
  altitude, what modality (diagram, table, example) the content needed but didn't get." A
  *general* docs-affordance gap it surfaces is promoted into the shipped affordance rubric.
- **`dry-dock-overhaul`** — "what lens wasn't run, what identity-level question wasn't asked,
  what finding was asserted but not adversarially verified, what file wasn't read." Its output
  seeds the loop-until-dry and the run's "known blind spots" footer.

The primitive is the same; only the prompt's domain nouns change.
