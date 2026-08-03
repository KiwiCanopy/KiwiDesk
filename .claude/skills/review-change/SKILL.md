---
description: Run KiwiDesk's review workflow — code-reviewer and architect-reviewer in parallel, plus whichever specialist lanes the diff opens — with the AGENTS.md §3 (Review step) sequencing. Use on a finished, verified, committed change before opening a PR.
argument-hint: "[optional: base ref, e.g. main or a commit/PR]"
---

Run the review workflow — the Review step AGENTS.md §3 delegates
here — on the current change. Precondition: the change should already be
finished, verified (`/verify-gate`), and committed. If it clearly
is not, say so and stop.

## 1. Establish the diff

Determine the review range from `$ARGUMENTS` if given (a base ref —
the last reviewed commit or PR merge point), else the branch's
merge base with `main`.

!`BASE="$ARGUMENTS"; BASE="${BASE:-$(git merge-base HEAD main)}"; echo "--- diff stat vs $BASE ---" && git diff --stat "$BASE"...HEAD 2>/dev/null`

## 2. First round — parallel

Spawn `code-reviewer` and `architect-reviewer` on the diff **in
parallel** (one message, one Agent call each): the diff is finished
and the perspectives are independent, so serializing only costs
time. Brief each with the review range.

Open the additional lanes the diff earns — in the **same**
message, since they are independent too. The gate is a property of
the diff, not a judgement call:

| The diff… | also spawn |
|---|---|
| adds or edits a test | `guard-prover` |
| changes user-visible behavior | `docs-steward` |
| adds or alters an `L()` string, or touches a catalog | `localization-auditor` |
| touches `site/` | `site-engineer` |

`guard-prover` mutates code, so spawn it the way its own file asks
to be spawned; the other lanes are read-only or edit only their own
tree.

The gate above is a property of the diff — it is this skill's to
own. What each agent *is*, and when to reach for one outside a
review, is in [subagents.md](../../rules/subagents.md).

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

The loop is gated on substance: a substantial fix batch earns a
round, a lone comment or guard tweak that closes a finding does
not — self-verify that one and stop.

### Which agent runs a re-review

Round 1 always uses **fresh** agents (decision 2026-07-13):
independence is the point, and a reviewer carrying opinions from
an earlier feature anchors on them.

A re-review in the **same session** goes back to the round-1
agent (message it) rather than spawning a new one — it already
holds the diff and its own findings, so it verifies "were my
findings fixed" directly instead of re-deriving the context.

But reuse by **cache warmth**, not by the session boundary alone
(decision 2026-07-17). Resuming only wins while the agent's
context is still cache-warm. After a long gap (many edits, a slow
rebuild) resuming reloads its whole now-stale transcript
uncached — a large context just to answer a small question. Then
a **fresh** agent with a tight "here's what each fix claims to
do" brief is cheaper and nearly as good.

So: reuse while warm; go fresh once it has cooled. Across
sessions it is moot — subagent context dies with the session. If
the reuse target was stopped or died, fresh is the only option:
brief it fully.

## 5. Report

Summarize: findings raised, fixed, and dismissed (with reasons).
Only then is the change ready for a PR.
