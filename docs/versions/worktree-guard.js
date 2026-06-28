/*
 * SPDX-FileCopyrightText: © 2026 Tyler Nivin
 * SPDX-License-Identifier: MIT
 */

/* Single-version shim for the worktree-guard docs badge. release-please bumps the version
   on the annotated line below (a `generic` extra-files updater on worktree-guard's release);
   the pages render it from window.PLUGIN_VERSIONS into every [data-version="worktree-guard"]
   badge. One version per file means the unscoped generic updater can't clobber another
   plugin's version. Loaded via <script>, so badges work from file:// with no server. */
window.PLUGIN_VERSIONS = Object.assign(window.PLUGIN_VERSIONS || {}, { "worktree-guard": "0.2.0" }); // x-release-please-version
