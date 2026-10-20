#!/usr/bin/env bash
# Step 5 - Impact (no Sonar equivalent: this is the point)
# Who depends on this API? The Postman Context Graph knows, Sonar does not.
#
# 1. Ask the Context Graph for the consumers of the API (IMPACT_API).
# 2. Check whether this change touches the contract and whether it looks breaking.
# 3. A breaking change with known consumers is a hard blocker ("breaking": true).
#
# Limits (see docs/cli-inventory.md): `context-graph ask` answers in free text, so the
# prompt forces a JSON-only answer, and "breaking" is a heuristic on the contract diff.
STEP=impact
source "$(dirname "$0")/lib/common.sh"

# The API as registered in the Context Graph (this team ingested healthcare-appointments).
IMPACT_API="${IMPACT_API:-appointments-service}"
BASE_REF="${GATE_BASE_REF:-origin/main}"
QUESTION="List the services that consume $IMPACT_API through the Context Graph. Reply with ONLY a JSON array, no prose, no code fence. Each item: {\"name\": string, \"endpoint\": string, \"protocol\": string, \"confidence\": number between 0 and 1}. Reply [] if there is none."
CMD="postman context-graph ask \"<list the consumers of $IMPACT_API as JSON>\" --wait --json"
need postman && need jq || { not_available "postman CLI or jq not installed" "$CMD"; exit 0; }

# --- 1. Consumers from the Context Graph ------------------------------------------
# The answer comes from an LLM, so an empty list is retried (up to 3 asks): a missing
# consumer would otherwise silently turn a breaking change into a pass.
raw="$(mktemp)"; answer=""
for attempt in 1 2 3; do
  postman context-graph ask "$QUESTION" --wait --json --timeout 120 > "$raw" 2>/dev/null
  answer="$(jq -r '.result.answer // empty' "$raw" 2>/dev/null | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//')"
  echo "$answer" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1 && break
  log "attempt $attempt: no consumer returned"
done
if ! echo "$answer" | jq -e 'type == "array"' >/dev/null 2>&1; then
  not_available "Context Graph gave no usable answer (not logged in, or API not ingested)" "$CMD"; exit 0
fi
consumers="$(echo "$answer" | jq -c '.')"
count="$(echo "$consumers" | jq 'length')"

# --- 2. Does this change touch the contract, and does it look breaking? -------------
# Heuristic on the diff of contract/openapi.yaml against the base branch:
#   removed/renamed property or path, or a changed "required:" list = breaking.
base="$BASE_REF"; git rev-parse --verify -q "$base" >/dev/null || base="HEAD"
diff_out="$(git diff "$base" -- "$CONTRACT" 2>/dev/null)"
changed=false; breaking=false
if [ -n "$diff_out" ]; then
  changed=true
  echo "$diff_out" | grep -E '^-[^-]' | grep -E '^-\s+(/[^:]*|[A-Za-z_][A-Za-z0-9_]*):\s*$|^-\s+required:' >/dev/null && breaking=true
  echo "$diff_out" | grep -E '^\+\s+required:' >/dev/null && breaking=true
fi

# --- 3. Verdict ---------------------------------------------------------------------
details="$(mktemp)"
echo "$consumers" | jq --argjson breaking "$([ "$breaking" = true ] && [ "$count" -gt 0 ] && echo true || echo false)" \
  'map(. + {api: "'"$IMPACT_API"'", breaking: $breaking, check: "consumer", result: (.name + " calls " + (.endpoint // "?")),
    hint: (if $breaking then "This change breaks " + .name + ". Keep the removed or renamed field/path (add the new one next to it) and do not make request fields required, or version the API." else "Known consumer, no action." end)})' > "$details"

if   [ "$breaking" = true ] && [ "$count" -gt 0 ]; then
  emit fail 0 "Breaking contract change: $count consumer(s) of $IMPACT_API affected ($(echo "$consumers" | jq -r 'map(.name)|join(", ")'))" "$CMD" "$details"
elif [ "$breaking" = true ]; then
  emit warn 60 "Breaking contract change, but the Context Graph knows no consumer of $IMPACT_API" "$CMD" "$details"
elif [ "$changed" = true ]; then
  emit pass 100 "Additive contract change; $count known consumer(s) of $IMPACT_API" "$CMD" "$details"
else
  emit pass 100 "Contract unchanged; $count known consumer(s) of $IMPACT_API" "$CMD" "$details"
fi
exit 0
