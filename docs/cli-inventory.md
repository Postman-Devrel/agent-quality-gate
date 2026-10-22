# Postman CLI inventory (CI gate)

Every command below was run with `-h` and executed against this repo on **Postman CLI 1.73.0** (npm latest: 1.75.0).
Nothing here is guessed. "Verified" means the command was executed; "Docs" cross-check against learning.postman.com is still to do (see Open points).

| # | Gate step | Command | Exists today | Output | Exit code |
|---|-----------|---------|--------------|--------|-----------|
| 1 | Skills check | `postman skills status --json [--strict]` | Yes (verified) | JSON: `state` = `current` / `behind` / `modified` / `unknown`, plus a per-file list and `orphans` | 0 = check done, 1 = origin unreachable, 3 = not current **and** `--strict` |
| 2 | Contract lint | `postman spec lint postman/specs/appointments-api/index.yaml -o json -f warning --no-report-events` | Yes (verified) | JSON `{ "violations": [ ... ] }`; table by default | non-zero when a violation reaches `--fail-severity` (default `ERROR`) |
| 3a | Tests: contract run | `postman collection run "postman/collections/Appointments API" --use-mock "{{baseUrl}} mock:postman/mocks/orders-mock" --output <dir>` | Yes (verified) | YAML run report: `*.collection-run-summary.yaml` + `*.collection-run-executions.yaml` | non-zero when an assertion fails (`-x` suppresses it) |
| 3b | Tests: JUnit | `mvn test` (not a Postman command) | n/a | Surefire XML in `target/surefire-reports` | non-zero on failure |
| 4 | AI readiness | `postman spec ai-readiness postman/specs/appointments-api/index.yaml -o json [--min-score N]` | Yes (verified) | JSON with `readiness.score_0_100`, `readiness.bucket`, `signals`, `recommendations`, `docCoverage` | non-zero when score < `--min-score` |
| 4b | AI readiness (collection) | `postman collection ai-readiness "postman/collections/Appointments API" -o json` | Yes (verified) | Same shape, `sourceType: collection` | same |
| 5 | Impact | `postman context-graph ask "<question>" --wait --json` | Yes, free text only (verified, see below) | JSON ask record: `status`, `result.answer`, `result.citations[]` | 0 on completion |

## Findings per step

### 1. Skills check — works, but it does not check what the plan assumed
`postman skills status` compares the skills **committed in `postman/skills/`** against the published ones. It does **not** check the Claude Code plugin version.
The plugin is updated with `claude plugin update postman` (named in the CLI help), which cannot run in CI.
- Gate design: score the repo skills with `skills status` (verified); report the plugin version as informational only.
- **CLI bug, root cause found:** on a pristine `git init && postman init` repo (CLI 1.73.0 and 1.75.0), `postman skills status` answers `foreign` (exit 1) and `postman skills update` refuses with exit 4. The cause is the two `.py` files that ship with the skills (`performance-testing/references/jmeter-import/scripts/`): the CLI counts them as "source files". Deleting them gives `behind`; `skills update` brings them back and breaks it again.
- Gate design: `01-skills-check.sh` runs `postman skills status --json`: `current` is a pass, `behind`, `modified` and `unknown` are warnings, anything else (including `foreign`) is `not_available`. **Today it reports `not_available` in this repo.** Waiting for feedback from the Postman CLI team. A workaround (check a temporary copy of the skills without the `.py` files) is kept on the branch `fix/skills-check-py-workaround` and is not used.
- `postman skills update` exits 4 when a skill file was edited locally (needs `--force`).

### 2. Contract lint — works
- Reads local files, JSON output with `-o json`. Clean contract gives `{"violations": []}`.
- Governance rules: by default the built-in ruleset (e.g. "Operation should return a 5xx HTTP status code"). Team rulesets are fetched with `--workspace-id`.
- `-f warning` makes warnings fail the command; the gate script ignores the exit code anyway and reads the violations.
- Needs no login for local files. `--no-report-events` stops it from sending events to the API Catalog.

### 3. Tests & mocks — works
- `--use-mock "{{baseUrl}} mock:<path>"` starts the local mock and redirects `{{baseUrl}}` to it. Verified: 5 requests, 5 assertions, 0 failed.
- Machine-readable result: `--output <folder>` writes a YAML summary. JUnit/JSON reporters (`-r`) are mentioned in the plugin skill but are **not listed** in `collection run -h` of 1.73.0: unconfirmed, not used.
- Cloud mock URL variant (`mock-server:<id>`) exists in `-h`; not needed, the local mock avoids a secret and a network dependency.
- The collection also runs against the real app (`baseUrl` = `http://localhost:8080`), 5/5 pass.

### 4. AI readiness — works
- Current contract: **90 / 100, bucket "Excellent"**, confidence high. Top-level keys: `source, sourceType, complexity, readiness, confidence, docCoverage, signals, recommendations, stats`.
- `--min-score` gives a pass/fail exit code, but the gate wants the raw number, so the script reads `readiness.score_0_100`.

### 5. Impact (Context Graph) — works through a JSON-only prompt, with caveats
- `postman context-graph ask` is answered by an LLM service: free text plus citations; `provenance` only echoes the typed query, not its result. There is no structured consumer list and no breaking flag.
- The team is derived from the API key. With the key of the team that ingested `healthcare-org-app/healthcare-appointments`, the question "Which services consume or depend on appointments-service?" returns `patients-service` (`GET /api/appointments/`, confidence 0.9).
- The gate asks for a **JSON-only** answer (`[{name, endpoint, protocol, confidence}]`). It came back as `[]` once in four runs, so `05-impact.sh` retries empty answers up to 3 times.
- "Breaking" does **not** come from the Context Graph: `gate/lib/contract-diff.py` compares the contract with the base branch structurally (removed or renamed path, response or property, changed type, a request that became stricter). Additions, including a new schema with its own `required` list, are not breaking. Without PyYAML it falls back to a line heuristic. Breaking plus at least one consumer is a hard blocker.
- The API of this repo is the Java implementation of the `appointments-service` contract, so the consumers found are the real ones (name set with `IMPACT_API`).
- Needs the `POSTMAN_API_KEY` of the team holding the ingestion; without it the step is `not_available`.

## Commands the plan guessed that do not exist
| Guess | Reality |
|-------|---------|
| "skills version check" | `postman skills status` exists, but for repo skills only, not for the agent plugin |
| `postman ... --score` for AI readiness | `spec/collection ai-readiness -o json` |
| "Context Graph query" returning impacted consumers | only free-text `context-graph ask` |
| `postman init --no-cloud` (bootstrap skill) | absent from `postman init -h` in 1.73.0 |

## Open points
1. Cross-check with learning.postman.com is not done (no web fetch yet); everything above comes from `-h` and live runs.
2. CLI 1.73.0 is older than the latest 1.75.0. The workflow will pin one version; I propose 1.75.0 after re-running this inventory on it.
3. Step 5 decision: ingest this repo and workspace into the Context Graph (writes to the team graph), or ship step 5 as `not_available` with the real command documented.
