---
name: pre-public-hardening
description: >-
  Use when the user asks to "make this repo public", "prep this repo to go public", "is this
  repo safe to open-source?", "harden before publishing", "scan the git history for secrets",
  or "pre-public review". Drives a whole-repo, full-history readiness review: scanning every
  commit for secrets (not just the working tree), auditing .gitignore for leak gaps, flushing
  private-context artifacts, and verifying license completeness — producing a go/no-go
  checklist for the human. Complements the gate's working-tree gitleaks scan rather than
  replacing it: the gate can't see a secret committed and later removed, but this skill can.
  It does NOT flip visibility or rewrite history — it detects and prescribes; the human acts.
---

# pre-public-hardening

Once a repo goes public, its git history is public — permanently. A secret committed in
week one and deleted in week three is still in every clone, still in GitHub's object
store, still retrievable by anyone with the URL. The risk surface isn't just the current
file tree; it's every commit ever made, plus docs and comments written for a
private-development context that now read as noise or unintentional leaks to an external
audience. This skill closes that gap with a disciplined pre-publish review: full-history
secret scan, .gitignore audit, private-artifact flush, and license verification — before
the visibility switch is flipped.

## Full-history secret scan

The headline check — and the one a commit-time hook cannot do. A gitleaks pre-commit hook
(if your repo's gate runs one, as dev-kit's home marketplace does) sees only the working
tree and staged changes; a secret committed and later deleted is invisible to it but still
fully present in `.git`. Scan the **entire commit graph** before publishing:

```bash
gitleaks git --log-opts="--all"
```

`--log-opts="--all"` walks every ref — all branches, all tags — so no commit is missed.
`gitleaks detect --source . --log-opts="--all --full-history"` also covers the full graph
on older gitleaks (`detect` is the legacy command); `gitleaks git` is the idiomatic form on
current versions when scanning history rather than the working tree.

Any hit means the repo is **not safe to publish as-is**. The required response is:

1. **Rotate the secret immediately** — assume it's already compromised; a secret in git
   history is as public as a tweet the moment the repo goes public.
2. **Rewrite history** to physically remove it. `git filter-repo` (preferred) or BFG
   Repo Cleaner are the standard tools. Deleting the file in a new commit is NOT enough:
   the secret remains in all prior commits and is trivially recoverable.
3. **Force-push and notify collaborators** to re-clone or reset — anyone with a local
   copy of the old history still has the secret.

If your repo's gate already includes gitleaks (as dev-kit's home marketplace does), it's
installed; otherwise grab it first (`brew install gitleaks`, or see the gitleaks install
docs).

## .gitignore audit

Once public, contributors will clone and experiment — and `.gitignore` is what prevents
them from accidentally committing secrets or local-only files. Audit it before publishing.

**Patterns that should be present** (adjust for stack):

- `.env`, `.env.*`, `.env.local` — environment files with credentials
- `*.key`, `*.pem`, `*.p12`, `*.pfx` — private keys and certificates
- specific credential filenames — `credentials.json`, `secrets.yaml`, service-account keys.
  Prefer named files over blanket `*secret*` / `*credentials*` globs: a broad glob hides
  legitimate files (a `secrets/` *docs* page, a `credentials.example`) and trips the inverse
  risk below.
- `*.local` — local-override config files
- Editor and OS cruft: `.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/settings.json`

**The inverse risk**: patterns so broad they hide files that SHOULD be tracked. A
wildcard like `*.json` or `/config/` silently suppresses tracked config and is actively
harmful in a public repo where new contributors won't understand what's missing.
Cross-check with `git ls-files --cached --ignored --exclude-standard` — it lists **tracked**
files that match an ignore pattern (git requires the `--cached`/`--others` mode flag
alongside `--ignored`), catching exactly this inverse risk where a catch-all silently covers
files you meant to track. (Swap `--cached` for `--others` to inspect untracked-but-ignored
files instead.)

## Private-conversation & AI-artifact scan

Scan docs, markdown, comments, and commit messages for content that only made sense in
a private-development context. Categories to look for:

- **Session transcripts and inline chat** — "as we discussed", "as you suggested",
  "based on our earlier conversation", snippets that read like a conversation excerpt.
- **Internal-audience TODOs** — comments naming people, referencing internal systems, or
  assuming context no external contributor would have ("ask Alice about this", "see the
  Confluence page").
- **AI-assistant attribution and boilerplate** — "Generated by ChatGPT", "Co-authored
  by Claude", hallmark AI-assistant phrasing in comments or docs. If your project bans AI
  attribution (as dev-kit's home does for commits and PRs), extend that scrutiny to the full
  file tree before publishing.
- **Scratch notes and WIP markers** — temporary reasoning, half-finished TODOs addressed
  to oneself, comments like "figure this out later" with no resolution.

These don't all block publishing on their own, but they read poorly to an external
audience and signal a repo that wasn't cleaned up. Grep for the common tell-phrases;
read any markdown in `docs/` or at the repo root with fresh eyes as if you're a
contributor seeing it for the first time.

## License & SPDX completeness

Publishing without a license means the repo is legally all-rights-reserved by default —
contributors can read it but cannot fork, use, or modify it. This is almost never what
"open-source" means. The portable goal: every repo going public needs a clear, correct
license. Verify:

- **A license is present and correct** — a root `LICENSE` file is the standard, sufficient
  form for most repos. Confirm it's the **intended** one: MIT, Apache-2.0, and AGPL-3.0 have
  meaningfully different downstream terms.
- **The copyright year and holder are correct** — stale years or placeholder names create
  real ambiguity about ownership.

If your repo uses **REUSE/SPDX** (as dev-kit's home marketplace does — `hawkeye` for inline
headers, `REUSE.toml` for markdown/JSON that can't carry them without breaking parsers), run
`reuse lint` to confirm every file carries license info and that `LICENSES/<SPDX-ID>.txt`
holds the license text:

```bash
reuse lint   # only if the repo has adopted REUSE/SPDX
```

If it doesn't use REUSE, a bare root `LICENSE` is correct and complete — don't treat it as a
defect.

## Go / no-go checklist

Produce this checklist and get explicit sign-off before flipping visibility. Every item
is a hard gate — any NO blocks publishing.

- [ ] **Full-history secret scan clean** — `gitleaks git --log-opts="--all"` returned
  zero findings, or all hits have been rotated and the commits physically removed via
  `git filter-repo` or BFG.
- [ ] **.gitignore covers secret patterns** — `.env`, key/cert patterns, and local-
  override files are ignored; no overly-broad pattern silently hides tracked files.
- [ ] **No private-conversation or AI artifacts** — docs, comments, and commit messages
  read cleanly to an external audience; no session fragments, internal-audience TODOs,
  or AI attribution boilerplate remain.
- [ ] **License present and correct** — the intended license is in place (a root `LICENSE`
  suffices); if the repo uses REUSE/SPDX, `reuse lint` passes and `LICENSES/` holds the
  right text.
- [ ] **README and docs reframed for an external audience** — assumes no knowledge of
  private development history, has a working "get started" path, and doesn't reference
  internal context.

## What this is not

- **Not a visibility toggle** — the human flips the repo public, deliberately, after the
  checklist passes. This skill never touches repo settings.
- **Not a replacement for a commit-time gitleaks hook** — if your repo's gate runs gitleaks
  (as dev-kit's home does), that prevents secrets from being committed in the first place;
  this skill adds full-history and whole-repo audits on top. If it doesn't, this full-history
  scan is your only secret check — all the more reason to run it.
- **Not history rewriting itself** — when a scan finds a secret in history, this skill
  prescribes `git filter-repo` or BFG and explains why; the human runs it. Rewriting
  history on a repo with existing collaborators requires coordination this skill cannot
  do for you.
- **Not a general code security audit** — it covers the go-public-specific risks (secret
  history, license gaps, private artifacts). For a broader security review of the code
  itself, reach for `/security-review`.
