# Working on this repo

Contract-first Java API (`postman/specs/appointments-api/index.yaml`, Spring Boot in `src/`, Postman collection in `postman/`) with a quality gate in CI (`gate/`, `.github/workflows/quality-gate.yml`). For Postman work, follow `AGENTS.md`.

## The loop for any change to the contract, the code or the Postman objects

The same path every time, on a pull request or not, so the behaviour is predictable.

1. **Branch.** Work on a branch, never on `main`. Use the **api-coder** agent for the change: contract first, then code, tests and the Postman collection, the local gate (`./gate/run-all.sh`), then push. It reports the branch and the full commit SHA.
2. **Review.** After every push, and on every CI event about the gate (a failing `quality-gate` check, whether it comes from the app's Auto-fix or not), launch the **gate-reviewer** agent with the branch and that exact SHA. It waits for the run, reads the gate report and returns a verdict and a fixes brief. Do not read the CI output yourself and do not fix from the raw event.
3. **Fix.** If the verdict is FAILED, give the brief word for word to the **same** api-coder agent (SendMessage), which applies it and pushes to the **same branch**. Then go back to step 2 with the new SHA.
4. **Stop** after 3 rounds, or when the verdict is PASSED, and report: rounds played, rating per round, what changed between rounds, the branch or PR link.

## Rules

- Never merge, force-push or push to `main` unless the user asks for it.
- Never edit `gate/`, `quality-gate.yml`, `.github/` or `.claude/` to get a better verdict: the gate lives outside the agents on purpose. If the gate itself looks wrong, say so and stop.
- Never rename or remove a field, path or response that consumers use, and never make an existing request field required: add next to it, or version the API.
- Never run requests against a real server (`https://myhealthcare.dev` is production). The collection's `baseUrl` stays `http://localhost:8080`.
- A `not_available` step is a gap, not a pass: say so in the report.
