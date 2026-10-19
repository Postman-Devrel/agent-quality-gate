#!/usr/bin/env bash
# Shared helpers for the gate steps.
#
# Contract of every step script:
#   - runs ONE Postman CLI command (plus minimal glue)
#   - writes gate-results/<step>.json with the normalized result
#   - never fails the job by itself (always exits 0): the aggregate step decides
#
# Result shape:
#   { "step", "status": pass|warn|fail|not_available, "score": 0-100|null,
#     "summary", "details": [...], "command" }

RESULTS_DIR="${GATE_RESULTS_DIR:-gate-results}"
CONTRACT="${CONTRACT:-contract/openapi.yaml}"
COLLECTION="${COLLECTION:-postman/collections/Orders API}"

log() { printf '[gate:%s] %s\n' "${STEP:-?}" "$*" >&2; }

# need <binary>: returns 1 (and logs) when a tool is missing.
need() { command -v "$1" >/dev/null 2>&1 || { log "missing tool: $1"; return 1; }; }

# emit <status> <score|null> <summary> <command> [details-json-file]
# Writes the normalized result and prints a one-line verdict.
emit() {
  local status="$1" score="$2" summary="$3" command="$4" details_file="${5:-}"
  local details='[]'
  [ -n "$details_file" ] && [ -s "$details_file" ] && details="$(cat "$details_file")"
  mkdir -p "$RESULTS_DIR"
  jq -n --arg step "$STEP" --arg status "$status" --argjson score "$score" \
        --arg summary "$summary" --arg command "$command" --argjson details "$details" \
        '{step:$step,status:$status,score:$score,summary:$summary,details:$details,command:$command}' \
        > "$RESULTS_DIR/$STEP.json"
  printf '%s: %s (score=%s) %s\n' "$STEP" "$status" "$score" "$summary"
}

# not_available <reason> <command>: the capability is missing or cannot run.
# It is excluded from the weighted score and shown in grey, never counted as a pass.
not_available() {
  echo "NOT_AVAILABLE: $1" >&2
  emit not_available null "NOT_AVAILABLE: $1" "$2"
}

# Run from the repository root whatever the caller's directory.
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 0
