#!/usr/bin/env bash
# Step 5 - Impact (no Sonar equivalent: this is the point)
# Who depends on this API? The Context Graph is the right source.
#
# NOT_AVAILABLE today: `postman context-graph ask` answers in free text, with no
# structured consumer list and no breaking-change flag (see docs/cli-inventory.md).
# The command is kept here so the gap is explicit and easy to close.
STEP=impact
source "$(dirname "$0")/lib/common.sh"

CMD='postman context-graph ask "Which APIs or consumers depend on the Orders API?" --wait --json'
not_available "Context Graph returns free text only: no structured consumers or breaking flag" "$CMD"
exit 0
