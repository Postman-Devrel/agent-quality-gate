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

| 2 | "Document the Orders contract" | `postman:api-documentation` (read for best practices; spec authored by the agent, no generator exists) | `contract/openapi.yaml`, OpenAPI 3.1; `postman spec lint`: 0 errors, 0 warnings |
| 3 | "Generate a Postman collection from the spec" | `postman:api-documentation`, `postman:collection-schema-v3` | `postman spec generate collection` -> `postman/collections/Orders API/` (v3 YAML) |
| 4 | "Add tests to the collection" | `postman:api-testing` | `pm.test` contract assertions on all 5 requests via `postman collection request update --scripts`; `collection lint`: clean |
| 5 | "Create a mock server from the spec" | `postman:api-mocking` | `postman mock generate` -> `postman/mocks/orders-mock/` (local, port 4010) |
| 6 | "Run the collection against the mock, then against the real app" | `postman:api-testing`, `postman:api-mocking` | `collection run --mock`: 5/5 pass; against Spring Boot on :8080: 5/5 pass |

## Gaps / questions

- `postman init --visibility personal` could not create the workspace (`create_forbidden`), while `postman workspace create` succeeded. The workspace was therefore made by a direct CLI call, which the plan says to flag. Unclear whether the trailing "refused" message is a partial failure; worth checking in the Postman UI.
- Spec, API, collection and mock artifacts: not created yet.
- `postman init --no-cloud`, mentioned in the bootstrap skill, is not in `postman init -h` of CLI 1.73.0.
- Collections are in the Postman v3 format (a directory of YAML files), not `orders.postman_collection.json` as the plan's repo tree suggests. The mock is a local mock (`postman/mocks/orders-mock`), not yet pushed.
- Not pushed to the Postman cloud: the plugin's rule is not to `postman workspace push` without consent, so Postman is not yet the source of truth.
- Plain-language requests were not intercepted by a per-request hook: the hook is a `SessionStart` instruction, so routing is by the agent loading `api-engineer`.
- Maven is not installed system-wide; Maven 3.9.9 was downloaded to a temp folder to build. JDK on this machine is 25; the pom targets Java 21.
