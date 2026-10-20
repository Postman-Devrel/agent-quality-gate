# quality-gate-panel

A Claude Code mod that shows this repo's quality gate while you work.

- **Band above the prompt**: `Gate A 93/100`, one dot per step (green pass, orange warn, red fail, hollow when `not_available`), the source (`local` or `ci@<sha>`) and the CI state while a run is in progress.
- **Status line**: `Gate A 93`.
- **`/gate`**: a pane with the step table, the blockers and the "What to fix" findings.
- **Toasts** when the CI run of the current commit changes state.

## Where the data comes from

- The local report `gate-results/report.json`, written by `./gate/run-all.sh`.
- The CI report: the mod polls `gh run list` for the current branch every 20 seconds and, when the run for the checked-out commit is finished, downloads the `gate-report` artifact into `gate-results/ci/` (git-ignored). The CI report wins over the local one for the same commit.

Needs `git` and an authenticated `gh` in the project directory. Without `gh` the mod shows the local report only.

## Install

From a clone, in Claude Code:

```
/plugin marketplace add ./
/plugin install quality-gate-panel
```

Or run a session with `claude --plugin-dir mods/quality-gate-panel`.

## Status

Validated with `claude plugin validate` and type-checked with `tsc`. It has no automated tests yet (`claude plugin test` was unavailable when it was written).
