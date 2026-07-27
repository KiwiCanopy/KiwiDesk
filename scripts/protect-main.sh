#!/bin/bash
# Applies the branch-protection settings decided in #487, in one
# step, so the window between "KiwiDesk is public" and "main is
# protected" is seconds rather than a click-through.
#
# WHY IT CANNOT RUN EARLIER: GitHub's free plan answers
#   403 Upgrade to GitHub Pro or make this repository public
# for the protection endpoint, so this unlocks at the public flip.
# Run it immediately after flipping visibility.
#
# NOT every setting here is the hardened default. Two are deliberate
# deviations, ratified 2026-07-27 — do not "correct" them to the
# generic advice without re-reading why:
#
#   required_approving_review_count = 0, NOT the usual >=1. GitHub
#   does not let you approve your own PR, so on a solo repo a
#   required approval either deadlocks every merge or gets bypassed
#   on every merge — protecting nothing either way. Merge rights come
#   from repo role, so an outside contributor still cannot merge with
#   0. Flip to 1 the day a second collaborator with Write access
#   exists.
#
#   enforce_admins = false, where GitHub's own hardening advice is to
#   INCLUDE administrators. Owner's call, eyes open: it keeps an
#   escape hatch for a genuine emergency, at the price that these
#   rules NUDGE rather than bind the one account with write access.
#   Understand what that does and does not buy — the owner is already
#   the only thing that can merge (no auto-merge, workflow token is
#   read-only, Actions cannot approve PRs), so the value here is not
#   keeping others out. It is that the merge button stays hidden
#   until CI is green, which catches the mistake that actually
#   happens: merging red. Everything else is self-discipline.
#
# required_conversation_resolution = true is an addition beyond
# #487's list (kept 2026-07-27): it stops a PR merging with an
# unanswered review comment, which starts mattering the day outside
# PRs arrive. dismiss_stale_reviews was dropped as near-inert at 0
# required approvals.
#
# Status checks are listed by JOB NAME and must match
# .github/workflows/ci.yml. This is the setting that finally makes
# CI block rather than report (#532).
set -euo pipefail

REPO="${1:-KiwiCanopy/KiwiDesk}"

visibility="$(gh api "repos/$REPO" --jq .visibility)"
if [ "$visibility" != "public" ]; then
    echo "ERROR: $REPO is '$visibility'."
    echo "  Branch protection needs a public repo on the free plan."
    echo "  Flip visibility first, then re-run."
    exit 1
fi

# A required context is the job's DISPLAY name (`name:`) when it has
# one, not the job id — get this wrong and every merge blocks forever
# on a check that can never report. Both CI jobs set `name:`, so the
# contexts are those, not `build-lint-test` / `release-build`.
#
# Echoed from the workflow rather than trusted, because a rename in
# CI would silently invalidate the list.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Job display names in .github/workflows/ci.yml:"
awk '/^jobs:/{j=1; next} j && /^  [a-zA-Z0-9_-]+:$/{id=$1}
     j && /^    name:/{sub(/^    name: */, ""); print "  " id " -> " $0}' \
    "$ROOT/.github/workflows/ci.yml"
CONTEXTS='["Build, Lint & Test", "Release Build"]'
echo "Requiring: $CONTEXTS"
echo "If the names above disagree, fix CONTEXTS and re-run."

echo "Applying protection to $REPO main..."
gh api -X PUT "repos/$REPO/branches/main/protection" \
    --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": $CONTEXTS
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON

echo
echo "Enabling repo-level hardening (public-only features)..."
gh api -X PATCH "repos/$REPO" \
    -F delete_branch_on_merge=true \
    -F allow_rebase_merge=false >/dev/null
gh api -X PUT "repos/$REPO/vulnerability-alerts" >/dev/null 2>&1 \
    || true

echo
echo "Done. Verify:"
echo "  gh api repos/$REPO/branches/main/protection --jq ."
echo
echo "Still manual (no stable API on the free plan) — Settings >"
echo "Code security:"
echo "  - secret scanning + push protection"
echo "  - private vulnerability reporting"
echo "Then move SECURITY.md into KiwiCanopy/.github (#487) and drop"
echo "this repo's copy: a repo-level file overrides the org default."
