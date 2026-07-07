# Watching CI and Copilot reviews — the shared mechanics

The one place ship and the `land` loop both describe **how to wait on an async signal** (CI
finishing, a Copilot review landing) and **how to request and read a Copilot review**. Phase 8
of `SKILL.md` and steps 2/4 of `pr-landing-driver.md` both point here so the mechanics can't
drift out of sync between the two call sites.

## Standing watcher-safety rules

These are generic Claude Code harness rules — they hold for *any* `waiting:*` park, not just
ship's.

1. **Silence ≠ success.** A watcher that greps only for the success marker stays silent through
   a crash, a cancellation, or a timeout — and a silent watcher reads as "still running,"
   stranding you forever. The filter must cover **every terminal state**, not just success:
   emit on failure/cancellation/timeout signatures too, so a dead watch wakes you with a verdict
   instead of never waking you at all.
2. **Wake ≠ verdict.** Being re-invoked is not proof the watched condition *succeeded* — the
   harness can resume the session because the watcher exited on *its own* error. On every wake,
   **re-read the live state** (checks on the current head, the reviews list) before acting; never
   treat "I was woken" as "CI went green."
3. **Never park with nothing watching.** A `waiting:*` token backed by no self-resuming watch is
   a bare stop — nothing resumes the loop. Only set `waiting:ci` / `waiting:copilot` once a watch
   that will re-invoke you is actually running.

## Wait-primitive decision table

Pick the primitive by the *shape* of what you're waiting on. The load-bearing finding: a
completing background **process** generates a harness resume event on its own; a timed wakeup
does not — it only advances when the runtime happens to re-invoke the session, so if the user
steps away it strands. (This is what stranded a merge-ready PR for hours — a `ScheduleWakeup`
was "a watch," but the wrong kind.)

| Waiting on | Correct primitive | Why |
|---|---|---|
| A single job reaching a terminal state (CI on a head SHA; a Copilot review landing) | **Backgrounded Bash process** (`run_in_background: true`) that blocks then exits | Its exit *is* a completion event — re-invokes the session across `/compact` and idle gaps, zero agent polling. `gh pr checks --watch` for CI; `scripts/wait-for-copilot-review.sh` for the review. |
| An indefinite/bounded *stream* of occurrences (each new matching log line) | **Monitor** off a bash source | Fires per-occurrence; the filter must still cover every terminal state (rule 1). |
| Wall-clock / recurring / long-horizon low-frequency polling | **cron** (`CronCreate`), self-deleting once it fires | For genuinely periodic checks, not for parking on one job. |

**Ruled out for `waiting:copilot` (and `waiting:ci`): `ScheduleWakeup`, manual re-polling of
`get_reviews`, and a bare stop.** A timed `ScheduleWakeup` is *not* a reliable resume — it does
not generate a completion event. Use the backgrounded process only.

## Watching CI on the head SHA

CI reports through **two** GitHub surfaces, and the merge gate reads the *published status*, not
the CI UI. Pin every read to the PR's current head SHA, and read **both** surfaces before
concluding green:

- **`get_check_runs`** (check-runs API) and **`get_status`** (the commit-status API) — a required
  context can be published on *either*. An **empty check-runs list is not "no CI"**: the required
  status may live on the commit-status surface, or a notification may have dropped. Treating
  empty as "no checks, proceed" is wrong.
- **A green run in the CI UI is not the same as the required status being published on the head
  SHA.** A dropped status notification can leave the required check unpublished even though the
  run itself went green — and the merge gate reads the published status. So a green-looking run
  is not sufficient; confirm the required context is *published green on the head SHA* on one of
  the two surfaces.
- On a **suspected dropped notification** (run went green in the UI but no published status
  appears), re-request / re-watch rather than treating the silence as terminal — and remember
  rule 1: a watch that only matched the success context would stay silent here.

## Requesting and reading a Copilot review — mechanism traps

The Phase 8 state machine ((a)/(b)/(c)) is about *what state the review is in*. These are the
**API-mechanism traps** that make requesting/detecting silently fail regardless of the state:

1. **Request with `request_copilot_review` — never `gh pr edit --add-reviewer copilot`.** The
   `--add-reviewer` GraphQL path **silently drops bot logins**: it returns success and adds
   nothing. Use the dedicated `request_copilot_review` (GitHub MCP or the REST request path).
2. **Author-login asymmetry.** Copilot appears in **`requested_reviewers`** under one login, but
   the posted **review** is authored by **`copilot-pull-request-reviewer[bot]`**. Code that
   matches "the same login" across the request surface and the review surface silently finds
   nothing. Match `requested_reviewers` to detect the *request*, and
   `copilot-pull-request-reviewer[bot]` to detect the *review* (this is exactly what
   `scripts/wait-for-copilot-review.sh` pins on).
3. **`reviewRequests` (GraphQL) omits the bot.** A naive "is Copilot a requested reviewer?" check
   via the GraphQL `reviewRequests` field misses it. Read `requested_reviewers` via REST instead.
4. **A review has two parts.** The **summary body** and the **inline comments** are separate —
   parse *both*, or you miss findings that live only in the inline thread.

## The Copilot-review watch

`scripts/wait-for-copilot-review.sh <owner/repo> <pr-number> [timeout-seconds]` is THE mechanism
for state (b) — the review-side parallel to `gh pr checks --watch` for CI. Run it with
`run_in_background: true`; it blocks until `copilot-pull-request-reviewer[bot]` has a review on
the **current head SHA**, then exits `READY`, or exits `TIMEOUT` when the bounded window elapses
(both terminal, both `exit(0)`, so it can never hang). Its completion re-invokes the session. On
re-invoke, re-read live state (rule 2): `READY` → parse and triage; `TIMEOUT` → treat Copilot as
unavailable and proceed (it's advisory; the bounded-window rule already permits landing).
