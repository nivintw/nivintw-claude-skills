---
title: dev-kit doctor
---

# doctor

A health check for the plugins installed from this marketplace. It catches **version drift**
— the skill that just ran is older than what's released, even with autoupdate on — and
inventories what's installed. Read-only: it diagnoses and prescribes, never mutates.

## Usage

```text
/dev-kit:doctor
```

Natural-language forms work too: *"am I on the latest version"*, *"check my plugin
versions"*, *"did the update actually take"*, *"list my plugins and skills"*.

## What it does

Two jobs. The drift check reconciles **three** versions per plugin, because any pair can
disagree:

1. **Read the running versions** — for each skill invoked this session, the version in its
   load-banner path (`…/<plugin>/<version>/skills/<skill>`) is the code that actually
   executed. Only this in-session read catches the headline bug; no script can see it.
2. **Run the bundled helper** — compares newest-cached (on disk under
   `~/.claude/plugins/cache/`) against latest-released (the repo's `<plugin>-v<version>`
   tags) and prints a `PLUGIN / INSTALLED / LATEST / STATUS` table.
3. **Reconcile and prescribe** — running < newest cached means the session loaded a stale
   entry: `/reload-plugins` (restart if it doesn't take). Newest cached < latest released
   means the release isn't downloaded yet: wait for autoupdate, then reload. All three
   equal: current, said plainly.
4. **Inventory** — lists each plugin and its skills with a one-line purpose from the
   frontmatter, marking which are loaded this session versus merely installed.

Release tags come from the GitHub MCP or `gh`; without either, the check degrades to
"latest unknown" and the inventory still works from local files.

## When to reach for it

Whenever a skill seems out of date, a shipped fix doesn't seem to be the code that ran, or
you just want to see what's installed and what each skill is for. It is not an updater —
it never downloads, reloads, or deletes anything; it tells you exactly which command to
run, and why.

!!! note "Reloading can't fetch what isn't there"
    A bare `/reload-plugins` is a no-op until autoupdate has actually downloaded the newer
    release. When newest-cached lags latest-released, the wait comes first — reloading just
    re-picks the newest entry already on disk.

## Related

- [`ship`](ship.md) — after shipping a skill fix, `doctor` confirms that fix is the code
  actually running in your session.
- [`land`](land.md) — merging a Release PR is what cuts the `<plugin>-v<version>` tag
  `doctor` treats as latest-released.
- [dev-kit overview](index.md) — the static roster of skills; `doctor`'s inventory is its
  live, per-session counterpart.
