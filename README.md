# agent-quality-gate

An API-first Java service with a quality gate built for coding agents.

The contract (`postman/specs/appointments-api/index.yaml`) is the source of truth. The service is a Spring Boot implementation of the `appointments-service` contract from [`healthcare-org-app/healthcare-appointments`](https://github.com/healthcare-org-app/healthcare-appointments). The Postman objects (collection, mock, spec) live in the repo and in a Postman workspace. A quality gate runs in CI on every push and decides whether a change is good enough to merge: for a human reviewer and for the coding agents that work on the API.

## Why a gate for the contract

A code quality tool analyzes code. Nothing in that stack looks at the API *contract*, or at who depends on it. A coding agent can rename a response field, update the unit tests to match, keep the build green, and still break every consumer. The gate checks the contract, the consumers' expectations, and the dependents, and it runs outside the agent: the agent cannot skip it.

## Layout

| Path | Content |
|------|---------|
| `postman/specs/appointments-api/index.yaml` | OpenAPI 3.1 contract |
| `src/` | Spring Boot 3 / Java 21 service (in-memory store) |
| `postman/` | v3 collection with `pm.test` assertions, local mock, spec link; synced to a Postman workspace |
| `gate/` | the five gate steps, `aggregate.js`, `run-all.sh`, `lib/` helpers |
| `quality-gate.yml` | weights, rating scale, blockers |
| `.github/workflows/quality-gate.yml` | the CI pipeline |
| `mods/` | the Claude Code mod that displays the gate |
| `.claude/agents/` | `api-coder` (implements and fixes) and `gate-reviewer` (reads the gate result, writes a fixes brief) |
| `docs/` | CLI inventory, architecture |

## Run the service

Needs Java 21 or newer. The Maven wrapper downloads Maven.

```bash
./mvnw spring-boot:run                 # http://localhost:8080
./mvnw test                            # JUnit
./scripts/check-api.sh                 # build, start the API, run the Postman collection against it, stop
```

The service implements the documented endpoints (`/api/appointments`, `/{record_id}`, `/cancel`, `/check-in`, `/health`, `/ready`) with seeded data. Not implemented: authentication and the side effects the contract documents for the original service (Kafka and audit events, peer enrichment on create).

## The quality gate

Five steps. Each runs one Postman CLI command (plus minimal glue) and writes `gate-results/<step>.json`; none fails the job by itself, `aggregate.js` decides.

| # | Step | Command | What it checks |
|---|------|---------|----------------|
| 1 | `skills-check` | `postman skills status --json` | the Postman skills committed in the repo are current (`not_available` today because of a CLI bug, see below) |
| 2 | `contract-lint` | `postman spec lint postman/specs/appointments-api/index.yaml -o json` | the contract against Postman governance rules |
| 3 | `tests` | `./mvnw test`, `postman collection run … --use-mock …` | JUnit; the collection replayed against a mock **generated from the current contract**; every contract operation has a request in the collection |
| 4 | `ai-readiness` | `postman spec ai-readiness postman/specs/appointments-api/index.yaml -o json` | how well an agent can discover, understand and call the API |
| 5 | `impact` | `postman context-graph ask …` + contract diff | who consumes the API in the Context Graph, and whether the change breaks them |

Details, flags and output formats: [docs/cli-inventory.md](docs/cli-inventory.md).

### Scoring

Configured in [`quality-gate.yml`](quality-gate.yml).

- **Composite score**: weighted average. Weights: skills 10, lint 25, tests 25, AI readiness 20, impact 20.
- **Rating**: A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 50, E < 50. The gate passes at **B or better**.
- **Hard blockers**, whatever the score: a lint error, a failing test, a breaking change with a known consumer.
- **`not_available` steps** are left out of the average (the other weights are re-normalized) and shown in grey. They are never counted as a pass.

### The report

`gate/aggregate.js` writes `gate-results/report.md` and `report.json`. The report has the score, the rating, a table per step with its exact command, the blockers, and a **What to fix** section: one finding per line with a fix hint. `report.json` carries the same findings in a `feedback` array, so an agent can consume it directly.

### Run it locally

Needs Java 21+, Node, `jq`, Python 3 with PyYAML (optional) and the Postman CLI 1.73.0, logged in (`postman login --with-api-key "$POSTMAN_API_KEY"`).

```bash
./gate/run-all.sh                  # all five steps and the report
./gate/02-contract-lint.sh         # one step; same JSON as in CI
GATE_BASE_REF=origin/main ./gate/05-impact.sh   # branch the contract diff is computed against
```

`MVN=/path/to/mvn` replaces the Maven wrapper.

## CI

`.github/workflows/quality-gate.yml`: `build`, then the five gate steps in parallel (a matrix), then `quality-gate`, which aggregates, writes the job summary, posts or updates one comment on the branch's pull request, uploads the `gate-report` artifact and fails when the gate fails. It runs on every push, on pull requests and on manual dispatch, but only does the work when the branch changes something the gate judges (`contract/`, `src/`, `postman/`, `.postman/`, `gate/`, the Maven files, `quality-gate.yml` or the workflow itself); for docs, the mod or the agents' files the `quality-gate` job succeeds at once and says the gate was skipped, so it stays usable as a required check. Make the `quality-gate` job a required check to block merges.

Secrets and variables:

| Name | Kind | Used by |
|------|------|---------|
| `POSTMAN_API_KEY` | secret | login, and the cloud-backed steps. Use the key of the Postman team whose Context Graph holds the API, otherwise `impact` is `not_available` |
| `IMPACT_API` | variable, optional | the API name in the Context Graph (default `appointments-service`) |

The workspace, API and mock identifiers are not needed in CI: the contract and the collection are local files and the mock is generated on the runner. The workspace binding is recorded in `.postman/resources.yaml`.

## Agents

Two agents work on this repo (`.claude/agents/`), each with a narrow role:

- **`api-coder`** changes the API contract first, then the Java code, the tests and the Postman collection (through the Postman plugin), runs the gate locally, pushes a branch and applies the fixes it is given. It may not edit `gate/`, `quality-gate.yml`, `.github/` or `.claude/`.
- **`gate-reviewer`** is read-only. It finds the CI run for the exact commit that was pushed, reads the gate report and writes a prioritised fixes brief for the coder.

The Postman plugin handles everything Postman for the agents (`npx @postman/postman-plugin install`); CI has no agent, so the gate scripts call the Postman CLI directly.

## Claude Code mod

`mods/quality-gate-panel` is a Claude Code mod that shows the gate in the session: a band above the prompt, a status line entry, a `/gate` pane and toasts when the CI run changes. See [its README](mods/quality-gate-panel/README.md).

## Known limits

- **`skills-check` is `not_available`.** In Postman CLI 1.73.0 and 1.75.0, `postman skills status` answers `foreign` as soon as `postman/skills` holds a `.py` file, and the skills ship two of them (`performance-testing/.../scripts/*.py`). Reported to the Postman CLI team; the step stays `not_available` (excluded from the score, shown in grey) until it is fixed. A workaround exists on the branch `fix/skills-check-py-workaround`. The step checks the skills committed in the repo, not the version of the agent plugin.
- **Impact depends on an LLM.** `context-graph ask` returns free text. The step asks for JSON only and retries an empty answer up to 3 times, but it can still miss a consumer. "Breaking" comes from a structural diff of the contract against the base branch (removed or renamed path, response or property, changed type, stricter request); it does not see behaviour the contract does not describe.
- **The Context Graph must know the API.** The graph of the team behind `POSTMAN_API_KEY` must hold `appointments-service`.
- **Contract lint does not detect breaking changes.** No built-in governance rule flags a rename or a new required field. Steps 3 and 5 cover that.
- **Collection tests are state-dependent**: they assume the seeded appointment `2317` of a fresh start.
- **The collection `baseUrl` is `http://localhost:8080`.** The spec lists a production server first; the generated collection must never point at it. The gate redirects `baseUrl` to a generated mock.
- **Postman v3 format**: the collection is a folder of YAML files.
