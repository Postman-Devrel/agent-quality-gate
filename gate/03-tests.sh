#!/usr/bin/env bash
# Step 3 - Tests & mocks (Sonar analogy: unit tests + coverage)
#   a) JUnit tests:  ./mvnw test
#   b) Postman collection run against a mock generated from the CURRENT contract.
#      The collection is the consumers' expectation: if the contract drifts, it fails.
#   c) Contract coverage: every operation of the contract has a request in the collection.
STEP=tests
source "$(dirname "$0")/lib/common.sh"

MVN_BIN="${MVN:-./mvnw}"   # the Maven wrapper; MVN=/path/to/mvn overrides it
ROOT="$(pwd)"
CMD="postman collection run \"$COLLECTION\" --use-mock \"{{baseUrl}} mock:<generated mock>\" --no-report-events"
need postman && need jq || { not_available "postman CLI or jq not installed" "$CMD"; exit 0; }

details="$(mktemp)"; echo '[]' > "$details"
# add_detail <check> <result> [hint]: "hint" tells a coding agent how to fix the finding.
add_detail() {
  jq --arg k "$1" --arg v "$2" --arg h "${3:-}" '. + [{check:$k,result:$v} + (if $h == "" then {} else {hint:$h} end)]' \
    "$details" > "$details.n" && mv "$details.n" "$details"
}

# --- a) JUnit ----------------------------------------------------------------
mkdir -p "$RESULTS_DIR"
junit_ok=0; junit_msg="Maven not available"
if need "$MVN_BIN"; then
  if "$MVN_BIN" -q -B test > "$RESULTS_DIR/mvn.log" 2>&1; then junit_ok=1; junit_msg="JUnit tests pass"
  else junit_msg="JUnit tests fail"; fi
fi
if [ "$junit_ok" -eq 1 ]; then add_detail junit "$junit_msg"
else add_detail junit "$junit_msg" "Run ./mvnw test and fix the failing tests (see $RESULTS_DIR/mvn.log)."; fi

# --- b) Postman collection against a fresh mock -------------------------------
work="$(mktemp -d)"
postman mock generate "$CONTRACT" -n appointments-mock --port 4010 -o "$work/mock" --force >/dev/null 2>&1
postman collection run "$COLLECTION" --use-mock "{{baseUrl}} mock:$work/mock/config.yaml" \
  --no-report-events --output "$work/run" > "$work/run.log" 2>&1
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
grep -E 'AssertionError' "$work/run.log" | sed -E 's/^ *[0-9]+\. +//; s/ +$//' | head -10 | while IFS= read -r line; do
  add_detail failure "$line" "The contract and the collection disagree. Either the code or the contract changed a field consumers rely on (keep it, or version the change), or the collection must be updated on purpose."
done

# --- c) Contract coverage ------------------------------------------------------
# Generate a collection from the current contract (in a temp dir) and compare the
# "METHOD path" sets with the committed collection.
endpoints() {
  find "$1" -name '*.request.yaml' -not -path '*/.resources/*' | while read -r f; do
    m="$(grep -m1 '^method:' "$f" | awk '{print $2}')"
    u="$(grep -m1 '^url:' "$f" | sed -E "s/^url: *//; s/[\"']//g; s/\{\{baseUrl\}\}//; s/\?.*//; s/:[a-z_]+/{id}/g; s/\{[a-z_]+\}/{id}/g")"
    echo "$m $u"
  done | sort -u
}
( cd "$work" && git init -q && postman spec generate collection "$ROOT/$CONTRACT" -n gen --folder-strategy Tags >/dev/null 2>&1 )
endpoints "$work/postman/collections/gen" > "$work/expected.txt"
endpoints "$COLLECTION" > "$work/actual.txt"
total="$(wc -l < "$work/expected.txt" | tr -d ' ')"
missing_list="$(comm -23 "$work/expected.txt" "$work/actual.txt")"
missing="$(printf '%s' "$missing_list" | grep -c . || true)"
if [ "$total" -gt 0 ]; then coverage=$(( 100 * (total - missing) / total )); else coverage=100; fi
add_detail coverage "$((total - missing))/$total contract operations have a request in the collection ($coverage%)"
printf '%s\n' "$missing_list" | grep . | while IFS= read -r op; do
  add_detail uncovered "$op" "Add a request for '$op' to the Postman collection with pm.test assertions (postman collection request add/update), then re-run the gate."
done

# --- Score and verdict ---------------------------------------------------------
# 40 points JUnit, 40 points Postman assertions, 20 points contract coverage.
if [ "$executed" -gt 0 ]; then pm_part=$(( 40 * (executed - failed) / executed )); else pm_part=0; fi
score=$(( 40 * junit_ok + pm_part + 20 * coverage / 100 ))
summary="JUnit: $junit_msg; Postman: $((executed - failed))/$executed assertions pass; coverage $coverage%"

if [ "$junit_ok" -ne 1 ] || [ "$failed" -gt 0 ] || [ "$req_errors" -gt 0 ] || [ "$executed" -eq 0 ]; then
  emit fail "$score" "$summary" "$CMD" "$details"
elif [ "$coverage" -lt 100 ]; then
  emit warn "$score" "$summary" "$CMD" "$details"
else
  emit pass "$score" "$summary" "$CMD" "$details"
fi
exit 0
