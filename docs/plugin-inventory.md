# Postman plugin inventory

Trace of what the coding agent did through the Postman plugin. The gate checks it independently.

## Plugin

| Item | Value |
|------|-------|
| Plugin | `postman` (claude-plugins-official) |
| Version | 2.0.1 (from the plugin cache directory) |
| Hook | `SessionStart`: routes API-engineering requests to `postman:api-engineer` |
| Postman CLI (local) | 1.73.0 (latest on npm: 1.75.0, so the local copy is outdated) |
| Postman MCP server | `plugin:postman:postman` requires OAuth, not authorized; unused so far |

## Requests

| # | Plain-language request | Skills that ran | Result / artifact |
|---|------------------------|-----------------|-------------------|
| 1 | "Set up a Postman workspace for this repo (agent-quality-gate) with an Orders API." | hook -> `postman:api-engineer` -> `postman:bootstrap` (chain confirmed) | `postman init --visibility personal` wrote `.postman/resources.yaml` and the `postman/` tree. Exit code 5: no workspace created, because the repo has no git `origin` remote. `workspace.id` is empty. |

| 1b | Same request, retried after adding `origin` = `https://github.com/avdev4j/agent-quality-gate.git` | `postman:bootstrap` (`postman init`) | Second run refused (exit 4, `foreign-postman-dir`) because the first run had left a `postman/` folder; I deleted those generated files and re-ran. `init` then exited 5 (`create_forbidden`, workspace call failed). |
| 1c | Fallback after `init` failed to create the workspace | `postman workspace create --visibility personal` (CLI, outside any skill; see gaps) | Workspace `avdev4j/agent-quality-gate`, id `2e8dbc70-159f-41f6-9ecd-13c0c1959f17`, personal. Recorded in `.postman/resources.yaml`. The command also printed "Postman refused this request" after reporting success. |

## Gaps / questions

- `postman init --visibility personal` could not create the workspace (`create_forbidden`), while `postman workspace create` succeeded. The workspace was therefore made by a direct CLI call, which the plan says to flag. Unclear whether the trailing "refused" message is a partial failure; worth checking in the Postman UI.
- Spec, API, collection and mock artifacts: not created yet.
- `postman init --no-cloud`, mentioned in the bootstrap skill, is not in `postman init -h` of CLI 1.73.0.
