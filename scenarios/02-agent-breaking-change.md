# Scenario 2: agent-authored breaking change (gate fails)

A coding agent "cleans up" the API: it renames a response field and makes a request field mandatory.
It updates the Java code **and the unit tests**, so the build stays green.

Branch: `demo/agent-breaking-change` (one commit on top of `main`).

## What the "agent" changed

| File | Change |
|------|--------|
| `contract/openapi.yaml` | list response: `count` renamed to `total`; `patient_id` added to `AppointmentCreateRequest.required` |
| `src/main/java/.../AppointmentsController.java` | returns `total`; `POST` answers 400 without `patient_id` |
| `src/test/java/.../AppointmentsControllerTest.java` | updated to `$.total`, so JUnit passes |

## Reproduce

```bash
git switch demo/agent-breaking-change
GATE_BASE_REF=main ./gate/run-all.sh
git push -u origin demo/agent-breaking-change
gh pr create --base main --head demo/agent-breaking-change --title "Clean up the appointments API"
```

## Expected report

Rating **C** (70/100), gate **FAILED** (exit code 1) because of two hard blockers:

| Step | Status | Score |
|------|--------|------:|
| skills-check | not_available | – |
| contract-lint | pass | 100 |
| tests | **fail**: JUnit green, Postman 9/10 (`200 and a page of appointments`) | 95 |
| ai-readiness | warn: 70/100 | 70 |
| impact | **fail**: breaking change, `patients-service` affected | 0 |

Blockers: a failing test, a breaking impact. The score alone is a C: the blockers are what stop the merge, whatever the average says.

## Why the gate catches what the build misses

- **JUnit passes**: the agent edited the tests to match its own change.
- **Postman collection fails**: the collection is the consumers' expectation. The gate regenerates the mock from the *new* contract and replays the committed collection; the list response has no `count` any more.
- **Impact fails**: the contract diff removes a property and adds a `required` list, and the Context Graph lists a real consumer of this API (`patients-service`, `GET /api/appointments/`).
- **Contract lint does not warn.** No built-in governance rule flags a rename or a new required field: lint checks the shape of a contract, not its compatibility with the previous version. Steps 3 and 5 cover that gap.
