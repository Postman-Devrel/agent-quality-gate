# Architecture

## Two layers, two tools

| Layer | Who runs it | Postman access |
|-------|-------------|----------------|
| Authoring | the coding agent, in Claude Code | the **Postman plugin**: a hook routes requests to `api-engineer`, which delegates to skills (bootstrap, documentation, testing, mocking) |
| Gate | GitHub Actions, no agent | the [Postman agent quality gate](https://github.com/Postman-Devrel/postman-agent-quality-gate), a reusable workflow at `@v1` |

The gate lives outside the agent on purpose: an agent that can edit the code and the tests can also edit anything running next to it, but not a required CI check.

## Data flow

The gate reads the spec and the collection from `.postman/resources.yaml`, runs its steps with the Postman CLI, and writes a report (job summary, pull request comment, `gate-results/`). Its architecture, step result contract and decisions are documented in the product: see its `docs/architecture.md`. This repo only holds:

- `quality-gate.yml`: the configuration (`impact.api: appointments-service`, pass rating, blockers);
- `.github/workflows/quality-gate.yml`: the caller of the reusable workflow;
- `.github/workflows/tests.yml`: the JUnit tests, which the gate does not run.

## Why contract tests catch what JUnit misses

The gate generates a fresh mock from the **current** `postman/specs/appointments-api/index.yaml`, then replays the **committed** collection against it. The collection holds what consumers expect; the contract holds what the code now promises. If they diverge, assertions fail even when the agent updated every unit test. Whether the code matches the contract is not covered by the gate: JUnit does that.

## Decisions

- Actions are pinned by commit SHA; the gate workflow is pinned by the major tag `v1`.
- Workspace, spec, collection and mock are synced to a Postman workspace in the devrel team (`postman workspace push`); the repo files remain the source for the gate.
