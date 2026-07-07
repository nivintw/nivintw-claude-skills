# Synced-files test + divergence registry — copy-paste skeletons

Concrete starting points for the two artifacts `template-reconcile` scaffolds into a
copier-managed repo: a **divergence registry** that documents every intentional deviation
from the template, and a **synced-files test** that fails when a template-owned file drifts
without a registered reason. Adapt paths and the template-materialization step to the repo;
the shapes below are the reusable part.

## Divergence registry

A tracked plain-text file — `tests/template-divergences.txt` is a reasonable home. One entry
per intentionally-divergent template-owned file: the repo-relative path, then a one-line
reason. The invariant the test enforces: **a template-owned file not listed here is expected
to be byte-identical to the template.**

```text
# <repo-relative path>    # why it intentionally differs from the template
README.md                 # project-specific intro; template ships only a stub
.config/licenserc.toml    # extra SPDX header rule for our skill markdown (filed upstream: nivintw/copier-everything#NN)
```

Keep the "filed upstream: <owner/repo#N>" note on any divergence you've already ported back —
it turns the registry into the audit trail for the upstream-port workflow.

## Synced-files test (bats skeleton)

A **real-tree assertion** that diffs the actual repo against **what the template renders**, not
against the raw template tree. Render with copier itself so `.jinja` suffixes, Jinja-conditional
names, `_exclude`, and `_subdirectory` are all handled — a raw `template/<path>` byte-diff can't
do any of that and silently mismatches or skips. The test must **fail loudly, never vacuously
green**: an empty candidate set, a failed render, or an all-skipped run is a failure, not a pass.

```bash
#!/usr/bin/env bats
# Asserts template-owned files match what the template RENDERS at the pinned _commit, except
# those documented in tests/template-divergences.txt. Uses copier to render (not a raw
# template-tree byte-diff), so .jinja / conditional names / _exclude / _subdirectory are handled.

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  REGISTRY="$REPO_ROOT/tests/template-divergences.txt"
  COMMIT=$(sed -n 's/^_commit: *//p' "$REPO_ROOT/.copier-answers.yml")  # e.g. v1.4.0

  # Render what the template GENERATES for this repo's recorded answers. `copier recopy` reads
  # _src_path + the answers from .copier-answers.yml and regenerates the template files; run it
  # on a throwaway clone (real tree untouched), pinned to _commit. If the clone or render fails,
  # these commands return non-zero and bats fails the test in setup — never a silent empty dir
  # that would make every comparison "match".
  RENDER_ROOT="$(mktemp -d)"
  RENDERED="$RENDER_ROOT/repo"
  git clone --quiet "$REPO_ROOT" "$RENDERED"
  uvx copier recopy --defaults --overwrite --vcs-ref "$COMMIT" "$RENDERED"
}

teardown() { rm -rf "$RENDER_ROOT"; }

# True if $1 (repo-relative path) is listed in the divergence registry. Matches the path
# literally against each line's first field — never as a regex (paths contain `.` etc.).
is_registered_divergence() {
  awk -v want="$1" '!/^[[:space:]]*#/ && NF && $1 == want { hit = 1 } END { exit hit ? 0 : 1 }' \
    "$REGISTRY" 2>/dev/null
}

@test "template-owned files match the copier render unless a divergence is registered" {
  # CANDIDATES: the files this repo declares should track the template. Derive these from the
  # adoption walk (Adoption & update — no silent drops), e.g. the template's config/CI/gate
  # files this repo adopted verbatim. NOT guessed.
  CANDIDATES=(
    # .config/licenserc.toml
    # .github/workflows/pr.yml
  )

  # Guard against a vacuous pass: an empty candidate set, or a render that produced nothing,
  # must FAIL — not silently compare zero files and report green.
  [ "${#CANDIDATES[@]}" -gt 0 ] || { echo "no CANDIDATES declared — the test would check nothing"; false; }
  # Positive control: the render must have produced its answers file, proving copier actually
  # ran. Without this, a no-op render makes every candidate look "not rendered" and skip silently.
  [ -f "$RENDERED/.copier-answers.yml" ] || { echo "copier render produced no output"; false; }

  drift=()
  compared=0
  for rel in "${CANDIDATES[@]}"; do
    is_registered_divergence "$rel" && continue
    [ -f "$RENDERED/$rel" ] || continue   # template no longer renders it; not a sync target
    compared=$((compared + 1))
    diff -q "$RENDERED/$rel" "$REPO_ROOT/$rel" >/dev/null 2>&1 || drift+=("$rel")
  done

  # If every candidate was registered or unrendered, nothing was actually compared — that is a
  # vacuous run, not a pass.
  [ "$compared" -gt 0 ] || { echo "no candidate was compared (all skipped) — the test is vacuous"; false; }
  [ "${#drift[@]}" -eq 0 ] || {
    printf 'drifted from the template render (register the divergence or re-sync): %s\n' "${drift[@]}"
    false
  }
}
```

Notes:

- **`CANDIDATES`** is the list of files meant to stay in sync — populate it from the adoption
  walk, not by guessing. A file the template no longer renders is skipped (not a drift), but an
  *empty or all-skipped* candidate set fails the test (the vacuous-green guards above).
- **copier does the rendering.** Don't reimplement `.jinja`-stripping / `_subdirectory` /
  conditional-name resolution by hand — that hand-rolled mapping is exactly what breaks on a
  non-trivial template. `copier recopy --pretend` (dry-run) is the way to *inspect* drift without
  writing; the skeleton above renders into a throwaway clone so it can byte-diff.
- This is a **skeleton to adapt**, not a drop-in: the candidate set, registry path, and the
  copier invocation (how copier is available — `uvx`, a venv, …) are per-repo. Verify it passes
  against the current tree before committing it — and confirm it *fails* when you deliberately
  drift a candidate, so you know it isn't vacuously green.
