# quality-gate-panel

A Claude Code mod that shows this repo's quality gate while you work, without leaving the session.

## What it shows

- **`/gate` (and `/gate-all`)**: one wide pane, docked beside the conversation where the surface allows it. It also tries to open at session start, after a `git push` or `gh pr create`, and when the CI run of the current commit finishes (the surface decides whether there is room). Columns are fixed-width cells and the score bars are colored runs of spaces, so the layout holds in a proportional font.
  - **Toolbox**: 🔧 fix puts the fixes brief of the analysis shown below in the prompt box (you read it, then Enter); ↻ re-run puts the re-run command there; ⟳ refresh reloads local and CI now.
  - **Branches and pull requests**: one row per branch with two scores side by side. **CI** is the latest run of the workflow on the branch: its score once the report is there, else its state (queued, in progress, failed, skipped); **Local** is the report of `./gate/run-all.sh` in this checkout, so only the checked-out branch (marked `▶`) has one. Then the PR number, the blockers and the age. A `→` button per branch asks the agent about it.
  - **Detail**: click a CI or Local score to show that analysis below the table (`▸` marks it): its steps, its blockers and the "What to fix" findings. By default it shows the checked-out branch, CI for HEAD if there is one, else local.
  - BRANCHES and WHAT TO FIX fold with their `▾`/`▸` button.
- **A band above the prompt** (`/gate-band`, off by default): the local score and the CI score side by side (with a warning when they differ), PR counts and four icon buttons: ↻ (re-run the gate) and 🔧 (ask for a fix) send the matching prompt to the agent at once, ⧉ opens the pane, ✕ hides the band.
- **Toasts and a prompt suggestion** when the CI run for the checked-out commit finishes. The suggested next prompt (apply the fixes, or summarize and open a PR) is only proposed; Tab takes it.
- **Status line**: `Gate A 93`.

Colors follow the Postman palette (orange `#FF6C37` accent, Postman's green, yellow and red for pass, warn and fail), as raw hex so they read the same on a light or dark theme.

## Where the data comes from

- The local report `gate-results/report.json`, written by `./gate/run-all.sh`.
- The CI reports: every 20 seconds for the current branch and every 60 seconds for the recent branches, the mod runs `gh run list` and downloads the `gate-report` artifact of finished runs into `gate-results/ci/` (git-ignored). A CI report wins over the local one for the same commit.

Needs `git` and an authenticated `gh` in the project directory. A desktop app often starts with a short `PATH`, so the mod also tries `/opt/homebrew/bin/gh`, `/usr/local/bin/gh` and `/usr/bin/gh`. When `gh` fails, the reason is shown instead of an empty list.

## Install

From a clone, in Claude Code:

```
/plugin marketplace add ./
/plugin install quality-gate-panel
```

Or run a session with `claude --plugin-dir mods/quality-gate-panel`.

## Limits

- Where a pane is placed (beside the conversation or above the prompt) is the surface's choice. The mod asks for 110 columns and 26 rows.
- It cannot add a tab to the app's own side panes (Changes, PR, terminal).
- Validated with `claude plugin validate`, type-checked with `tsc`, and `claude plugin test` runs `tests/pane.test.tsx` (the score buttons and the detail, on the terminal and the desktop).
