# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# /// script
# requires-python = ">=3.11"
# ///
"""Gather and rank a repo's open GitHub issues for /dev-kit:open-work.

Split into an impure `gather()` (shells out to `gh`) and a pure `rank()` (partitioning,
sorting, degraded-mode detection) so the deterministic half is unit-testable without live
GitHub calls — see `--input` below.

Usage:
  rank_issues.py [--owner OWNER --repo REPO] [--viewer LOGIN] [--limit N]
  rank_issues.py --input fixture.json --viewer LOGIN

Without --input, gathers live via `gh` (owner/repo/viewer resolved automatically if omitted).
With --input, reads a JSON array of already-gathered issue dicts (see `gather()`'s output
shape) and skips all `gh` calls — the fixture format bats tests use.

Prints the ranked result as JSON to stdout. Exit 0 on success, 1 on a `gh`/IO failure, 2 on
a usage error.
"""

import argparse
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

STATUS_LABELS = ("status:triage", "status:ready", "status:in-progress", "status:in-review")
PRIORITY_LABELS = ("high", "medium", "low")
PRIORITY_RANK = {p: i for i, p in enumerate(PRIORITY_LABELS)}
STALE_DAYS = 14
BLOCKED_BY_RE = re.compile(r"blocked\s+by\s*:?\s*((?:#\d+[\s,]*)+)", re.IGNORECASE)
ISSUE_NUM_RE = re.compile(r"#(\d+)")

CLOSED_BY_PR_QUERY = """
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    issue(number: $number) {
      closedByPullRequestsReferences(first: 5, includeClosedPrs: true) {
        nodes { number state mergedAt url }
      }
    }
  }
}
"""


def run_gh(args: list[str]) -> str:
    return subprocess.run(
        ["gh", *args], capture_output=True, text=True, check=True
    ).stdout


def resolve_repo() -> tuple[str, str]:
    data = json.loads(run_gh(["repo", "view", "--json", "owner,name"]))
    return data["owner"]["login"], data["name"]


def resolve_viewer() -> str:
    return run_gh(["api", "user", "--jq", ".login"]).strip()


def is_degraded(issues: list[dict]) -> bool:
    return not any(issue["status"] != "unlabeled" for issue in issues)


def get_primary_status(labels: list[str]) -> str:
    for status_label in STATUS_LABELS:
        if status_label in labels:
            return status_label.split(":", 1)[1]
    return "unlabeled"


def get_priority(labels: list[str]) -> str | None:
    for priority in PRIORITY_LABELS:
        if f"priority:{priority}" in labels:
            return priority
    return None


def extract_blocked_by(body: str) -> list[int]:
    numbers: list[int] = []
    for match in BLOCKED_BY_RE.finditer(body):
        numbers.extend(int(n) for n in ISSUE_NUM_RE.findall(match.group(1)))
    return numbers


def resolve_linked_pr(owner: str, repo: str, number: int) -> dict | None:
    out = run_gh(
        [
            "api", "graphql",
            "-f", f"query={CLOSED_BY_PR_QUERY}",
            "-F", f"owner={owner}",
            "-F", f"repo={repo}",
            "-F", f"number={number}",
        ]
    )
    issue = json.loads(out).get("data", {}).get("repository", {}).get("issue") or {}
    nodes = (issue.get("closedByPullRequestsReferences") or {}).get("nodes") or []
    if not nodes:
        return None
    node = next((n for n in nodes if n.get("mergedAt")), nodes[0])
    return {
        "number": node["number"],
        "state": node["state"],
        "merged_at": node.get("mergedAt"),
        "url": node["url"],
    }


def fetch_body(owner: str, repo: str, number: int) -> str:
    data = json.loads(run_gh(["issue", "view", str(number), "--repo", f"{owner}/{repo}", "--json", "body"]))
    return data.get("body") or ""


def gather(owner: str, repo: str, limit: int = 500) -> list[dict]:
    raw = json.loads(
        run_gh(
            [
                "issue", "list", "--repo", f"{owner}/{repo}", "--state", "open",
                "--limit", str(limit),
                "--json", "number,title,labels,updatedAt,assignees,url",
            ]
        )
    )
    open_numbers = {item["number"] for item in raw}

    issues = []
    for item in raw:
        labels = [label["name"] for label in item["labels"]]
        issues.append(
            {
                "number": item["number"],
                "title": item["title"],
                "url": item["url"],
                "updated_at": item["updatedAt"],
                "assignee": item["assignees"][0]["login"] if item["assignees"] else None,
                "status": get_primary_status(labels),
                "blocked_label": "status:blocked" in labels,
                "priority": get_priority(labels),
                "blocked_by": [],
                "linked_pr": None,
            }
        )

    degraded = is_degraded(issues)

    def enrich(issue: dict) -> None:
        wants_pr_check = (issue["status"] in ("in-progress", "in-review")) or (degraded and issue["assignee"])
        if wants_pr_check:
            issue["linked_pr"] = resolve_linked_pr(owner, repo, issue["number"])
        if not degraded and issue["status"] == "ready":
            body = fetch_body(owner, repo, issue["number"])
            issue["blocked_by"] = [
                {"number": n, "open": n in open_numbers} for n in extract_blocked_by(body)
            ]

    # Each issue's extra gh calls (linked-PR lookup, body fetch) are independent network
    # round trips — run them concurrently rather than one at a time.
    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(enrich, issues))

    return issues


def _is_stale(updated_at: str, now: datetime) -> bool:
    try:
        dt = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return False
    return (now - dt).days >= STALE_DAYS


def rank(issues: list[dict], viewer: str | None, now: datetime) -> dict:
    degraded = is_degraded(issues)

    def has_merged_linked_pr(issue: dict) -> bool:
        pr = issue.get("linked_pr")
        return bool(pr and pr.get("state") == "MERGED")

    done_but_open = [
        i for i in issues if i["status"] in ("in-progress", "in-review") and has_merged_linked_pr(i)
    ]
    done_numbers = {i["number"] for i in done_but_open}

    def effectively_blocked(issue: dict) -> bool:
        if issue.get("blocked_label"):
            return True
        return issue["status"] == "ready" and any(b["open"] for b in issue.get("blocked_by", []))

    blocked = [i for i in issues if i["number"] not in done_numbers and effectively_blocked(i)]
    blocked_numbers = {i["number"] for i in blocked}
    excluded = done_numbers | blocked_numbers

    untriaged = [i for i in issues if i["number"] not in excluded and i["status"] in ("triage", "unlabeled")]

    in_flight = [i for i in issues if i["number"] not in excluded and i["status"] in ("in-progress", "in-review")]
    yours = sorted(
        (i for i in in_flight if i["assignee"] in (None, viewer)), key=lambda i: i["updated_at"]
    )
    others = sorted(
        (i for i in in_flight if i["assignee"] not in (None, viewer)), key=lambda i: i["updated_at"]
    )

    ready = [i for i in issues if i["number"] not in excluded and i["status"] == "ready"]
    startable = [i for i in ready if i["assignee"] in (None, viewer)]
    unranked_priority = len(PRIORITY_LABELS)
    startable_sorted = sorted(
        startable,
        key=lambda i: (PRIORITY_RANK.get(i["priority"], unranked_priority), i["updated_at"]),
    )

    def annotate_stale(rows: list[dict]) -> list[dict]:
        return [{**i, "stale": _is_stale(i["updated_at"], now)} for i in rows]

    return {
        "tally": {
            "open": len(issues),
            "ready": len(ready),
            "in_progress": len(in_flight),
            "untriaged": len(untriaged),
        },
        "degraded": degraded,
        "resume": {
            "yours": annotate_stale(yours),
            "others": annotate_stale(others),
        },
        "start_next": startable_sorted[:5],
        "start_next_total": len(startable_sorted),
        "needs_attention": {
            "untriaged_count": len(untriaged),
            "blocked": blocked,
            "done_but_open": done_but_open,
        },
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--owner")
    parser.add_argument("--repo")
    parser.add_argument("--viewer", help="GitHub login treated as 'yours' for resume/ownership splits")
    parser.add_argument("--limit", type=int, default=500)
    parser.add_argument("--input", help="Path to a JSON array of pre-gathered issues; skips live gh calls")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])

    if args.input and not args.viewer:
        print("usage: --viewer is required when using --input", file=sys.stderr)
        return 2

    try:
        if args.input:
            with open(args.input, encoding="utf-8") as f:
                issues = json.load(f)
            viewer = args.viewer
        else:
            owner = args.owner
            repo = args.repo
            if not owner or not repo:
                owner, repo = resolve_repo()
            viewer = args.viewer or resolve_viewer()
            issues = gather(owner, repo, args.limit)
    except subprocess.CalledProcessError as e:
        print(f"gh command failed: {e.stderr.strip() if e.stderr else e}", file=sys.stderr)
        return 1
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    print(json.dumps(rank(issues, viewer, datetime.now(timezone.utc)), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
