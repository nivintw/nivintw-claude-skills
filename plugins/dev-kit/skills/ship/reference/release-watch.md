# Release watch — poll for the tag and release that release-please cuts asynchronously

After a **release-please Release PR** merges, the CI pipeline cuts a new `<plugin>-v<version>`
tag and GitHub Release asynchronously — land never waits on that pipeline, and neither does the
human, so you'd otherwise be left manually polling. This file packages that post-merge watch
as a mechanic encoded once: poll for the expected tag, report the version and release notes
when it lands, confirm the closed issues, then clean up the poll job. It is a companion to
land's Post-merge cleanup, not part of the pre-merge loop.

## 1. When this applies

Only after a **release-please Release PR** merges — a PR whose title matches
`chore(main): release …` or `chore(<pkg>): release …`. This is categorically different from
landing a normal feature or fix PR:

- A feature/fix PR merges into `main`; release-please's `main.yml` then opens (or updates) a
  Release PR for the affected plugin. No tag is cut at this point.
- A Release PR merges; `main.yml` then cuts the `<plugin>-v<version>` tag + GitHub Release for that
  plugin. **This is the trigger.** This repo is per-plugin: tags look like `dev-kit-v0.11.0`,
  `castify-v0.2.1` — one tag per plugin per release.

Do not run this watch after a normal feature/fix merge. It is a no-op there and will poll
indefinitely for a tag that release-please won't cut until the next Release PR merges.

## 2. Determine the expected tag

Read the version from the plugin's `.claude-plugin/plugin.json` (`$.version`, the field
release-please bumps) **after the Release PR merges** — that is the version the release
pipeline will tag. Form:

```text
<plugin>-v<version>    # e.g. dev-kit-v0.11.0
```

Here `<plugin>` is **not** the bare directory name — it's the package's `component` field
in `.config/release-please-config.json` (`packages["plugins/<name>"].component`, e.g.
`dev-kit`), which is what release-please uses as the tag prefix.

## 3. Poll for the tag and release

Prefer **GitHub MCP reads** over `gh` for polling (same discipline as the pre-merge CI
watch):

```text
# MCP — preferred
mcp__github__get_release_by_tag  { owner, repo, tag: "<plugin>-v<version>" }
mcp__github__get_latest_release  { owner, repo }          # cross-check
mcp__github__list_tags           { owner, repo }           # if the release object lags

# gh fallback (acceptable when MCP isn't available)
gh release view <plugin>-v<version>
gh release list --limit 5
```

Poll in a bounded loop — check every ~60 s, give up and surface after ~15 minutes if the
pipeline hasn't fired. A stuck pipeline (no tag after the timeout) is a signal to inspect
`main.yml` runs manually, not to keep polling silently.

## 4. The self-deleting poll cron

Rather than blocking the session, set up a **harness poll cron** (CronCreate) that ticks
every minute, checks for the expected tag, and self-deletes once it fires:

1. **Create the cron** — poll interval 1 min, prompt: check for `<tag>` via
   `mcp__github__get_release_by_tag`; if found, report version + release notes, run step 5,
   then self-delete (CronDelete this job's ID).
2. **On found** — extract the tag name, release URL, body (release notes), and published
   timestamp from the release object. Report them to the user in a short summary.
3. **Self-delete** — the cron deletes itself on first success so it doesn't keep ticking
   after the release lands. If the bounded timeout fires instead, the cron reports the
   miss, surfaces the `main.yml` run URL for inspection, and self-deletes.

Keep the cron prompt tight: one MCP call to check the tag, branch on found vs. not-found,
report and self-delete vs. continue. No branching logic that can loop on error.

## 5. Confirm closed issues

Once the release tag is confirmed, verify the issues the Release PR closed are actually
closed — release-please's `Closes #N` trailer is usually reliable, but a typo'd reference
or a manually-wired issue can slip through. Delegate to **`/dev-kit:handle-task-tracking`**
for this check; do not reimplement it here. Clear any stale `status:in-*` labels the same
way land's Post-merge step does.

## What this is not

- **Not a release-please config change.** This procedure watches a release that release-please
  is already configured to cut. If a plugin isn't wired into `.config/release-please-config.json`
  or `.config/.release-please-manifest.json`, fix the config separately — watching won't
  conjure a missing release.
- **Not a `copier update` trigger.** A new plugin release does not mean it's time to pull
  template changes from `copier-everything`. Template updates are a separate, deliberate act.
- **Not a re-implementation of land's pre-merge CI watch.** The pre-merge loop (in
  `pr-landing-driver.md`) watches the feature/fix PR's checks before merging. This
  watch runs *after* a Release PR merges and polls for the asynchronous tag — different
  pipeline, different trigger, different state.
