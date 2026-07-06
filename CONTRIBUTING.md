<!--
SPDX-FileCopyrightText: © 2026 Tyler Nivin
SPDX-License-Identifier: MIT
-->

# Contributing to nivintw-claude-skills

Thanks for contributing!

## Workflow

1. Branch off `main` and land changes via a PR (enable branch protection to enforce it).
2. Install the hooks: `uvx prek@0.4.8 install`.
3. Make your change. The pre-commit hooks run the full quality gate — the same checks run in CI.
4. Commit with plain [Conventional Commits](https://www.conventionalcommits.org) (no
   leading emoji — release-please can't parse one), enforced by commitizen at commit-msg time.
5. Open a PR and make sure CI is green before requesting review.

## Running the quality gate

```bash
uvx prek@0.4.8 run --all-files
```
