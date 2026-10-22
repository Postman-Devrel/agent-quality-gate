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
| `quality-gate.yml` | config of the quality gate (API name in the Context Graph, pass rating, blockers) |
| `.github/workflows/quality-gate.yml` | calls the reusable workflow of the [Postman agent quality gate](https://github.com/Postman-Devrel/postman-agent-quality-gate) |
| `.github/workflows/tests.yml` | the project's own JUnit tests |
| `.claude/` | `api-coder` (implements and fixes) and the plugin settings that bring the gate loop |
| `docs/` | architecture |

## Run the service

Needs Java 21 or newer. The Maven wrapper downloads Maven.

```bash
./mvnw spring-boot:run                 # http://localhost:8080
./mvnw test                            # JUnit
./scripts/check-api.sh                 # build, start the API, run the Postman collection against it, stop
```

The service implements the documented endpoints (`/api/appointments`, `/{record_id}`, `/cancel`, `/check-in`, `/health`, `/ready`) with seeded data. Not implemented: authentication and the side effects the contract documents for the original service (Kafka and audit events, peer enrichment on create).

## The quality gate

The gate is a separate product: [Postman-Devrel/postman-agent-quality-gate](https://github.com/Postman-Devrel/postman-agent-quality-gate), consumed here at tag `v1`. It reads the spec and the collection from `.postman/resources.yaml` and runs six steps (`skills-check`, `contract-lint`, `contract-tests`, `coverage`, `ai-readiness`, `impact`). It does not run the Java tests: the `tests` workflow does (`./mvnw test`). Scoring, report format and steps are documented in the product's README and docs.

This repo's configuration is [`quality-gate.yml`](quality-gate.yml): `impact.api: appointments-service`, pass at B, blockers on a lint failure, failing contract tests and a breaking change with a known consumer.

### Run it locally

Needs the Postman CLI (1.76.0), logged in (`postman login --with-api-key "$POSTMAN_API_KEY"`).

```bash
npx github:Postman-Devrel/postman-agent-quality-gate#v1 run             # all steps and the report in gate-results/
npx github:Postman-Devrel/postman-agent-quality-gate#v1 run contract-lint   # one step
```

## CI

- `.github/workflows/quality-gate.yml` calls the product's reusable workflow (`gate.yml@v1`) on every push, pull request and manual dispatch. It posts one comment on the pull request and the check is named `gate / quality-gate`; make it required to block merges.
- `.github/workflows/tests.yml` runs `./mvnw -B test` on Java 21.

| Name | Kind | Used by |
|------|------|---------|
| `POSTMAN_API_KEY` | secret | login, and the cloud-backed steps. Use the key of the Postman team whose Context Graph holds the API, otherwise `impact` is `not_available` |

The API name in the Context Graph is set in `quality-gate.yml` (`impact.api`).

## Agents

- **`api-coder`** (`.claude/agents/`) changes the API contract first, then the Java code, the tests and the Postman collection (through the Postman plugin), runs the gate locally, pushes a branch and applies the fixes it is given. It may not edit `quality-gate.yml`, `.github/` or `.claude/`.
- The `postman-agent-quality-gate` Claude Code plugin (enabled in `.claude/settings.json`) brings the `gate-loop` skill, the read-only `gate-verdict` agent (finds the CI run for the pushed commit and writes a fixes brief) and a live gate pane. See [CLAUDE.md](CLAUDE.md) for the loop.

The Postman plugin handles everything Postman for the agents (`npx @postman/postman-plugin install`); CI has no agent.

## Known limits

- **Impact depends on an LLM.** `context-graph ask` returns free text, so the step can miss a consumer. See the product docs.
- **The Context Graph must know the API.** The graph of the team behind `POSTMAN_API_KEY` must hold `appointments-service`.
- **Collection tests are state-dependent**: they assume the seeded appointment `2317` of a fresh start.
- **The collection `baseUrl` is `http://localhost:8080`.** The spec lists a production server first; the generated collection must never point at it. The gate runs the collection against a generated mock.
- **Postman v3 format**: the collection is a folder of YAML files.
