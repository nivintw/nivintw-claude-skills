---
name: doctor
description: >-
  Use when the user asks "am I on the latest version", "is dev-kit (or any plugin) up to
  date", "check my plugin versions", "why am I running an old skill", "did the update take",
  or "what skills do I have". Does two things: (1) a version-drift check — compares the plugin
  versions loaded this session and cached on disk against the latest releases, flagging when a
  stale cache runs an old skill despite a newer release (even with autoupdate on); and (2) a
  skill inventory — lists the marketplace's plugins and their skills, one line each.
---

# doctor

A health check for the installed Claude Code plugins from this marketplace. Two jobs:
**catch version drift** (the loaded/cached skill is older than what's released) and
**inventory** what's installed. It reads the local plugin cache and the repo's release tags;
it never mutates anything.

## Check for version drift

The trap this exists to catch: a skill runs from an **old cached version** even though a newer
one is released and autoupdate is on — so a fix you shipped isn't the code that ran. Three
versions can disagree, and you must check all three:

1. **Running** — the version *this session loaded*. You can read it directly: when a skill is
   invoked, its load banner names its base directory, e.g.
   `…/plugins/cache/<marketplace>/<plugin>/<version>/skills/<skill>`. That `<version>` is what
   actually executed.
2. **Newest cached** — the newest version present on disk under
   `~/.claude/plugins/cache/<marketplace>/<plugin>/`. The running version can be *older* than
   this if the session loaded a stale entry.
3. **Latest released** — the newest `<plugin>-v<version>` release tag on the repo.

The script compares two of these (newest-cached vs latest-released); the **running** version is
visible only to *you*, from the load banner — so the check is two-handed, and the
running-version comparison is the half that catches the headline bug. Do both, every run:

**Step 1 — read the running versions (the headline check, do it first).** For each skill
invoked this session, read the `<version>` out of its load-banner base directory
(`…/<plugin>/<version>/skills/<skill>`). That is the code that actually executed — the one
thing no script can see for you, and the one most likely to be silently stale.

**Step 2 — run the helper for newest-cached vs latest-released:**

```bash
# defaults to the nivintw-claude-skills marketplace
"${CLAUDE_PLUGIN_ROOT}/skills/doctor/scripts/plugin-doctor.sh"
# or target another marketplace / repo explicitly
"${CLAUDE_PLUGIN_ROOT}/skills/doctor/scripts/plugin-doctor.sh" <marketplace> <owner/repo>
```

It prints a `PLUGIN / INSTALLED / LATEST / STATUS` table and a summary line (always exiting 0 —
drift is reported in the output, not the exit code), noting how many versions are cached; a
large cache is the breeding ground for the stale-load bug. The **INSTALLED** version is read
from each cached entry's `.claude-plugin/plugin.json` — the manifest is canonical — not from
the cache directory's name, so a mislabeled or renamed cache dir can't misreport what's
installed (it falls back to the dir name only when the manifest is unreadable).

The **STATUS** column distinguishes two failure modes that used to collapse together:

- **`no release yet (no <plugin>-v* tag)`** — the tag lookup *succeeded* but this plugin has
  no matching release tag. Benign and per-plugin (a new plugin not yet cut).
- **`release lookup failed … cached-only`** — the tag lookup itself *failed* (an `HTTP 404`
  on the repo, or a network/auth error). Latest-released can't be resolved for *anyone*, so
  drift can't be judged; the table degrades to cache-only and the summary says so explicitly.
  This is a transport problem, not "no release."

**Step 3 — reconcile running vs newest-cached vs latest-released** and prescribe the fix:

- **running < newest cached** → the session loaded a stale entry though a newer one is already
  on disk → **`/reload-plugins`** (restart the session if it doesn't pick it up). This is the
  exact stale-load bug, and only Step 1 catches it.
- **newest-cached < latest released** → the newer release is published but not yet downloaded
  — wait for autoupdate to fetch it, then **`/reload-plugins`** (or it's live next session);
  a bare `/reload-plugins` is a no-op until autoupdate downloads the release.
- **all three equal** → current; say so plainly.

## Inventory the installed skills

Answer "what do I have and what's it for" by listing each plugin in the marketplace and the
skills under it, with the one-line purpose from each skill's frontmatter. Read the plugins
from the cache (`~/.claude/plugins/cache/<marketplace>/<plugin>/<newest>/skills/*/SKILL.md`)
or, when run inside the marketplace repo, from `plugins/<plugin>/skills/*/SKILL.md`. For each
skill, surface its `name` and a trimmed first sentence of its `description`. Group by plugin,
and mark which plugins/skills are **loaded in this session** versus merely installed, so the
user can see the gap between available and active.

### Classify installed hooks (blocking vs advisory)

The helper's **HOOKS** section lists every hook each plugin installs (from its
`hooks/hooks.json`) and classifies each as **blocking** or **advisory** — because a hook that
can silently veto your actions is worth knowing about. The heuristic: a hook is **blocking**
when it runs on a *decision-capable* event — one whose output or exit can veto an action
(`PreToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`) — **and** its command script emits
a veto: a `deny` permission decision, a `block` decision, or a deliberate `exit 2` /
`sys.exit(2)`. Everything else is **advisory**: a non-decision event (`PostToolUse`,
`SessionStart`/`SessionEnd`, `Notification`, `PreCompact`) can only annotate, inject, or log,
and a decision-capable event whose script never vetoes just observes. A decision-capable hook
whose script can't be located to confirm is reported `blocking?` — the event gives it the
power, we just couldn't verify use. (Classification needs `jq`, which ships with Claude Code;
without it the section notes that it was skipped.)

## Tooling

Prefer the **GitHub MCP** (or `gh`) to resolve the latest release tags; the helper script
uses `gh api repos/<owner>/<repo>/tags`. If `gh` is absent the drift check degrades to
"latest unknown"; if `gh` is present but the tags call *fails* (an `HTTP 404`, or a
network/auth error) the check degrades to **cache-only** with an explicit "release lookup
failed" message — kept distinct from a plugin that merely has no release yet. Either way the
inventory still works from local files — don't fail the whole run over a missing release
lookup.
