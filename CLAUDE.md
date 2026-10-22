> **DEPRECATED: do not work in this repository.** It is archived/read-only. It was a Java copy of the `appointments-service` contract. The gate is now the product https://github.com/Postman-Devrel/postman-agent-quality-gate and the reference consumer is the real service https://github.com/healthcare-org-app/healthcare-appointments. Make changes there, not here, and do not run the change loop below.

# Working on this repo

Contract-first Java API (`postman/specs/appointments-api/index.yaml`, Spring Boot in `src/`, Postman collection in `postman/`). Two CI checks: `tests` (this project's JUnit) and `quality-gate`, the [Postman agent quality gate](https://github.com/Postman-Devrel/postman-agent-quality-gate) (config `quality-gate.yml`, caller `.github/workflows/quality-gate.yml`). For Postman work, follow `AGENTS.md`.

The gate comes from the `postman-agent-quality-gate` Claude Code plugin (enabled in `.claude/settings.json`): the `gate-loop` skill and the `gate-verdict` agent.

## The loop for any change to the contract, the code or the Postman objects

Follow the `gate-loop` skill. The same path every time, on a pull request or not, so the behaviour is predictable.

1. **Branch.** Work on a branch, never on `main`. Use the **api-coder** agent (this project's coder) for the change: contract first, then code, tests and the Postman collection, the local check (`npx github:Postman-Devrel/postman-agent-quality-gate#v1 run`), then push. It reports the branch and the full commit SHA.
2. **Verdict.** After every push, and on every CI event about the gate (a failing `quality-gate` check, whether it comes from the app's Auto-fix or not), launch the **gate-verdict** agent with the branch and that exact SHA. It waits for the run, reads the gate report and returns a verdict and a fixes brief. Do not read the CI output yourself and do not fix from the raw event.
3. **Fix.** If the verdict is FAILED, give the brief word for word to the **same** api-coder agent (SendMessage), which applies it and pushes to the **same branch**. Then go back to step 2 with the new SHA.
4. **Stop** after 3 rounds, or when the verdict is PASSED, and report: rounds played, rating per round, what changed between rounds, the branch or PR link.

## Rules

- Never merge, force-push or push to `main` unless the user asks for it.
- Never edit `quality-gate.yml`, `.github/` or `.claude/` to get a better verdict: the gate lives outside the agents on purpose. If the gate itself looks wrong, say so and stop.
- Never rename or remove a field, path or response that consumers use, and never make an existing request field required: add next to it, or version the API.
- Never run requests against a real server (`https://myhealthcare.dev` is production). The collection's `baseUrl` stays `http://localhost:8080`.
- A `not_available` or degraded step is a gap, not a pass: say so in the report.
- The gate does not run the Java tests: `./mvnw test` (and the `tests` workflow) do.
