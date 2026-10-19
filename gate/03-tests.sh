#!/usr/bin/env bash
# Step 3 - Tests & mocks (Sonar analogy: unit tests + coverage)
#   a) JUnit tests:  mvn test
#   b) Postman collection run against a mock generated from the CURRENT contract.
# The collection is the consumers' expectation: if the contract drifts, it fails.
STEP=tests
source "$(dirname "$0")/lib/common.sh"

MVN_BIN="${MVN:-mvn}"
CMD="postman collection run \"$COLLECTION\" --use-mock \"{{baseUrl}} mock:<generated mock>\""
need postman && need jq || { not_available "postman CLI or jq not installed" "$CMD"; exit 0; }

details="$(mktemp)"; echo '[]' > "$details"
add_detail() { jq --arg k "$1" --arg v "$2" '. + [{check:$k,result:$v}]' "$details" > "$details.n" && mv "$details.n" "$details"; }

# --- a) JUnit --------------------------------------------------------------
mkdir -p "$RESULTS_DIR"
junit_ok=0; junit_msg="mvn not available"
if need "$MVN_BIN"; then
  if "$MVN_BIN" -q -B test > "$RESULTS_DIR/mvn.log" 2>&1; then junit_ok=1; junit_msg="JUnit tests pass"
  else junit_msg="JUnit tests fail (see mvn log)"; fi
fi
add_detail junit "$junit_msg"

# --- b) Postman collection against a fresh mock ------------------------------
work="$(mktemp -d)"
postman mock generate "$CONTRACT" -n appointments-mock --port 4010 -o "$work/mock" --force >/dev/null 2>&1
postman collection run "$COLLECTION" --use-mock "{{baseUrl}} mock:$work/mock/config.yaml" \
  --output "$work/run" > "$work/run.log" 2>&1
summary_file="$(ls "$work"/run/*summary.yaml 2>/dev/null | head -1)"
if [ -z "$summary_file" ]; then
  not_available "collection run produced no report" "$CMD"; exit 0
fi
# The summary is plain YAML: read the counters we need with awk (no YAML dependency).
executed="$(awk '/^  tests:/{f=1} f&&/executed:/{print $2; exit}' "$summary_file")"
failed="$(awk '/^  tests:/{f=1} f&&/failed:/{print $2; exit}' "$summary_file")"
req_errors="$(awk '/^  executedRequests:/{f=1} f&&/errors:/{print $2; exit}' "$summary_file")"
executed="${executed:-0}"; failed="${failed:-0}"; req_errors="${req_errors:-0}"
add_detail postman-collection "$executed assertion(s), $failed failed, $req_errors request error(s)"
grep -E 'AssertionError' "$work/run.log" | sed -E 's/^ *[0-9]+\. +//; s/ +$//' | head -10 | while IFS= read -r line; do add_detail failure "$line"; done

# Score: half for JUnit, half for the share of passing Postman assertions.
if [ "$executed" -gt 0 ]; then pm_part=$(( 50 * (executed - failed) / executed )); else pm_part=0; fi
score=$(( 50 * junit_ok + pm_part ))
summary="JUnit: $junit_msg; Postman: $((executed - failed))/$executed assertions pass"

if [ "$junit_ok" -eq 1 ] && [ "$failed" -eq 0 ] && [ "$req_errors" -eq 0 ] && [ "$executed" -gt 0 ]; then
  emit pass "$score" "$summary" "$CMD" "$details"
else
  emit fail "$score" "$summary" "$CMD" "$details"
fi
exit 0
