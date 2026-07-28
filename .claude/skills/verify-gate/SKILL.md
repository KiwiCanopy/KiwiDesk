---
description: Run KiwiDesk's full verification gate — debug build, tests, and lint (AGENTS.md §3, the Verify step), plus the release build when the change touches concurrency. Use before any commit or PR.
argument-hint: "[optional: file/dir to scope the lint]"
---

Run KiwiDesk's verification gate — the Verify step AGENTS.md §3
delegates here — in order, and report the result of each step.
Stop and surface the failure the moment a step fails; do not
continue to later steps.

## Fast inner loop

1. `swift build`
2. `swift test --skip ExecTests`
3. `swift test --filter ExecTests`
4. `scripts/lint.sh $ARGUMENTS` (omit the argument to lint the
   repo)

Steps 2 and 3 are **separate commands** by design — run as one
`swift test` the suite stalls for minutes at the tail. Why, and
the rest of the test conventions, live in
`.claude/rules/tests.md`.

`scripts/lint.sh` prints warnings that are not failures — only
its **exit code** decides.

## Release build — conditional

5. `swift build -c release`

The release build enables the optimizer and stricter concurrency
diagnostics (e.g. non-Sendable captures in `@Sendable` closures)
that the debug build silently misses. CI runs it as a parallel
job on every PR (#532), so it is **not** a mandatory local step.

Run it locally when the change touches concurrency, `@Sendable`
boundaries, or `Sendable` conformances — there the ~2min buys
back a PR round-trip. Otherwise skip it and let CI catch it, and
say in the report that it was skipped and why.

CI **reports** this job, it does not **block** on it (required
status checks need branch protection, which this plan does not
offer for a private repo — #487). So when you skip it locally,
say in the report that the `Release Build` job must be read
before merging — and run it locally anyway for anything landing
without a PR.

## Report

End with a one-line PASS/FAIL summary per step, marking step 5
PASS, FAIL, or SKIPPED (with the reason). On any failure, show
the relevant compiler/test/lint output and stop — the gate has
not passed.
