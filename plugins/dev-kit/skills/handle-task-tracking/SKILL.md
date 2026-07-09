---
name: handle-task-tracking
description: >-
  Use when the user asks to "track this with an issue", "open an issue", "file a bug", "triage
  the issues", "break this into sub-issues", "groom the backlog", or "close out this issue".
  Defines a repeatable workflow for using GitHub issues as the durable task ledger: capturing
  well-formed issues, triaging with a small status-label set (Projects optional), decomposing
  via native sub-issues, linking branches/PRs with "Closes #N", and closing them deliberately.
  Prefers the GitHub MCP tools, falling back to the gh CLI. Reach for it whenever tracking or
  grooming development tasks as GitHub issues — but not for implementing a change (that
  belongs to /dev-kit:ship, which delegates tracking here).
---

# handle-task-tracking

GitHub issues are the **durable task ledger** — the single source of truth for trackable
work that outlives any one session, branch, or person. A *healthy* tracker keeps one issue
per outcome, each well-formed and current. A *robust* one keeps the state in GitHub rather
than in a head or a chat scrollback, so the work survives context loss and hand-offs. This
is the same principle `/dev-kit:ship` applies with its progress file under the git dir —
externalize the plan so it can't evaporate — applied to the whole stream of work instead of
one change.

Apply the loop below: **capture → decompose → triage → link → close.** Scale the ceremony
to the team. Solo or a small team is the default here: self-assign, triage lightly, skip
the parts that only earn their keep with more people — but the assignment and hand-off
steps are present so the same workflow grows into a team without rework.

## The model — one issue, one outcome

Open an issue for any unit of work worth remembering after this session: a bug, a feature,
a chore, a decision to revisit. The bar is *"would future-me or a teammate want a record of
this?"* — not every passing thought.

Keep issues **outcome-shaped**, not activity-shaped. The title states the result ("Login
rejects valid 2FA codes after token refresh"), not the act ("Look at auth"). One issue
tracks one shippable outcome; if it needs more than one PR to finish, it probably wants
sub-issues (below).

The issue body is the durable brief. Capture, at minimum: the **problem / goal**, enough
**context** to act without re-discovery, **acceptance criteria** (how "done" is verified),
and what's explicitly **out of scope**. A copy-paste template lives in
[`reference/recipes.md`](reference/recipes.md).

## Capture — make it actionable from cold

Write the issue so someone (including a future Claude with none of this context) can pick it
up cold. Vague issues rot because nobody can tell when they're done. Prefer one or two
concrete acceptance criteria over a wall of prose.

Set the cheap metadata at creation time, because it's what makes the backlog queryable
later: **type/area** and **priority** labels, a **status** label (start at `status:triage`
unless it's obviously ready), an **assignee** if someone owns it now, and a **milestone**
if it belongs to a release. The full label taxonomy is in `reference/recipes.md`.

**File it in the right repo.** Working in one repo routinely surfaces follow-up that belongs
somewhere else — most often the upstream `copier-everything` template. During capture, decide
which repo the outcome lives in: default to the current repo, but when the work is really about
an upstream template or a sibling project, file it THERE — pass an explicit `owner` and `repo`
to the GitHub MCP (or `--repo owner/repo` to `gh`), not the cwd repo. Confirm or infer the
target before filing; don't assume cwd. After filing cross-repo, report back a typed, glossed
cross-repo link (`[owner/repo#N](url)`) as defined in the links section below, so the user can
click through immediately.

## Decompose — sub-issues for anything multi-step

When an outcome needs several independent pieces, split it into **native GitHub sub-issues**
under a parent, rather than a single issue with a checklist of vague bullets. Sub-issues are
real issues — each gets its own status, assignee, and PR — so progress is visible and the
parent shows a real completion count, not a stale checkbox list.

Reach for sub-issues when pieces can land in separate PRs, be worked in parallel, or be
handed to different people. Keep a plain checklist (task-list checkboxes) only for trivial,
same-PR steps not worth their own issue. The parent issue holds the why and the shared
acceptance criteria; each sub-issue holds one concrete deliverable.

## Triage & track — labels first

Drive status with a **small status-label set** so it works in any repo with zero setup:

`status:triage` → `status:ready` → `status:in-progress` → `status:in-review`, plus
`status:blocked` as an orthogonal flag. While open, an issue carries exactly one of those
four *progression* labels — moving work forward means swapping it — with `status:blocked`
layered on top when the work is stuck; **closing clears it** (closed is terminal — see
*Close deliberately*). Keep the set small — more states than the team actually uses become
noise nobody updates.

Triage means turning raw `status:triage` issues into either `status:ready` (clear enough to
start: acceptance criteria, priority, and area all set) or closed (won't-do / duplicate /
already-fixed, with a one-line reason). Don't let issues sit in `triage` indefinitely — an
untriaged pile is the first sign the tracker is going stale.

Selecting *which* `status:ready` task to start — ranking them and explaining the pick — is
`/dev-kit:open-work`'s job; this skill defines the labels that ranking reads. When you start
one, flip it to `status:in-progress` and self-assign. **Keep the issue current as the work
reveals new information** — post a comment when a decision is made, an approach changes, or a
blocker appears. The issue, not the chat, is the durable log.

**Projects (optional upgrade).** When a board view, cross-repo tracking, or custom fields
(sprint, estimate) genuinely help, add a GitHub Projects (v2) board whose columns mirror the
status labels. Treat it as a view over the issues, not a second source of truth — let the
status label stay authoritative so nothing breaks when the board isn't there.

## Link work to issues

Tie the code to the ledger so they never drift:

- **Branch from the issue** so the branch, PR, and issue are obviously one thread
  (`/dev-kit:ship` does this).
- **Flip to `status:in-review`** when the PR opens, so the ledger shows the work is awaiting
  review rather than still in progress.
- **Close from the PR** — `Closes #N` in the PR body closes the issue on merge and stamps it
  with the resolving commit.
- **Cross-link** blockers and related issues so dependencies are visible; promote a blocker
  to its own issue rather than burying it in a comment.

The exact branch-name and `Refs` / `Blocked by` / `Related to` forms live in
[`reference/recipes.md`](reference/recipes.md). `handle-task-tracking` tracks the *what*;
`/dev-kit:ship` delivers the *change* that closes it — the issue is the durable record, ship
is the worktree-isolated, reviewed PR that resolves it.

## Reference issues and PRs as typed, glossed links

Whenever you mention an issue or PR **in your own output** — a capture confirmation, a triage
summary, a "what I closed" report — render it as a **typed, clickable markdown link, glossed
on first mention**, never a bare `#N`. A bare number forces the reader to go look it up; a
linked, titled reference reads at a glance. This is the canonical form of that rule;
`/dev-kit:open-work` applies a presentation-only subset of it — keep the two consistent.

- **Issue:** `[issue #46](https://github.com/<owner>/<repo>/issues/46)` (short title) — e.g.
  `[issue #46](…/issues/46) (add release-please gate)`.
- **PR:** `[PR #46](https://github.com/<owner>/<repo>/pull/46)` (short title), and state its
  state — open / merged / draft — when it bears on the point.
- **Cross-repo:** repo-qualify the visible text so it's unambiguous —
  `[owner/repo#46](https://github.com/owner/repo/issues/46)`. An issue that lives in a
  different repo (an upstream template, a sibling project) is always qualified this way.
- Subsequent mentions in the same message may drop the gloss but keep the typed link.

**The one exception — the machine keyword stays bare.** GitHub's auto-close trailers in a
**commit message or PR body** (`Closes #N`, `Fixes #N`, `Refs #N`) must remain literal
`#N` — GitHub parses them, and a markdown link there breaks the auto-close. The link contract
governs **prose addressed to a human**; the bare keyword governs **machine-parsed trailers**.

This contract is the skill's own rule — apply it even if the surrounding environment's
conventions aren't loaded.

## Close deliberately

Closing is a real step, not an afterthought. Close with a **one- or two-line resolution**:
what changed and the PR/commit that did it — or, for won't-do, *why*. A reader six months
later should learn the outcome from the closed issue without opening anything else. Merging a
PR with `Closes #N` does this when the PR body is good; otherwise add the closing comment by
hand. Never silently close to clear the count — an unexplained closed issue is lost
information.

**Closing is terminal — clear the progression label.** Closed *is* the terminal state, so a
closed issue must not still wear `status:in-progress` or `status:in-review` (nor a leftover
`status:blocked`): that's a label that no longer matches reality. On close, **remove the
`status:in-*` progression label**. And confirm the close actually happened — `Closes #N`
fires only when the merge reaches the default branch with the keyword intact, so a squash
that drops it, a typo'd reference, or an epic with no direct PR can leave the issue **open
and stuck in `status:in-review`**. That stale label is exactly what makes a downstream
reader — or `/dev-kit:open-work` — mistake done work for live work. When it happens, close
the issue by hand (with the resolution) and clear the label.

## Reconcile — re-verify the ledger against reality

Labels are written on the happy path and then trusted forever, so drift accumulates: a
`status:blocked` issue whose blocker closed long ago, a `status:in-*` label outliving its merged
PR. This skill owns the status lifecycle and the "closing is terminal" rule, so it also owns a
**reconcile pass** that not only *detects* that drift but *fixes* it. It's callable standalone
("reconcile the tracker", "groom the backlog") and is what the auto-triggers below invoke.

**Reuse the resolver — don't re-derive.** `open-work`'s
[`../open-work/scripts/rank_issues.py`](../open-work/scripts/rank_issues.py) already resolves
`Blocked by #N` open-state and linked-PR merge-state, and now emits a `reconcile` block:
`unblock` (status:blocked whose every recorded blocker is closed), `close_done` (status:in-*
with a merged linked PR), and `stale_triage` (triage past the staleness threshold). Run it
(`uv run …/rank_issues.py`) and act on that block rather than re-querying GitHub yourself.

**Dry-run first.** Default to a **report** of what would change (the three lists above) before
mutating; only apply on confirmation or when an auto-trigger explicitly runs in apply mode.

Then, in apply mode, over the repo's open issues:

1. **`reconcile.unblock`** — remove `status:blocked`, restore the right progression label
   (`status:ready`, or `status:in-progress`/`in-review` if it has an open linked PR), and
   comment *why* (the blocker(s) that closed). A blocker set that isn't fully closed, or a
   `status:blocked` with no recorded `Blocked by #N` refs, is **left blocked** — never guessed.
2. **`reconcile.close_done`** — a done-but-open issue: clear the stale `status:in-*` label and
   **close with a resolution** (per *Close deliberately*). If `Closes #N` should have fired and
   didn't (a squash that dropped the keyword, a typo), close it by hand with the resolution.
3. **`reconcile.stale_triage`** — **surface only**, don't auto-mutate: triage needs a human
   decision, so list these for grooming rather than relabeling them.

Attribute every mutation with a comment saying the reconcile pass made it and why, so the change
is auditable rather than mysterious.

## Auto-reconcile — keep it correct without being asked

The user shouldn't have to run `open-work`/`doctor` to *discover* stale state — it should just
be kept correct. So the reconcile above runs as a **natural side effect** at the points dev-kit
already touches the ledger, each kept cheap (bounded, skippable on a large ledger, degrading to
report-only where the context is read-only):

- **`open-work`** runs the **blocked-recheck slice** before ranking, so its output is already
  corrected rather than merely *reporting* drift it can't fix — this closes the "open-work keeps
  surfacing stale `status:blocked`" loop. `open-work` stays read-only *for ranking*; the reconcile
  it triggers is a separate, clearly-attributed mutation.
- **`ship`** reconciles the issue(s) in play at Phase 0 (start of run) and in post-merge cleanup.
- **`handle-task-tracking`** runs a lightweight reconcile whenever it's invoked to groom, not
  only when someone asks for a full pass.

## Tooling — MCP first, gh as fallback

Prefer the **GitHub MCP tools** (`mcp__github__*`) for issue operations: they're structured
and typed, and they expose what this workflow leans on — native sub-issues and issue types —
as first-class calls, which plain `gh issue` handles awkwardly (sub-issues and Projects v2
otherwise mean verbose `gh api graphql`). Don't clone a repo just to read it — use the
GitHub MCP to read remote file contents and issues directly. The MCP's `issue_write` takes an
explicit `owner`/`repo`, so filing into a different repo — e.g. the upstream template — is a
first-class call: pass the target owner/repo directly, no directory change or clone needed.

**Keep the reads lean.** Cap page size with `perPage` (5–10) rather than pulling a whole
large backlog into context at once — then advance the right way per tool: `list_issues` is
cursor-paginated (pass `after` from the previous page's cursor; it takes no `page`), while
`issue_read` / `search_issues` use a numeric `page`. On `issue_read`, request only the
sub-resource you need (`get_labels` / `get_comments` / `get_sub_issues`) instead of the full
issue — a broad `list_issues` returns full-fidelity objects, wasted context when you only need
numbers, titles, and labels.

Fall back to the **`gh` CLI** when the MCP server isn't connected — check first, since it can
be absent in headless or cron runs — and whenever a human wants a command to paste into a
terminal. The recipes file gives both forms.

Copy-paste commands, the issue-body template, and the full label taxonomy:
[`reference/recipes.md`](reference/recipes.md).

## Anti-patterns

- **Tracking everything.** An issue per trivial thought buries the real work. Track outcomes
  worth remembering; do the five-minute task instead of filing it.
- **Dead issues.** Stale `in-progress`, an untriaged pile, issues nobody can tell are done.
  These erode trust in the tracker until people stop looking. Triage and close on a rhythm.
- **Status by vibes.** If the labels (or board) don't match reality, the ledger is fiction.
  Update status when the work moves, not at the end.
- **Issue-as-chat.** Decisions buried in PR threads or Slack vanish. Put the durable
  conclusion on the issue.
- **Checklist sprawl.** A 20-item checkbox list inside one issue hides progress and can't be
  parallelized — promote the independent items to sub-issues.
