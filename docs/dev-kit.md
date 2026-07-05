# dev-kit

<span data-version="dev-kit"></span> · workflow · pull-request · code-review · security-review ·
issues · worktrees ·
[source ↗](https://github.com/nivintw/nivintw-claude-skills/tree/main/plugins/dev-kit)

A human + AI development workflow. Take a change from idea to a reviewed pull request —
planned, isolated, implemented with tiered subagent delegation, simplified, documented, and
reviewed. The human stays in control at the ends; the rigorous work happens in the middle.
It never auto-merges — unless you explicitly tell it to `land` the PR.

## The loop

`/dev-kit:ship` is the orchestrator and calls the others directly; each also stands alone.
`/dev-kit:land` is a discoverable entry point to ship's own merge verb, not a separate loop
step. Three more sit deliberately outside this loop — `/dev-kit:dry-dock-overhaul`,
`/dev-kit:pre-public-hardening`, and `/dev-kit:template-reconcile` — occasional checks you
reach for on your own schedule, never called automatically.

Track work as issues with `/dev-kit:handle-task-tracking`, pick what's next with
`/dev-kit:open-work`, then `/dev-kit:ship` it — which reviews with `/dev-kit:review-pr`,
refreshes docs with `/dev-kit:generate-docs`, and tidies up with `/dev-kit:cleanup-locally`.

!!! note "A Stop hook backstops this"
    dev-kit also ships a `Stop` hook (`ship-continue.sh`) that blocks a premature stop only
    while a ship run's `state` names an active phase — e.g. right after a delegated
    sub-skill like `/security-review` hands back mid-run — and default-allows everywhere
    else (human gates, async waits, or no ship run at all), so it can never trap a session
    or nag during a legitimate wait.

## Commands

| Command | One-liner |
|---------|-----------|
| [`ship`](#ship) | Idea → review-ready PR: plan, worktree, implement, simplify, docs, review, hand off (or `land`). |
| [`land`](#land) | Discoverable entry point to `ship`'s merge verb — drives an open PR to merged. |
| [`review-pr`](#review-pr) | The single review entry point — full battery + adversarial pass, one prioritized report. |
| [`generate-docs`](#generate-docs) | Reconciles the whole docs set against the whole codebase; authors this site. |
| [`handle-task-tracking`](#handle-task-tracking) | GitHub issues as the durable task ledger — capture, triage, decompose, close. |
| [`open-work`](#open-work) | Ranked "pick up next" shortlist from the open issues, leading with in-flight work. |
| [`cleanup-locally`](#cleanup-locally) | Reconciles your local clone with the remote after PRs land. |
| [`doctor`](#doctor) | Health check for installed plugins — version drift + a skill inventory. |
| [`pre-public-hardening`](#pre-public-hardening) | Full-history secrets/licensing readiness review before a repo goes public. |
| [`dry-dock-overhaul`](#dry-dock-overhaul) | The most expensive skill by design — an exhaustive, human-triggered whole-repo audit. |
| [`template-reconcile`](#template-reconcile) | For Copier-managed repos — verifies template infra survived an adopt/update. |

### ship

`/dev-kit:ship` — the orchestrator. Drives a change from idea to a review-ready PR: plan and
get sign-off, work in a dedicated worktree, implement with work routed to the cheapest
fitting model tier, then simplify, refresh docs, run the full review battery, open the PR,
and converge an automated review. Hands off by default — or, on request, **lands** the PR:
drives CI to green, converges the review, then rebase-merges and cleans up. The one path
where ship merges.

Ask for `land` up front and that single grant covers the plan sign-off too — no separate
"plan and get sign-off" pause — plus every design/approach choice for the rest of the run,
logged to the PR (a required "Decisions made without asking" section) and mirrored as
`Decision:`-prefixed issue comments instead of re-confirmed. Naming several discrete items
alongside a `land` grant ("ship and land these three fixes as one batch") auto-detects as a
single minimal PR — that batching behavior doesn't apply without `land`; a bare `ship` batch
still ships each item as its own PR.

Try: *"ship this fix"* · *"take this from idea to a PR"* · *"land the PR"* · *"ship and land
it"*.

### land

`/dev-kit:land` — a discoverable, tab-completable entry point to `ship`'s `land` verb —
drives an already-open PR to merged: CI to green, the automated review converged, a
rebase-merge, then cleanup. With no PR number, attaches to the current branch's open PR;
`/dev-kit:land <N>` drives PR #N cold. (Batching several items into one PR is a `ship`-time
decision, made before the PR exists — ask `ship` to land a batch up front, not this command
after the fact.)

Try: *"land it"* · *"land PR #42"*.

### review-pr

`/dev-kit:review-pr` — the single review entry point. Runs and synthesizes the whole battery
— code review, security review, and the pr-review-toolkit — plus a context-chosen
adversarial pass that actively tries to break the change, then merges everything into one
prioritized report. Works on your own diff or a teammate's PR.

Try: *"review this PR"* · *"review my changes before I open a PR"* · *"review PR #42"*.

### generate-docs

`/dev-kit:generate-docs` — reconcile the whole documentation set against the whole codebase
every run — catching both drift (docs that no longer match the code) and omission (code
with no docs) — and author a bespoke MkDocs Material site (Markdown + a `mkdocs.yml` nav
tree) shaped to the repo, whatever kind it is. Humans first. (This page was authored by it.)

Try: *"generate the docs"* · *"refresh the docs"* · *"reconcile the docs"*.

### handle-task-tracking

`/dev-kit:handle-task-tracking` — a repeatable workflow for using GitHub issues as the
durable task ledger: capture work as well-formed issues, triage with a small status-label
set, decompose into native sub-issues, link branches and PRs with `Closes #N`, and close out
deliberately. The ledger that `/dev-kit:ship` delegates to across the lifecycle.

Try: *"open an issue for this"* · *"triage the issues"* · *"break this into sub-issues"*.

### open-work

`/dev-kit:open-work` — reads the repo's open issues and, when you have work in flight,
*leads* by calling out your in-progress work to resume — usually finish what you started
first — then returns the **full** ranked "pick up next" list of ready work, never truncated,
with a one-line rationale for the standout picks, instead of you eyeballing the whole list.
Ranks ready work by priority, staleness, and dependencies, surfaces blocked items, and flags
the untriaged pile. The select step between tracking and shipping.

Try: *"what should I work on next"* · *"what's in progress"* · *"shortlist my ready work"*.

### cleanup-locally

`/dev-kit:cleanup-locally` — reconcile your local clone with the remote after PRs land:
bring the default branch up to date, prune merged worktrees, and delete local branches
whose commits already merged — squash merges included. Deliberately conservative: anything
unmerged, dirty, or checked out is kept and reported, never clobbered.

Try: *"clean up local branches"* · *"prune merged worktrees"* · *"update main"*.

### doctor

`/dev-kit:doctor` — a health check for your installed plugins. Compares the version
actually loaded this session, the newest cached on disk, and the latest released — and
flags when a stale cache means an old skill is running despite a newer release, even with
autoupdate on. Also inventories the marketplace's plugins and their skills, so you can see
what's installed and what each is for.

Try: *"am I on the latest version"* · *"check my plugin versions"* · *"list my skills"*.

### pre-public-hardening

`/dev-kit:pre-public-hardening` — a whole-repo, full-history readiness review before a
private repo goes public: scans every commit for secrets (not just the working tree), audits
`.gitignore` for leak gaps, flushes private-context artifacts, and verifies license
completeness — producing a go/no-go checklist. Detects and prescribes; it never flips
visibility or rewrites history itself.

Try: *"make this repo public"* · *"is this repo safe to open-source?"* · *"scan the git
history for secrets"*.

### dry-dock-overhaul

`/dev-kit:dry-dock-overhaul` — deliberately outside the loop above. An exhaustive,
always-human-triggered audit of the whole repo, not a diff: every tracked file is genuinely
read and judged, plus a "10,000-foot" pass discovered fresh for this repo's own shape
(docs-site UX, test-suite architecture, naming consistency, or whatever else it calls for).
Orchestrates `/dev-kit:review-pr` (whole-repo mode), `/dev-kit:generate-docs`, and
`/dev-kit:pre-public-hardening` alongside that net-new coverage into one severity-ranked,
ephemeral report. This is the most expensive skill in the marketplace by design — reach for
it rarely, and on purpose.

Try: *"dry dock overhaul this repo"* · *"audit the whole repo"* · *"review every line"*.

### template-reconcile

`/dev-kit:template-reconcile` — for repos managed by a Copier template: reconciles against
the upstream template after an adopt or update, verifying no template infra was silently
dropped. Scaffolds a divergence registry and a synced-files test into the repo, and prompts
to file upstream (via `/dev-kit:handle-task-tracking`'s cross-repo filing) when a change
touches a template-owned file. A companion to `copier update`, not a replacement for it.

Try: *"adopt the copier template"* · *"reconcile against the template"* · *"did the template
infra come over?"*.

## Install

```text
/plugin marketplace add nivintw/nivintw-claude-skills
/plugin install dev-kit@nivintw-claude-skills
```
