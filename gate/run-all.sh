#!/usr/bin/env bash
# Runs the five gate steps in sequence, then the aggregation (local equivalent of the CI workflow).
set -u
cd "$(dirname "$0")/.." || exit 1
rm -rf "${GATE_RESULTS_DIR:-gate-results}"
for step in gate/0*.sh; do "$step"; done
node gate/aggregate.js
