---
description: Live demo loop. A coder agent implements an API change and pushes a branch, CI runs the gate, a reviewer agent reads the result and briefs the coder, until the gate passes (max 3 rounds).
argument-hint: "<feature description>"
---

Run the quality gate loop for this feature: $ARGUMENTS

1. Pick a branch name `demo/live-<short-slug>` (never `main`).
2. Spawn the **api-coder** agent: implement the feature on that branch (contract first, code, tests, Postman collection), run the gate locally, push the branch. Ask it to end with the branch name and the commit SHA.
3. Spawn the **gate-reviewer** agent with the branch and SHA. It waits for the GitHub Actions run and returns the verdict and a fixes brief.
4. Show me the verdict and the brief in a short summary (rating, blockers, number of fixes).
5. If the verdict is FAILED, send the brief to the **same api-coder** (SendMessage to its id) and ask it to fix and push to the same branch. Then go back to step 3 with the new SHA. Stop after 3 rounds.
6. When PASSED, or after round 3, give me: rounds played, rating per round, what changed between rounds, and the PR/branch link. Do not merge anything.

Rules: you only orchestrate. Do not edit code yourself and do not run the gate yourself, the two agents do. Never push to `main`.
