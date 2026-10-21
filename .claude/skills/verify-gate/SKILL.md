---
description: Run KiwiDesk's verification gate — debug build, the touched test suites (the full suite where no PR gates the push), lint, the warning ratchet (AGENTS.md §3, the Verify step), plus the release build when the change touches concurrency. Use before any commit or PR.
argument-hint: "[optional: file/dir to scope the lint]"
---

Run KiwiDesk's verification gate — the Verify step AGENTS.md §3
delegates here — in order, and report the result of each step.
Stop and surface the failure the moment a step fails; do not
continue to later steps.

## Which gate the change earns

Default to the gate below. Its exceptions, and how much of the
suite a change runs locally:

- Read `.github/ci-ignore.txt`. Never restate that list here — it
  is the one authority, shared with the `changes` job in `ci.yml`,
  and `CiPathFilterTests` is what keeps it honest.
- If `git diff --name-only` against the base is **entirely**
  inside that list, the Swift gate cannot be affected: nothing the
  build, the lint or the suite reads is in it. Skip steps 1–3.
- **A change entirely inside `docs/` takes CI as its gate**
  (owner, 2026-10-16): push, open the PR and arm auto-merge
  without a local `swift test` or site build. CI runs the same
  checks — `Build, Lint & Test` reads `docs/` because
  `RuleCitationTests` and `InstructionPinTests` resolve the paths
  rule files pin there, and `Build site` builds the pages — and a
  red PR cannot merge, so the local run only finds the failure a
  few minutes sooner while holding the machine-wide gate slot
  other sessions wait on. Fix a red and push again. Still run
  `scripts/unreleased-strip --check` locally: it takes a second.
- **Anything else runs the gate.** `AGENTS.md`,
  `.claude/rules/**`, `.claude/agents/**` and this skill tree are
  instructions every session reasons from, and a prose-only edit
  to them has already shipped a dangling citation; code, tests and
  `site/` need it besides.
- **A change that lands through a PR leaves the full suite to CI**
  (owner, 2026-10-21). Run step 1, step 3 (its catalog checks
  included) and the ratchet check below, and in place of step 2
  run `swift test --filter` over the suites the diff touches —
  the suites it edits, and the suites that read or scan the code
  it edits. CI's `Build, Lint & Test` runs the whole suite on
  every PR and a red PR cannot merge: fix the red and push again.
  A local full run only duplicated that run (~7 min each) while
  holding the machine-wide gate slot (`scripts/gate-lock`) that
  other sessions wait on.
- **Run step 2 whole, locally,** when no PR gates the push
  (`scripts/release.sh`, a direct push), when CI is unavailable,
  or when a late red would be expensive — for example right
  before handing the owner a device build. Say in the report
  which of these applied.
- **Additionally**, when a gated change touches `site/` — or
  `docs/` beside code — run the site build: `npm ci && npm run
  build` in `site/`. It is a separate gate, not a substitute: a
  missing Starlight frontmatter block breaks the site and no Swift
  test can see it.

Say in the report which gate you ran and why.

## Fast inner loop

Heavy steps queue machine-wide: `scripts/gate-hook` runs every
`swift build` / `swift test` whole under `scripts/gate-lock`,
one at a time across all worktrees, so parallel sessions stop
throttling the machine. Queue wait plus the suite can pass the
Bash tool's 10-minute cap — run the test step with
`run_in_background`. A step that says "gate busy" is waiting,
not hung; don't kill it or run around it.

1. `swift build`
2. `swift test -q` (the full suite — a PR-gated change runs
   only the `--filter`ed suites, per the gate section above.
   One command — the old two-command split died with the #494
   tail-hang fix; history and the rest of the test conventions
   live in `.claude/rules/tests.md`. `-q` drops the ~20k
   per-test progress lines a green full run prints (#1140);
   failure issues and the run summary still print, and a red
   run is re-run `--filter`ed for detail)
3. `scripts/lint.sh $ARGUMENTS` (omit the argument to lint the
   repo)

`scripts/lint.sh` prints warnings that are not failures — only
its **exit code** decides.

**A compiler warning reds CI even though step 1 passes (#1594,
#1596).** `ci.yml`'s Build and Test steps ratchet
(`-warnings-as-errors`, deprecations excepted) and step 1 above
does not, so a new warning — in `Sources/` or `Tests/` — is a
red PR after a green local gate.
Worse, SwiftPM re-emits nothing for a module it did not
recompile, so a warm tree hides it from a re-run. Before pushing,
check the warning the ratchet would see:

```
scripts/warning-gate swift build --build-tests \
  -Xswiftc -warnings-as-errors \
  -Xswiftc -Wwarning -Xswiftc DeprecatedDeclaration
```

`scripts/warning-gate` fails on a warning `-warnings-as-errors`
cannot promote — an isolation inherited from an SDK class
(#1780) — as CI's steps do.

Step 1 keeps its bare command deliberately: `VerifyGateParityTests`
scrapes it and requires the identical line in `scripts/release.sh`
and `release.yml`'s verify job, both of which the ratchet
deliberately exempts.

## Release build — conditional

4. `swift build -c release`

The release build enables the optimizer and stricter concurrency
diagnostics (e.g. non-Sendable captures in `@Sendable` closures)
that the debug build silently misses. CI runs it as a parallel
job on every PR (#532), and that job is a **required status
check** on `main` — `scripts/protect-main.sh`'s `CONTEXTS` is
the one copy of which checks are (#487) — so a red release build
cannot merge. It is therefore **not** a mandatory local step.

Run it locally when the change touches concurrency, `@Sendable`
boundaries, or `Sendable` conformances — there the ~2min buys
back a PR round-trip. Otherwise skip it and let CI catch it, and
say in the report that it was skipped and why. Run it locally
anyway for anything landing without a PR, where no check gates
the push.

## Report

End with a one-line PASS/FAIL summary per step, marking step 2
FULL or FILTERED (naming the filter) and step 4 PASS, FAIL, or
SKIPPED (with the reason). On any failure, show
the relevant compiler/test/lint output and stop — the gate has
not passed.
