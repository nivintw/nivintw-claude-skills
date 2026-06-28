#!/usr/bin/env python3
# SPDX-FileCopyrightText: © 2026 Tyler Nivin
# SPDX-License-Identifier: MIT

"""Safety net for the release-please per-plugin release wiring.

Under release-please, feature PRs deliberately do NOT bump a plugin's version — a
separate Release PR does. So the classic "fail the PR if a plugin changed without a
version bump" check would block every feature PR. This guards the same failure class
(a plugin whose version silently never tracks its changes) by enforcing *consistency*
of the release wiring instead:

  1. Every plugin on disk (plugins/<name>/.claude-plugin/plugin.json) is registered in
     BOTH .config/release-please-config.json and .config/.release-please-manifest.json — so
     release-please actually versions it. A new plugin that's never wired in would otherwise
     release never, reproducing the original bug.
  2. There are no orphan config/manifest entries pointing at a plugin that doesn't exist.
  3. Each plugin.json `version` equals its .config/.release-please-manifest.json entry — catching
     manual drift or a half-applied bump (manifest and plugin.json must agree).
  4. Each config package carries the extra-files entry that points release-please at
     plugin.json `$.version` — the wiring that actually performs the bump. A package added
     without it (the fiddliest part to copy-paste) would tag + bump the manifest while never
     touching plugin.json, silently reintroducing the drift this gate prevents.

Stateless and tree-only (no git history needed), so it runs as a prek hook and in the gate.
Exits non-zero with a list of every problem found.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG = REPO_ROOT / ".config" / "release-please-config.json"
MANIFEST = REPO_ROOT / ".config" / ".release-please-manifest.json"
PLUGINS_DIR = REPO_ROOT / "plugins"


def _load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        sys.exit(f"error: {path.relative_to(REPO_ROOT)} not found")
    except json.JSONDecodeError as exc:
        sys.exit(f"error: {path.relative_to(REPO_ROOT)} is not valid JSON: {exc}")


def main() -> int:
    config = _load_json(CONFIG)
    manifest = _load_json(MANIFEST)

    # Source of truth: plugins that actually exist on disk (have a plugin.json).
    disk: dict[str, str] = {}
    for plugin_json in sorted(PLUGINS_DIR.glob("*/.claude-plugin/plugin.json")):
        rel = plugin_json.parent.parent.relative_to(REPO_ROOT).as_posix()  # plugins/<name>
        data = _load_json(plugin_json)
        version = data.get("version")
        if not isinstance(version, str) or not version:
            sys.exit(
                f"error: {plugin_json.relative_to(REPO_ROOT)}: 'version' must be a non-empty string"
            )
        disk[rel] = version

    packages = config.get("packages", {})
    config_paths = set(packages)
    manifest_paths = set(manifest)
    disk_paths = set(disk)

    problems: list[str] = []

    membership_checks = [
        (disk_paths - config_paths, "on disk but missing from .config/release-please-config.json packages"),
        (disk_paths - manifest_paths, "on disk but missing from .config/.release-please-manifest.json"),
        (config_paths - disk_paths, "in .config/release-please-config.json but no plugin exists on disk"),
        (manifest_paths - disk_paths, "in .config/.release-please-manifest.json but no plugin exists on disk"),
    ]
    for paths, reason in membership_checks:
        problems.extend(f"{path}: {reason}" for path in sorted(paths))

    # Version agreement: plugin.json must match the manifest version of record.
    for path in sorted(disk_paths & manifest_paths):
        if disk[path] != manifest[path]:
            problems.append(
                f"{path}: version drift — plugin.json={disk[path]} "
                f"but .config/.release-please-manifest.json={manifest[path]}"
            )

    # The wiring that actually bumps plugin.json: each package must carry the extra-files
    # entry pointing release-please at .claude-plugin/plugin.json $.version. A package
    # registered without it bumps the manifest + tag while silently never touching
    # plugin.json — reintroducing the very drift this gate exists to prevent.
    for path in sorted(config_paths & disk_paths):
        extra_files = packages[path].get("extra-files", [])
        if not any(
            isinstance(entry, dict)
            and entry.get("type") == "json"
            and entry.get("path") == ".claude-plugin/plugin.json"
            and entry.get("jsonpath") == "$.version"
            for entry in extra_files
        ):
            problems.append(
                f"{path}: .config/release-please-config.json package is missing the extra-files entry "
                "{type:json, path:.claude-plugin/plugin.json, jsonpath:$.version} that bumps plugin.json"
            )

    if problems:
        print("Plugin release wiring is inconsistent:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        print(
            "\nFix: register every plugin in .config/release-please-config.json + "
            ".config/.release-please-manifest.json, and keep plugin.json versions in sync with "
            "the manifest (release-please maintains these via Release PRs).",
            file=sys.stderr,
        )
        return 1

    print(f"OK: {len(disk_paths)} plugin(s) consistently wired for release-please.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
