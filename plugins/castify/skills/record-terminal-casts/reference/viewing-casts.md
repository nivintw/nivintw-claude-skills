# Viewing and inspecting a cast

A quick reference for what you can (and can't) do with a `.cast` file after recording.

## 1. Quitting the CLI player

Play a cast with `asciinema play casts/<name>.cast`. To stop:

- Press **`q`** or **`Ctrl-C`** — either one quits immediately.
- If the terminal seems unresponsive (e.g. a key got swallowed), **closing the terminal
  tab or window** always works and leaves no side effects.

The player takes over the terminal for playback, so it can occasionally eat input; `q` is
reliable in practice, but the window-close escape hatch is there when needed.

## 2. No scrubber — plays start to finish

The CLI player has **no playback bar and no seek**. It plays the cast from the beginning
at the recorded pace (or a speed you set with `-s <factor>`). If you need to inspect a
specific moment, use the text render (see §3) or the web player in a browser (which does
have a scrubber).

## 3. Checking duration and content without watching

**Duration** is in the cast header. Read it directly:

```bash
head -1 casts/<name>.cast   # JSON header — look for "duration"
```

**Text render** — dump the visible output without playing:

```bash
asciinema convert -f txt casts/<name>.cast /dev/stdout
```

This is also the fastest way to confirm the expected output is present, check for shell
greeting noise, or verify `direnv:` lines were scrubbed.

**`asciinema cat`** streams the raw event data (timestamps + text), useful for inspecting
timing or event structure:

```bash
asciinema cat casts/<name>.cast
```

## 4. Exporting to other formats

**Animated GIF** — `agg` ([asciinema gif generator](https://github.com/asciinema/agg)) converts a `.cast` to a `.gif` (install with `brew install agg`):

```bash
agg casts/<name>.cast casts/<name>.gif
# with options:
agg --theme monokai --speed 1.5 casts/<name>.cast casts/<name>.gif
```

**Other formats** — `asciinema convert` handles several outputs:

```bash
asciinema convert -f gif  casts/<name>.cast casts/<name>.gif  # via asciinema (slower than agg)
asciinema convert -f txt  casts/<name>.cast casts/<name>.txt  # plain text transcript
asciinema convert -f iterm2 casts/<name>.cast casts/<name>.iterm2  # iTerm2 inline image
```

## 5. Scrubbing noise from a cast

The skill ships `scripts/cast-scrub.py` for removing unwanted output events (shell
greetings, `direnv:` hooks, stray notifications) without re-recording. It matches events
by their **visible text** (ANSI escapes are stripped before matching) and drops any output
event (`"o"`) whose text matches a pattern.

```bash
# Drop events matching the default patterns (direnv: lines):
python3 scripts/cast-scrub.py casts/original.cast casts/clean.cast

# Drop events matching a custom pattern:
python3 scripts/cast-scrub.py casts/original.cast casts/clean.cast --pattern "Welcome to"

# Stack multiple patterns (repeatable):
python3 scripts/cast-scrub.py casts/original.cast casts/clean.cast \
  --pattern "direnv:" --pattern "nvm use"
```

The script writes a new file — the original is untouched. It reports how many events
were kept vs. dropped on stderr. Note: this removes events by content, not by timestamp;
for timestamp-based trimming, adjust the cast file's event timestamps by hand or reach
for a dedicated cast-editing tool.
