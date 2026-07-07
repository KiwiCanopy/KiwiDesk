---
description: Run KiwiDesk's full verification gate — debug build, tests, lint, and the mandatory release build (AGENTS.md §3, the Verify step). Use before any commit or PR.
argument-hint: "[optional: file/dir to scope the lint]"
---

Run KiwiDesk's verification gate from AGENTS.md §3 (the Verify
step), in order, and report the result of each step. Stop and
surface the failure the moment a step fails — do not continue to
later steps.

## Fast inner loop

1. `swift build`
2. `swift test`
3. `scripts/lint.sh $ARGUMENTS` (omit the argument to lint the repo)

## Mandatory release gate

4. `swift build -c release`

The release build is **required** before any commit or PR: it
enables the optimizer and stricter concurrency diagnostics (e.g.
non-Sendable captures in `@Sendable` closures) that the debug
build silently misses. A change that passes 1–3 but fails 4 is
**not** verified.

## Report

End with a one-line PASS/FAIL summary per step. On any failure,
show the relevant compiler/test/lint output and stop — the gate
has not passed.
