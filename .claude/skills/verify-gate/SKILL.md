---
description: Run KiwiDesk's full verification gate — debug build, tests, and lint (AGENTS.md §3, the Verify step), plus the release build when the change touches concurrency. Use before any commit or PR.
argument-hint: "[optional: file/dir to scope the lint]"
---

Run KiwiDesk's verification gate — the Verify step AGENTS.md §3
delegates here — in order, and report the result of each step.
Stop and surface the failure the moment a step fails; do not
continue to later steps.

## Which gate the change earns

Default to the full gate below. One narrow exception, and it is
about running the gate that *can* catch something rather than
about saving time:

- Read `.github/ci-ignore.txt`. Never restate that list here — it
  is the one authority, shared with the `changes` job in `ci.yml`,
  and `CiPathFilterTests` is what keeps it honest.
- If `git diff --name-only` against the base is **entirely**
  inside that list, the Swift gate cannot be affected: nothing the
  build, the lint or the suite reads is in it. Skip steps 1–3.
- **Anything else runs the full gate.** `docs/`, `AGENTS.md`,
  `.claude/rules/**` and `.claude/agents/**` are deliberately not
  on the ignore list, so "it's only prose" is not a reason to
  skip: `RuleCitationTests` and `InstructionPinTests` read that
  tree — including paths a rule file *pins*, which is why
  `docs/**` is not ignorable — and a prose-only edit there has
  already shipped a dangling citation.
- **Additionally**, when the change touches `docs/` or `site/`,
  run the site build — `npm ci && npm run build` in `site/`. It
  is a separate gate, not a substitute: a missing Starlight
  frontmatter block breaks the site and no Swift test can see it.

Say in the report which gate you ran and why.

## Fast inner loop

1. `swift build`
2. `swift test -q` (one command — the old two-command split
   died with the #494 tail-hang fix; history and the rest of
   the test conventions live in `.claude/rules/tests.md`. `-q`
   drops the ~20k per-test progress lines a green full run
   prints (#1140); failure issues and the run summary still
   print, and a red run is re-run `--filter`ed for detail)
3. `scripts/lint.sh $ARGUMENTS` (omit the argument to lint the
   repo)

`scripts/lint.sh` prints warnings that are not failures — only
its **exit code** decides.

## Release build — conditional

4. `swift build -c release`

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

End with a one-line PASS/FAIL summary per step, marking step 4
PASS, FAIL, or SKIPPED (with the reason). On any failure, show
the relevant compiler/test/lint output and stop — the gate has
not passed.
