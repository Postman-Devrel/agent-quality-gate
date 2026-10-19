#!/usr/bin/env bash
# Step 2 - Contract lint (Sonar analogy: linter / code smells)
# Lints the OpenAPI contract with Postman governance rules.
STEP=contract-lint
source "$(dirname "$0")/lib/common.sh"

CMD="postman spec lint $CONTRACT -o json --no-report-events"
need postman && need jq || { not_available "postman CLI or jq not installed" "$CMD"; exit 0; }

out="$(mktemp)"; details="$(mktemp)"
# The exit code is ignored: the severity counts below drive the result.
$CMD > "$out" 2>/dev/null
if ! jq -e '.violations' "$out" >/dev/null 2>&1; then
  not_available "lint produced no JSON output" "$CMD"; exit 0
fi

jq '.violations' "$out" > "$details"
errors="$(jq '[.[] | select((.severity|tostring|ascii_downcase) == "error" or .severity == 0)] | length' "$details")"
warnings="$(jq '[.[] | select((.severity|tostring|ascii_downcase) == "warning" or .severity == 1)] | length' "$details")"
other="$(jq 'length' "$details")"; other=$((other - errors - warnings))

# Score: each error costs 40 points, each warning 10, anything else 2.
score=$((100 - 40*errors - 10*warnings - 2*other)); [ "$score" -lt 0 ] && score=0
summary="$errors error(s), $warnings warning(s), $other other"

if   [ "$errors" -gt 0 ];   then emit fail "$score" "$summary" "$CMD" "$details"
elif [ "$warnings" -gt 0 ]; then emit warn "$score" "$summary" "$CMD" "$details"
else                             emit pass 100 "No lint issue" "$CMD" "$details"
fi
exit 0
