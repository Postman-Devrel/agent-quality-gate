#!/usr/bin/env bash
# Step 4 - AI readiness (Sonar analogy: maintainability rating)
# How well can an agent discover, understand and call this API?
STEP=ai-readiness
source "$(dirname "$0")/lib/common.sh"

CMD="postman spec ai-readiness $CONTRACT -o json"
need postman && need jq || { not_available "postman CLI or jq not installed" "$CMD"; exit 0; }

out="$(mktemp)"; details="$(mktemp)"
$CMD > "$out" 2>/dev/null
score="$(jq -r '.readiness.score_0_100 // empty' "$out" 2>/dev/null)"
[ -n "$score" ] || { not_available "ai-readiness returned no score" "$CMD"; exit 0; }

jq '[(.recommendations // [])[]]' "$out" > "$details" 2>/dev/null
bucket="$(jq -r '.readiness.bucket' "$out")"
summary="AI readiness $score/100 ($bucket)"

# Thresholds: >= 80 pass, 60-79 warn, < 60 fail.
if   [ "$score" -ge 80 ]; then emit pass "$score" "$summary" "$CMD" "$details"
elif [ "$score" -ge 60 ]; then emit warn "$score" "$summary" "$CMD" "$details"
else                           emit fail "$score" "$summary" "$CMD" "$details"
fi
exit 0
