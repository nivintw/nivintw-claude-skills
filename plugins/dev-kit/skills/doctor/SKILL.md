---
name: doctor
description: >-
  This skill should be used when the user asks "am I on the latest version", "is dev-kit (or
  any plugin) up to date", "check my plugin versions", "why am I running an old version of a
  skill", "did the update actually take", "what skills do I have", "list my plugins and
  skills", or otherwise wants a health check of their installed Claude Code plugins. It does
  two things: (1) a **version-drift check** — compares the plugin versions actually loaded in
  this session and cached on disk against the latest released versions, and flags when a stale
  cache means an old skill is running despite a newer release (even with autoupdate on); and
  (2) a **skill inventory** — lists the marketplace's plugins and their skills with a one-line
  description of each. Reach for it whenever a skill seems out of date, an update doesn't seem
  to have taken, or you just want to see what's installed and what it's for.
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
large cache is the breeding ground for the stale-load bug.

**Step 3 — reconcile running vs newest-cached vs latest-released** and prescribe the fix:

- **running < newest cached** → the session loaded a stale entry though a newer one is already
  on disk → **`/reload-plugins`** (restart the session if it doesn't pick it up). This is the
  exact stale-load bug, and only Step 1 catches it.
- **running or newest-cached < latest released** → a newer version is published but not live
  → **`/reload-plugins`**; note autoupdate can lag a fresh release.
- **all three equal** → current; say so plainly.

## Inventory the installed skills

Answer "what do I have and what's it for" by listing each plugin in the marketplace and the
skills under it, with the one-line purpose from each skill's frontmatter. Read the plugins
from the cache (`~/.claude/plugins/cache/<marketplace>/<plugin>/<newest>/skills/*/SKILL.md`)
or, when run inside the marketplace repo, from `plugins/<plugin>/skills/*/SKILL.md`. For each
skill, surface its `name` and a trimmed first sentence of its `description`. Group by plugin,
and mark which plugins/skills are **loaded in this session** versus merely installed, so the
user can see the gap between available and active.

## Tooling

Prefer the **GitHub MCP** (or `gh`) to resolve the latest release tags; the helper script
uses `gh api repos/<owner>/<repo>/tags`. If neither is available, the drift check degrades to
"latest unknown" and the inventory still works from local files — don't fail the whole run
over a missing release lookup.
