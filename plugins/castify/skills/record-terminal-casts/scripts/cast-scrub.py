#!/usr/bin/env python3
"""cast-scrub.py — delete terminal-output events from an asciicast (v2) file.

A `.cast` is JSON: a header object on line 1, then `[time, "o"|"i", data]`
event lines. Because the timestamps are absolute (seconds from start), deleting
an output event is safe — the remaining events keep their timing; you just lose
whatever that event drew. Use it to remove environment noise a recording picked
up (a `direnv:` hook line, a shell greeting, a stray notification) without
re-recording.

Usage:
    cast-scrub.py IN.cast OUT.cast [--pattern REGEX ...]

Default patterns target common shell-startup noise. Patterns match against the
event's data with ANSI escape sequences stripped, so you match on visible text.
Any "o" event whose visible text matches *any* pattern is dropped.
"""
import argparse
import json
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[<>=]|\x1b[PX^_].*?\x1b\\|\x1b.")
DEFAULT_PATTERNS = [r"direnv:"]


def visible(s: str) -> str:
    return ANSI.sub("", s)


def main() -> int:
    ap = argparse.ArgumentParser(description="Drop matching output events from an asciicast v2 file.")
    ap.add_argument("infile")
    ap.add_argument("outfile")
    ap.add_argument("--pattern", action="append", default=None,
                    help="regex to match against visible event text (repeatable); "
                         f"default: {DEFAULT_PATTERNS}")
    args = ap.parse_args()
    patterns = [re.compile(p) for p in (args.pattern or DEFAULT_PATTERNS)]

    kept = dropped = 0
    with open(args.infile, encoding="utf-8") as f, open(args.outfile, "w", encoding="utf-8") as out:
        for i, line in enumerate(f):
            if i == 0:                      # header passes through untouched
                out.write(line)
                continue
            if not line.strip():
                continue
            ev = json.loads(line)
            if len(ev) >= 3 and ev[1] == "o" and any(p.search(visible(ev[2])) for p in patterns):
                dropped += 1
                continue
            out.write(line)
            kept += 1
    print(f"scrubbed {args.infile} -> {args.outfile}: kept {kept}, dropped {dropped}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
