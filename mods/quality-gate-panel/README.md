# quality-gate-panel

A Claude Code mod that shows this repo's quality gate while you work, without leaving the session.

## What it shows

- **`/gate` (and `/gate-all`)**: one wide pane, docked beside the conversation where the surface allows it. It also tries to open at session start, after a `git push` or `gh pr create`, and when the CI run of the current commit finishes (the surface decides whether there is room). Columns are fixed-width cells and the score bars are colored runs of spaces, so the layout holds in a proportional font.
  - **Local and CI cards**: side by side, click one to pick which report the detail below follows. Rounded cards, vibrant colors.
  - **Collapsible sections**: BRANCHES and WHAT TO FIX fold with their `▾`/`▸` button; a `→` button per branch asks the agent about it.
  - **Branches and pull requests**: the latest finished run of the workflow per branch, with its rating, score, blockers, commit and open PR number; the current branch is marked.
  - **This branch**: the step table, the blockers and the "What to fix" findings.
  - **Buttons** (icons): 🔧 puts the fixes brief for api-coder in the prompt box (you read it, then Enter); ↻ puts the re-run command in the prompt box.
- **A band above the prompt** (`/gate-band`, off by default): the local score and the CI score side by side (with a warning when they differ), PR counts and four icon buttons: ↻ (re-run the gate) and 🔧 (ask for a fix) send the matching prompt to the agent at once, ⧉ opens the pane, ✕ hides the band.
- **Toasts and a prompt suggestion** when the CI run for the checked-out commit finishes. The suggested next prompt (apply the fixes, or summarize and open a PR) is only proposed; Tab takes it.
- **Status line**: `Gate A 93`.

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
- Validated with `claude plugin validate` and type-checked with `tsc`. No automated tests yet: `claude plugin test` was unavailable when it was written.
