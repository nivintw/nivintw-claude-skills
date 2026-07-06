# nivintw-claude-skills

Tyler Nivin's Claude Code plugins — a scriptable terminal-recording toolkit and a human +
AI development workflow. Add the marketplace, install a plugin, then just ask Claude Code.

## Plugins

Three plugins — twelve commands and a worktree-safety hook.

<div class="grid cards" markdown>

-   :material-console-line: **[castify](castify.md)** <span data-version="castify"></span>

    ---

    Scriptable asciinema recordings. Script every keystroke and pause instead of performing
    a session live, so casts are reproducible and deterministic — and so you can record
    interactive TUIs like `fzf`, `less`, and `vim` at all.

    [`/castify:record-terminal-casts`](castify.md#commands)

-   :material-source-pull: **[dev-kit](dev-kit/index.md)** <span data-version="dev-kit"></span>

    ---

    A human + AI teaming development workflow. Take a change from idea to a reviewed PR,
    track the work as issues, pick what to do next, and keep your local clone and docs tidy
    — with the human in control at the ends.

    [`/dev-kit:ship`](dev-kit/ship.md) · [`/dev-kit:review-pr`](dev-kit/review-pr.md) ·
    [11 commands total](dev-kit/index.md#commands)

-   :material-shield-check-outline: **[worktree-guard](worktree-guard.md)**
    <span data-version="worktree-guard"></span>

    ---

    A safety net for git-worktree work. One `PreToolUse` hook that blocks an accidental
    write to the **parent checkout** while you're in a worktree — editing main's copy
    instead of the worktree's. Inert outside a worktree; fail-open on any error.

    No commands — [install it and it just watches](worktree-guard.md#install).

</div>

## Install

=== "From the marketplace"

    ```text
    # add the marketplace
    /plugin marketplace add nivintw/nivintw-claude-skills
    # install a plugin
    /plugin install castify@nivintw-claude-skills
    /plugin install dev-kit@nivintw-claude-skills
    /plugin install worktree-guard@nivintw-claude-skills
    ```

=== "From a local clone"

    Point the marketplace at the directory instead of the GitHub repo:

    ```text
    /plugin marketplace add ~/workspace/nivintw-claude-skills
    ```

    Then install plugins the same way as above.

Once installed, just ask Claude Code for what you want — the skills activate on their own;
there's nothing else to configure.
