# The docs affordance rubric

What **excellent docs must afford a reader** — the generic, repo-agnostic standard
`generate-docs` consults every run when judging whether a page communicates well (Core
philosophy #4). This is the skill's own **shipped reference material** (like
`dry-dock-overhaul`'s `lens-examples.md`), versioned and distributed with the plugin — *not* a
per-repo artifact. Per-repo specifics (which topics exist, how the nav is shaped) are still
re-derived from the code each run; this rubric is only the standard those pages are held to.

It is a rubric, not a checklist: a page doesn't need every affordance, and a repo can surface a
need none of these name. Use it to ask "is this the best way to communicate this?" with concrete
answers in hand, rather than defaulting to plain paragraphs.

## Orientation

- **A first-time reader knows within seconds what this is and whether it's for them.** The
  landing page and each page's opening orient before they explain.
- **Every page answers a real question a reader arrives with** — not "here is the surface,"
  but "here is how to do the thing you came to do."
- **The reader can tell where they are and where to go next** — the nav reflects how someone
  actually looks for things, and related pages link to each other instead of restating.

## The right shape for the content

- **Sequences and procedures are steps**, not prose paragraphs the reader has to re-sequence.
- **Comparisons, option matrices, and field references are tables**, not repeated sentence
  templates the reader has to diff by eye.
- **Structure/flow/state is a diagram** where a spatial relationship carries meaning words
  labour at (hand-built, per the repo's diagram convention — never a low-effort default).
- **Non-obvious claims carry a runnable example** — the smallest command/snippet that shows the
  behavior, not just an assertion of it.
- **Callouts (warnings, gotchas, prerequisites) are visually distinct** from the main flow
  (e.g. Material admonitions), so the reader can't skim past a load-bearing caveat.

## Honesty and altitude

- **Pitched at the reader's altitude** — a getting-started page doesn't open with internals; a
  reference page doesn't bury the one field the reader needs under a tutorial.
- **Prose reads as authored explanation, not generated boilerplate** — no filler that restates
  the heading, no "this section describes…" throat-clearing.
- **Code is the source of truth; the page never invents behavior the code doesn't have** — and
  never promises a capability that isn't there.
- **The failure/edge case is documented, not just the happy path** — what breaks, what the
  error means, how to recover.

## Promotion

When a run surfaces a **general** docs-affordance gap — a "docs like this should always afford
X" lesson, not a repo-specific fix — promote it back into *this* file so every repo inherits it
on the next plugin version (see the SKILL's *promotion loop*). Only genuinely generic lessons
belong here; a one-repo specific stays in that repo's pages.
