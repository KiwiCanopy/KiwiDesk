---
description: Run KiwiDesk's two-agent review workflow (code-reviewer + architect-reviewer) with the AGENTS.md §3 (Review step) sequencing. Use on a finished, verified, committed change before opening a PR.
argument-hint: "[optional: base ref, e.g. main or a commit/PR]"
---

Run the review workflow from AGENTS.md §3 (the Review step) on the
current change. Precondition: the change should already be
finished, verified (`/verify-gate`), and committed. If it clearly
is not, say so and stop.

## 1. Establish the diff

Determine the review range from `$ARGUMENTS` if given (a base ref —
the last reviewed commit or PR merge point), else the branch's
merge base with `main`.

!`BASE="$ARGUMENTS"; BASE="${BASE:-$(git merge-base HEAD main)}"; echo "--- diff stat vs $BASE ---" && git diff --stat "$BASE"...HEAD 2>/dev/null`

## 2. First round — parallel

Spawn **both** `code-reviewer` and `architect-reviewer` on the diff
**in parallel** (one message, two Agent calls): the diff is
finished and the perspectives are independent, so serializing only
costs time. Brief each with the review range.

## 3. Triage

Collect findings. Address or **consciously dismiss** each one
(state why dismissed). Apply fixes as a focused follow-up.

## 4. Re-review — only if the fix batch is substantial

If the fixes are substantial (new abstractions, behavioral gates —
not just comment or guard tweaks), re-review **only the fix range**,
**sequentially**:

1. `code-reviewer` first — are the fixes correct?
2. then `architect-reviewer` — do the seams the fixes introduced
   hold up?

Brief each re-review with what the fixes claim to do, so it
verifies the claims instead of re-reviewing the whole feature.
Alternate rounds until one returns no major findings.

## 5. Report

Summarize: findings raised, fixed, and dismissed (with reasons).
Only then is the change ready for a PR.
