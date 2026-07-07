#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# wait-for-copilot-review.sh <owner/repo> <pr-number> [timeout-seconds]
#
# Blocks until copilot-pull-request-reviewer[bot] has a review on the head SHA captured when
# this script STARTED (not re-read as the PR advances — see the pin note below),
# then exits READY — or exits TIMEOUT if the bounded window elapses first. TWO terminal states,
# both exit(0), so it can never hang. Run it via Bash with run_in_background: true so the
# harness re-invokes the session on exit — a completing background *process* generates a resume
# event; a timed ScheduleWakeup does not (that mechanism stranded a merge-ready PR — see the
# skill's watch-and-review reference). This is THE mechanism for the Copilot-review watch, the
# review-side parallel to `gh pr checks --watch` for CI.
#
# Pins to the head SHA captured at start — the state you're converging: a stale review on an
# EARLIER push doesn't count, and if a NEW commit lands mid-watch, this run keeps waiting on the
# SHA it started on (re-run it against the new head after you push). On re-invoke: clean
# review -> merge; real findings -> address and re-request;
# TIMEOUT -> Copilot is advisory, treat as unavailable and land anyway.

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: wait-for-copilot-review.sh <owner/repo> <pr-number> [timeout-seconds]" >&2
  exit 2
fi

repo="$1"
pr="$2"
timeout="${3:-900}"

# Pin to the head SHA now; a review on a later push is checked against this exact commit.
head_sha="$(gh pr view "$pr" --repo "$repo" --json headRefOid --jq '.headRefOid')"
deadline=$((SECONDS + timeout))

# The reviewer's login on the posted *review* is copilot-pull-request-reviewer[bot] — NOT the
# login Copilot appears under in requested_reviewers. Match the review author, and pin commit_id.
until gh api "repos/$repo/pulls/$pr/reviews" \
  --jq "any(.[]; .user.login==\"copilot-pull-request-reviewer[bot]\" and .commit_id==\"$head_sha\")" |
  grep -q true; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "TIMEOUT: no Copilot review on $head_sha after ${timeout}s (treat as unavailable, land anyway)"
    exit 0
  fi
  sleep 20
done

echo "READY: Copilot review present on $head_sha"
