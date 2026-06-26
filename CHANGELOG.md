<!--
SPDX-FileCopyrightText: © 2026 Tyler Nivin
SPDX-License-Identifier: MIT
-->

<!-- Managed by commitizen. The first release will populate this file. -->

## v1.0.0 (2026-06-26)

### ✨ Features

- require EnterWorktree/ExitWorktree in ship's worktree phase
- ship opens the PR as a draft until hand-off
- ship converges an automated Copilot review before hand-off
- document the status:in-review transition in task-tracking
- add handle-task-tracking skill and revoice marketplace skills
- add dev-kit plugin (ship, review-pr, generate-docs)

### 🐛🚑️ Fixes

- authenticate releases via CI_CLIENT_ID variable + harden the gate
- account for EnterWorktree/ExitWorktree semantics in ship
- clarify review-pr hand-off wording and a casts phrasing
- clarify status:blocked is orthogonal to the progression labels
- address Copilot review on skill wording and docs sync
- correct MCP command details in task-tracking recipes
- emit hawkeye-canonical SPDX headers from generate-docs
- derive owner/repo marketplace-add target in generate-docs

### ♻️ Refactorings

- tighten task-tracking skill prose after simplify pass

### feat

- **castify**: human-paced typing, cast-scrub tool, quieter recordings
- add castify plugin for scriptable asciinema casts

### 💚👷 CI & Build

- skip the release job until the App secrets exist

### 📝💡 Documentation

- regenerate marketplace docs for handle-task-tracking
- add the generated marketplace docs site
- add CLAUDE.md with marketplace conventions

### 🧹 chore

- update scaffold template to 6d99de4
- reconcile scaffold infra into the existing repo
