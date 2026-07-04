#!/usr/bin/env bats
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT


# Tests for plugins/dev-kit/skills/open-work/scripts/rank_issues.py's rank() logic — the
# deterministic partition/sort half of /dev-kit:open-work. Each test feeds a fixture JSON
# array (the gather() output shape) via --input, so no live gh/GitHub calls happen.
# Run:  bats tests/open_work_rank.bats

setup() {
  SANDBOX="$(mktemp -d)"
  SCRIPT="$BATS_TEST_DIRNAME/../plugins/dev-kit/skills/open-work/scripts/rank_issues.py"
  FIXTURE="$SANDBOX/issues.json"
  RECENT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  STALE="2020-01-01T00:00:00Z"
}

teardown() {
  rm -rf "$SANDBOX"
}

issue() {
  # issue <number> <status> <priority-or-null> <assignee-or-null> <updated_at> [blocked_label] [blocked_by_json] [linked_pr_json]
  local number=$1 status=$2 priority=$3 assignee=$4 updated_at=$5
  local blocked_label=${6:-false} blocked_by=${7:-[]} linked_pr=${8:-null}
  jq -n \
    --argjson number "$number" \
    --arg status "$status" \
    --arg priority "$priority" \
    --arg assignee "$assignee" \
    --arg updated_at "$updated_at" \
    --argjson blocked_label "$blocked_label" \
    --argjson blocked_by "$blocked_by" \
    --argjson linked_pr "$linked_pr" \
    'def nullify(x): if x == "null" then null else x end;
     {
      number: $number, title: ("issue " + ($number | tostring)),
      url: ("https://github.com/o/r/issues/" + ($number | tostring)),
      updated_at: $updated_at,
      assignee: nullify($assignee),
      status: $status,
      blocked_label: $blocked_label,
      priority: nullify($priority),
      blocked_by: $blocked_by,
      linked_pr: $linked_pr
    }'
}

run_rank() {
  local viewer=$1
  run uv run "$SCRIPT" --input "$FIXTURE" --viewer "$viewer"
}

@test "partitions ready/triage/in-progress/in-review into the right buckets" {
  jq -n \
    --argjson a "$(issue 1 ready medium null "$RECENT")" \
    --argjson b "$(issue 2 triage null null "$RECENT")" \
    --argjson c "$(issue 3 in-progress null null "$RECENT")" \
    --argjson d "$(issue 4 in-review null null "$RECENT")" \
    '[$a, $b, $c, $d]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.tally == {open: 4, ready: 1, in_progress: 2, untriaged: 1}'
  echo "$output" | jq -e '.start_next | length == 1 and .[0].number == 1'
  echo "$output" | jq -e '.needs_attention.untriaged_count == 1'
  echo "$output" | jq -e '(.resume.yours + .resume.others) | map(.number) | sort == [3, 4]'
}

@test "status:blocked label excludes an issue from start-next and lists it as blocked" {
  jq -n --argjson a "$(issue 1 ready medium null "$RECENT" true)" '[$a]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.start_next == []'
  echo "$output" | jq -e '.needs_attention.blocked | length == 1 and .[0].number == 1'
}

@test "a ready issue with an open Blocked-by reference is treated as blocked" {
  jq -n --argjson a "$(issue 1 ready medium null "$RECENT" false '[{"number": 9, "open": true}]')" \
    '[$a]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.start_next == []'
  echo "$output" | jq -e '.needs_attention.blocked | length == 1'
}

@test "a ready issue whose Blocked-by reference is already closed is startable" {
  jq -n --argjson a "$(issue 1 ready medium null "$RECENT" false '[{"number": 9, "open": false}]')" \
    '[$a]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.start_next | length == 1'
  echo "$output" | jq -e '.needs_attention.blocked == []'
}

@test "an in-progress issue with a merged linked PR is done-but-open, not resumable" {
  local pr='{"number": 50, "state": "MERGED", "merged_at": "2026-01-01T00:00:00Z", "url": "https://x/50"}'
  jq -n --argjson a "$(issue 1 in-progress null null "$RECENT" false '[]' "$pr")" '[$a]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.resume.yours == [] and .resume.others == []'
  echo "$output" | jq -e '.needs_attention.done_but_open | length == 1 and .[0].number == 1'
  echo "$output" | jq -e '.tally.in_progress == 0'
}

@test "an in-progress issue with an open (unmerged) linked PR stays in resume" {
  local pr='{"number": 50, "state": "OPEN", "merged_at": null, "url": "https://x/50"}'
  jq -n --argjson a "$(issue 1 in-progress null null "$RECENT" false '[]' "$pr")" '[$a]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.needs_attention.done_but_open == []'
  echo "$output" | jq -e '(.resume.yours + .resume.others) | length == 1'
}

@test "start-next sorts by priority first, staleness second" {
  jq -n \
    --argjson a "$(issue 1 ready low null "$RECENT")" \
    --argjson b "$(issue 2 ready high null "$STALE")" \
    --argjson c "$(issue 3 ready high null "$RECENT")" \
    '[$a, $b, $c]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.start_next | map(.number) == [2, 3, 1]'
}

@test "start-next is capped at 5 but reports the true total" {
  local rows=()
  for n in $(seq 1 7); do
    rows+=("$(issue "$n" ready medium null "$RECENT")")
  done
  printf '%s\n' "${rows[@]}" | jq -s '.' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.start_next | length == 5'
  echo "$output" | jq -e '.start_next_total == 7'
  echo "$output" | jq -e '.tally.ready == 7'
}

@test "a ready issue assigned to someone else is excluded from start-next but still counted ready" {
  jq -n --argjson a "$(issue 1 ready medium other-person "$RECENT")" '[$a]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.start_next == []'
  echo "$output" | jq -e '.tally.ready == 1'
}

@test "resume splits yours (self-assigned or unassigned) from others" {
  jq -n \
    --argjson a "$(issue 1 in-progress null someone "$RECENT")" \
    --argjson b "$(issue 2 in-progress null null "$RECENT")" \
    --argjson c "$(issue 3 in-progress null other-person "$RECENT")" \
    '[$a, $b, $c]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.resume.yours | map(.number) | sort == [1, 2]'
  echo "$output" | jq -e '.resume.others | map(.number) == [3]'
}

@test "a resume row past the staleness threshold is flagged stale" {
  jq -n \
    --argjson a "$(issue 1 in-progress null null "$RECENT")" \
    --argjson b "$(issue 2 in-progress null null "$STALE")" \
    '[$a, $b]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '(.resume.yours[] | select(.number == 1) | .stale) == false'
  echo "$output" | jq -e '(.resume.yours[] | select(.number == 2) | .stale) == true'
}

@test "a fully unlabeled ledger is flagged degraded" {
  jq -n --argjson a "$(issue 1 unlabeled null null "$RECENT")" '[$a]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.degraded == true'
}

@test "a ledger with at least one status label is not degraded" {
  jq -n \
    --argjson a "$(issue 1 ready medium null "$RECENT")" \
    --argjson b "$(issue 2 unlabeled null null "$RECENT")" \
    '[$a, $b]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.degraded == false'
  echo "$output" | jq -e '.needs_attention.untriaged_count == 1'
}

@test "usage error when --input is given without --viewer" {
  jq -n '[]' >"$FIXTURE"
  run uv run "$SCRIPT" --input "$FIXTURE"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--viewer is required"* ]]
}

@test "empty ledger produces an all-zero tally" {
  jq -n '[]' >"$FIXTURE"
  run_rank someone
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.tally == {open: 0, ready: 0, in_progress: 0, untriaged: 0}'
  echo "$output" | jq -e '.start_next == [] and .needs_attention.blocked == [] and .needs_attention.done_but_open == []'
}
