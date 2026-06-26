#!/usr/bin/env bash
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

# example-fixtures.sh — build clean, throwaway fixtures to record against.
#
# Casts read best when the working tree is predictable: known branches, known
# search hits, known caches. Build that in a temp dir so recordings are
# reproducible and never touch real work. This example backs the demos in
# example-record.sh (fzf git checkout, ripgrep search, multi-repo status,
# python-cache cleanup). Adapt it to whatever your own commands need.
set -euo pipefail
LAB="${CAST_LAB:-/tmp/castlab}"
rm -rf "$LAB/demo" "$LAB/multi" "$LAB/pyproj"
mkdir -p "$LAB/demo" "$LAB/multi" "$LAB/pyproj"

# Keep fixture git history isolated from your real identity/config.
export GIT_AUTHOR_NAME=dev GIT_AUTHOR_EMAIL=dev@example.com
export GIT_COMMITTER_NAME=dev GIT_COMMITTER_EMAIL=dev@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

# ---- demo repo: branches + searchable source (branch picker, file search) ----
cd "$LAB/demo"
git init -q -b main
mkdir -p src
cat >src/auth.py <<'EOF'
def login(user, password):
    """Authenticate a user and start a session."""
    return issue_token(user)


def logout(session):
    session.invalidate()
EOF
cat >src/api.py <<'EOF'
def handler(request):
    # TODO: rate-limit the login endpoint
    if request.path == "/login":
        return login(request.user, request.password)
    return not_found()
EOF
printf '# demo\n\nA tiny project used to record terminal casts.\n' >README.md
git add -A && git commit -qm "Initial commit"
git branch feature/login
git branch feature/api-pagination
git branch bugfix/session-typo

# ---- multi-repo parent (run-across-every-repo helpers) -----------------------
for r in api web infra; do
  cd "$LAB/multi"
  git init -q -b main "$r"
  cd "$r"
  echo "# $r" >README.md
  git add -A && git commit -qm "Initial commit"
done
echo "draft" >"$LAB/multi/web/notes.md"                             # untracked → shows in status
cd "$LAB/multi/api" && echo "x" >config.yaml && git add config.yaml # staged

# ---- python project with caches (cache cleanup) ------------------------------
cd "$LAB/pyproj"
mkdir -p pkg/__pycache__ tests __pycache__ .pytest_cache .mypy_cache .ruff_cache
printf 'def add(a, b):\n    return a + b\n' >pkg/calc.py
: >pkg/__pycache__/calc.cpython-312.pyc
: >__pycache__/conftest.cpython-312.pyc
: >.pytest_cache/CACHEDIR.TAG
: >.mypy_cache/.gitignore
: >.ruff_cache/CACHEDIR.TAG
: >tests/test_calc.pyc

echo "fixtures ready under $LAB"
