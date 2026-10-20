#!/usr/bin/env bash
# Step 1 - Skills check (Sonar analogy: dependency-check)
# Are the Postman skills committed in this repo up to date? An outdated skill is
# treated like a vulnerable library: the agent works from stale instructions.
STEP=skills-check
source "$(dirname "$0")/lib/common.sh"

CMD="postman skills status --json"
need postman && need jq || { not_available "postman CLI or jq not installed" "$CMD"; exit 0; }

out="$(mktemp)"; details="$(mktemp)"
$CMD > "$out" 2>/dev/null
state="$(jq -r '.state // "error"' "$out")"
jq '[(.files // [])[] | select(.state != "current") | {skill, path, state}]' "$out" > "$details" 2>/dev/null

case "$state" in
  current)  emit pass 100 "Skills match the published version" "$CMD" ;;
  behind)   emit warn 50  "Skills are behind the published version: run 'postman skills update'" "$CMD" "$details" ;;
  modified) emit warn 70  "Skills were edited locally" "$CMD" "$details" ;;
  unknown)  emit warn 70  "Skills cannot be compared (no recorded hashes)" "$CMD" "$details" ;;
  *)        not_available "skills status returned '$state': $(jq -r '.error // "no output"' "$out")" "$CMD" ;;
esac
exit 0
