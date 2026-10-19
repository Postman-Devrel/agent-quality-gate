# Scenario 2: agent-authored breaking change (rating D)

A coding agent "cleans up" the API: it renames a response field and makes a request field mandatory.
It updates the Java code **and the unit tests**, so the build stays green.

Branch: `demo/agent-breaking-change` (one commit on top of `main`).

## What the "agent" changed

| File | Change |
|------|--------|
| `contract/openapi.yaml` | `Order.totalAmount` renamed to `total`; `couponCode` added to `CreateOrderRequest.required` |
| `src/main/java/.../Order.java` | record component `totalAmount` renamed to `total` |
| `src/main/java/.../OrderService.java` | `create` rejects a request without `couponCode` |
| `src/test/java/.../*Test.java` | updated to the new names, so JUnit passes |

## Reproduce

```bash
git switch demo/agent-breaking-change
GATE_BASE_REF=main ./gate/run-all.sh
git push -u origin demo/agent-breaking-change
gh pr create --base main --head demo/agent-breaking-change --title "Clean up the Order API"
```

## Expected report

Rating **D**, gate **FAILED** (exit code 1):

| Step | Status | Score |
|------|--------|------:|
| skills-check | not_available | – |
| contract-lint | pass | 100 |
| tests | **fail**: JUnit green, Postman 0/5 | 50 |
| ai-readiness | pass: 90/100 | 90 |
| impact | **fail**: breaking change, `patients-service` affected | 0 |

Composite score: 62/100. Blockers: a failing test, a breaking impact.

## Why the gate catches what the build misses

- **JUnit passes**: the agent edited the tests to match its own change.
- **Postman collection fails**: the collection is the consumers' expectation. The gate regenerates the mock from the *new* contract and replays the committed collection; `total` is not `totalAmount`.
- **Impact fails**: the contract diff removes a property and changes a `required` list, and the Context Graph lists a consumer of the API (`patients-service`, `GET /api/appointments/`).
- **Contract lint does not warn.** The plan expected a warning, but no built-in Postman governance rule flags a rename or a new required field: lint checks the shape of a contract, not its compatibility with the previous version. That gap is what steps 3 and 5 cover.
