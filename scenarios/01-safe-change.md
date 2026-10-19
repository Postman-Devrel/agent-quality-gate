# Scenario 1: safe change (rating A)

An optional `note` field is added to the `Order` response. Nothing a consumer relies on moves.

Branch: `demo/safe-change` (one commit on top of `main`).

## What the change does

| File | Change |
|------|--------|
| `contract/openapi.yaml` | adds `note` (string) to `Order`, **not** in `required` |
| `src/main/java/.../Order.java` | adds `String note`, omitted from JSON when null |
| `src/test/java/.../OrdersControllerTest.java` | a test that `note` is absent when empty |

## Reproduce

```bash
git switch demo/safe-change
GATE_BASE_REF=main ./gate/run-all.sh          # local run, same output as CI
git push -u origin demo/safe-change
gh pr create --base main --head demo/safe-change --title "Add an optional note to Order"
```

`MVN=/path/to/mvn` points the tests step to a Maven that is not on the `PATH`.
`GATE_BASE_REF` is the branch the contract diff is computed against.

## Expected report

Rating **A**, gate **PASSED**:

| Step | Status | Score |
|------|--------|------:|
| skills-check | not_available (see Known limits in the README) | – |
| contract-lint | pass | 100 |
| tests | pass: JUnit green, Postman 5/5 | 100 |
| ai-readiness | pass: 90/100 | 90 |
| impact | pass: additive change, 1 known consumer | 100 |

Composite score: 98/100.
