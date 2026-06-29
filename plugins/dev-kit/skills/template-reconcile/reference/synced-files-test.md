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

Two parts, mirroring `tests/check_plugin_release_wiring.bats`: per-case sandbox assertions
(optional, for the registry parser), and a **real-tree assertion** that diffs the actual repo
against the template. Materialize the template once at the pinned `_commit` and diff each
candidate file; skip anything in the registry.

```bash
#!/usr/bin/env bats
# Asserts template-owned files are byte-identical to the template at the pinned _commit,
# except those documented in tests/template-divergences.txt.

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  REGISTRY="$REPO_ROOT/tests/template-divergences.txt"

  # Read the template source + pinned commit from .copier-answers.yml.
  SRC=$(sed -n 's/^_src_path: *//p' "$REPO_ROOT/.copier-answers.yml")   # e.g. gh:owner/repo
  COMMIT=$(sed -n 's/^_commit: *//p' "$REPO_ROOT/.copier-answers.yml")  # e.g. v1.4.0

  # Resolve the clone source. _src_path may be Copier's `gh:owner/repo` shorthand, a full
  # https/ssh URL, or a local path — handle the shorthand, otherwise clone $SRC as-is.
  case "$SRC" in
  gh:*) CLONE_SRC="https://github.com/${SRC#gh:}.git" ;;
  *) CLONE_SRC="$SRC" ;;
  esac

  # Materialize the template tree at that commit. Clone then check out, so this works whether
  # _commit is a tag, a branch, or a bare commit SHA (Copier allows any of them).
  TEMPLATE_DIR="$(mktemp -d)"
  git clone --quiet "$CLONE_SRC" "$TEMPLATE_DIR"
  git -C "$TEMPLATE_DIR" checkout --quiet "$COMMIT"
}

teardown() { rm -rf "$TEMPLATE_DIR"; }

# True if $1 (repo-relative path) is listed in the divergence registry. Matches the path
# literally against each line's first field — never as a regex (paths contain `.` etc.).
is_registered_divergence() {
  awk -v want="$1" '!/^[[:space:]]*#/ && NF && $1 == want { hit = 1 } END { exit hit ? 0 : 1 }' \
    "$REGISTRY" 2>/dev/null
}

@test "template-owned files match the template unless a divergence is registered" {
  drift=()
  # CANDIDATES: the files this repo declares should track the template byte-for-byte.
  # Derive these from the adoption walk (Adoption & update — no silent drops), e.g. the
  # template's config/CI/gate files that this repo adopted verbatim.
  for rel in "${CANDIDATES[@]}"; do
    is_registered_divergence "$rel" && continue
    [ -f "$TEMPLATE_DIR/$rel" ] || continue   # template no longer ships it; not a sync target
    if ! diff -q "$TEMPLATE_DIR/$rel" "$REPO_ROOT/$rel" >/dev/null 2>&1; then
      drift+=("$rel")
    fi
  done
  [ "${#drift[@]}" -eq 0 ] || {
    printf 'drifted from template (register the divergence or re-sync): %s\n' "${drift[@]}"
    false
  }
}
```

Notes:

- **`CANDIDATES`** is the list of files meant to stay in sync — populate it from the adoption
  walk, not by guessing. A file the template no longer ships is skipped (not a drift).
- Prefer the **GitHub MCP** (`mcp__github__get_file_contents` at the pinned `_commit`) over a
  clone when the test runs somewhere a clone is awkward; the clone form above is the portable
  default.
- This is a **skeleton to adapt**, not a drop-in: the candidate set, registry path, and
  template-materialization step are per-repo. Verify it passes against the current tree before
  committing it.
