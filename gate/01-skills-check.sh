#!/usr/bin/env bash
# Step 1 - Skills check (Sonar analogy: dependency-check)
# Are the Postman skills committed in this repo up to date? An outdated skill is
# treated like a vulnerable library: the agent works from stale instructions.
#
# Workaround for a Postman CLI bug (1.73.0 and 1.75.0): `postman skills status` answers
# "foreign" as soon as postman/skills holds a .py file, and the skills themselves ship two
# (performance-testing/.../scripts/*.py). So the check runs on a temporary copy of the skills
# without .py files, and those two files are ignored in the verdict. See docs/cli-inventory.md.
STEP=skills-check
source "$(dirname "$0")/lib/common.sh"

CMD="postman skills status --json"
need postman && need jq || { not_available "postman CLI or jq not installed" "$CMD"; exit 0; }
[ -d postman/skills ] || { not_available "no postman/skills folder in this repository" "$CMD"; exit 0; }

# Temporary copy: only the skills and the hashes recorded by `postman init`.
work="$(mktemp -d)"
mkdir -p "$work/postman" && cp -R postman/skills "$work/postman/" && cp -R .postman "$work/"
find "$work/postman" -name '*.py' -delete
git -C "$work" init -q

out="$(mktemp)"; details="$(mktemp)"
( cd "$work" && $CMD ) > "$out" 2>/dev/null
state="$(jq -r '.state // "error"' "$out")"

# The deleted .py files show up as "missing", which turns "current" into "behind" (or "blocked"
# when a skill is also edited). Re-derive the verdict from every other file.
if [ "$state" = "behind" ] || [ "$state" = "blocked" ]; then
  jq '[(.files // [])[] | select(.state != "current" and (.path | endswith(".py") | not)) | {skill, path, state}]' "$out" > "$details"
  if   [ "$(jq 'map(select(.state == "modified")) | length' "$details")" -gt 0 ]; then state="modified"
  elif [ "$(jq 'length' "$details")" -gt 0 ] || [ "$(jq '(.orphans // []) | length' "$out")" -gt 0 ]; then state="behind"
  else state="current"; fi
else
  jq '[(.files // [])[] | select(.state != "current") | {skill, path, state}]' "$out" > "$details" 2>/dev/null
fi

case "$state" in
  current)  emit pass 100 "Skills match the published version" "$CMD" ;;
  behind)   emit warn 50  "Skills are behind the published version: run 'postman skills update'" "$CMD" "$details" ;;
  modified) emit warn 70  "Skills were edited locally" "$CMD" "$details" ;;
  unknown)  emit warn 70  "Skills cannot be compared (no recorded hashes)" "$CMD" "$details" ;;
  *)        not_available "skills status returned '$state': $(jq -r '.error // "no output"' "$out")" "$CMD" ;;
esac
exit 0
