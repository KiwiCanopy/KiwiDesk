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
#   require_code_owner_reviews = FALSE for the same reason: a code
#   owner's review is required whenever an owned path changes, the
#   owner cannot approve their own PR, and enforce_admins is true —
#   so on a solo repo the gate deadlocks every owner PR that touches
#   any path .github/CODEOWNERS owns. CODEOWNERS still does its
#   other job with this false: it auto-requests the owner on
#   outside PRs to those paths, and what stops an outsider from
#   rewording the licence chain is that only the owner can merge
#   (#1521). Flip this together with the approval count.
#
#   ORDER: the "CLA" context below is reported by a workflow that
#   `pull_request_target` runs from MAIN's copy, so re-running this
#   script before .github/workflows/cla.yml is on main blocks every
#   open PR on a context that cannot report. Merge it, see the job
#   green on one PR, then re-run.
#
#   enforce_admins = TRUE, and this reverses #487's original line
#   ("leave do-not-allow-bypassing OFF so an emergency fix is
#   possible"). That advice is sound on a TEAM repo, where the rules
#   still bind every other contributor and the exemption is only an
#   owner override. It does not survive a solo repo: the owner is the
#   only account with write access AND an admin, so exempting admins
#   exempts everybody and the whole ruleset binds nobody.
#
#   With it true, the rules bind the one person they can. Workflow
#   becomes branch -> PR -> CI green -> merge, and no approval is
#   needed (required_approving_review_count is 0, meaning zero, not
#   one). What it buys is that red CI cannot be merged.
#
#   The emergency hatch is not lost, just not left permanently open:
#   toggle this off in Settings (~15 s), fix, toggle back. Paying the
#   protection every day to save that on the rare day was the wrong
#   trade (owner, 2026-07-27).
#
#   NOTE: this is what finally makes `git push origin HEAD:main`
#   fail — the ff-merge convention retires here, by enforcement
#   rather than by agreement. Squash-via-PR becomes the one path.
#
# required_conversation_resolution = true is an addition beyond
# #487's list (kept 2026-07-27): it stops a PR merging with an
# unanswered review comment, which starts mattering the day outside
# PRs arrive. dismiss_stale_reviews was dropped as near-inert at 0
# required approvals.
#
# required_status_checks.strict = true is the one ordering rule:
# a PR merges only from a branch that is up to date with main, so
# the CI run on the PR head IS the run on the merged result. A
# merge-queue ruleset stood in for it from 2026-08-30 to
# 2026-09-14 and was retired for costing more wall-clock than it
# saved (owner ruling); do not bring it back without that ruling
# being reversed, and keep strict true while it is gone.
#
# Status checks are listed by JOB NAME and must match the
# workflows that report them — .github/workflows/ci.yml for the two
# macOS jobs, cla.yml for the CLA check. This is the setting that
# finally makes CI block rather than report (#532).
#
# ci.yml's two jobs are gated on its `changes` job rather than
# on a trigger filter, which is what makes requiring them safe: a
# PR touching only ignored paths leaves them *skipped*, and GitHub
# counts a skipped job as satisfying a required check. Filtering at
# the trigger instead would leave the workflow unreported and every
# such PR stuck on "Expected". CiPathFilterTests keeps that shape;
# packaging-and-release.md ("CI") carries the argument. The CLA
# check is safe to require for a different reason: it runs on
# every pull_request_target with no path filter, so it always
# reports — except on a PR opened with GITHUB_TOKEN, which fires
# no PR event at all (the same rule file, the fallback paragraph).

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
# on a check that can never report. Every required job sets
# `name:`, so the contexts are those, not `build-lint-test` /
# `release-build` / `cla`.
#
# Echoed from the workflow rather than trusted, because a rename in
# CI would silently invalidate the list.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Job display names in .github/workflows/ci.yml and cla.yml:"
awk '/^jobs:/{j=1; next} j && /^  [a-zA-Z0-9_-]+:$/{id=$1}
     j && /^    name:/{sub(/^    name: */, ""); print "  " id " -> " $0}' \
    "$ROOT/.github/workflows/ci.yml" "$ROOT/.github/workflows/cla.yml"
# "CLA" is .github/workflows/cla.yml's job (#1521): an unsigned
# commit author cannot merge; the owner is not exempt and passes
# after signing once.
CONTEXTS='["Build, Lint & Test", "Release Build", "CLA"]'
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
  "enforce_admins": true,
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
echo "YOUR WORKFLOW CHANGED as of this moment:"
echo "  'git push origin HEAD:main' now FAILS (enforce_admins)."
echo "  Use: branch -> PR -> wait for CI -> squash merge."
echo "  No approval needed; 0 required means zero."
echo
echo "Genuine emergency? Reopen the hatch, fix, close it:"
echo "  gh api -X PATCH repos/$REPO/branches/main/protection \\"
echo "    -F enforce_admins=false   # ...fix..., then re-run this"
echo
echo "Still manual (no stable API on the free plan) — Settings >"
echo "Code security:"
echo "  - secret scanning + push protection"
echo "  - private vulnerability reporting"
echo "Then move SECURITY.md into KiwiCanopy/.github (#487) and drop"
echo "this repo's copy: a repo-level file overrides the org default."
