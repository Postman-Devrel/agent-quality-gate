# Scenario 1: safe change (rating A)

An optional, documented `reason` field is added to the `Appointment` response. Nothing a consumer relies on moves.

Branch: `demo/safe-change` (one commit on top of `main`).

## What the change does

| File | Change |
|------|--------|
| `contract/openapi.yaml` | adds `reason` (string) to `Appointment`, **not** in `required` |
| `src/main/java/.../AppointmentStore.java` | trims `reason` on create |
| `src/test/java/.../AppointmentsControllerTest.java` | `reason` is optional and trimmed |

## Reproduce

```bash
git switch demo/safe-change
GATE_BASE_REF=main ./gate/run-all.sh          # local run, same output as CI
git push -u origin demo/safe-change
gh pr create --base main --head demo/safe-change --title "Add an optional reason to Appointment"
```

`MVN=/path/to/mvn` points the tests step to a Maven that is not on the `PATH`.
`GATE_BASE_REF` is the branch the contract diff is computed against.

## Expected report

Rating **A** (93/100), gate **PASSED**:

| Step | Status | Score |
|------|--------|------:|
| skills-check | not_available (see Known limits in the README) | – |
| contract-lint | pass | 100 |
| tests | pass: JUnit green, Postman 10/10 | 100 |
| ai-readiness | warn: 70/100 | 70 |
| impact | pass: additive change, 1 known consumer (`patients-service`) | 100 |
