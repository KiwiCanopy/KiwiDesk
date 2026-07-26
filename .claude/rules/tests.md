---
paths:
  - "Tests/**"
---

# Tests

The binding rules live in **AGENTS.md §2 & §5** (canonical). The
ones that bite large test PRs, as a checklist (rationale is in §5):

- **Pin the display, never inherit it** — a geometry fixture sets
  `core.tiler.visibleBounds = { _ in rect }` (#531), and pins any
  default it reasons from (`#expect(minWindowSize == 300)`). A
  test that lets the layout resolve the host's real `NSScreen`
  asserts whatever that machine is, and a narrow CI runner builds
  a different arrangement from identical code (#523). The hook
  pins bounds only: screen *existence* and topology are still the
  host's, and a fixture driving a whole `retile` is only half
  pinned (parking and bar geometry run against the real display).
  Reproduce a CI-only geometry failure by raising
  `min_window_size` until the same threshold trips; a pile is
  equal `minX` with midYs 40 pt apart.
- **Split suites early** — the 79-char limit and 350-line ceiling
  bite large test files. Break a suite into focused files *before*
  it approaches the ceiling.
- **Per-file private helpers are the convention** — small
  duplication across suites is fine; no shared test harness.
  Four ratified exceptions, all *stateless primitives* with no
  setup/teardown coupling and no assertions of their own:
  - *structural-parity primitives* (reflection helpers backing
    the field-list guards) in `ReflectionParity.swift` — a
    divergent copy would silently weaken a guard, the exact
    drift those guards prevent;
  - *script-spawn primitives* in `ScriptFixture.swift` — spawn
    a `scripts/*` tool and drain its pipes, plus the
    repo-shaped temp tree the `__file__`-rooted scripts need
    (the env-var-scoped `extract-keys` suites still lay out
    their own flat dirs, and that duplication is fine).
    Extracted at the **fifth** copy (#252's merge-keys suite,
    per the #249 architect review); a divergent copy silently
    changes what a suite observes (an undrained pipe, a missed
    `stderr`) without failing anything.
  - *colour-vision maths* in `ColorVisionSimulation.swift` — the
    Viénot protanopia transform plus luminance/contrast, shared
    by `SpaceBarAccentSeparationTests` and
    `DragPairSeparationTests`. Extracted at the **second** copy
    (#511): those guards assert on the numbers it returns, and
    the numbers *are* the argument the palette decisions rest
    on, so a drifted copy silently moves a threshold without
    failing anything.
  - *source-scanning primitives* in `SourceScan.swift` — the
    delimiter walker (`balanced`, `skipLiteral`), comment
    stripper and file enumerator shared by the parity guards
    that scan Swift source. Extracted at the **second** copy,
    on drift risk alone: harden the walker in one copy and not
    the other and the over-matching copy swallows the very call
    sites its guard exists to catch, so the guard passes for
    the wrong reason.

  **The drift risk is the bar; the copy count is only the
  evidence that prompted the look.** Both cases above happened
  to be caught at a threshold, but "we're at three copies" is
  not on its own an argument — a fourth shared helper needs a
  named way that a divergent copy would weaken a guard or
  change what a suite observes, plus statelessness. Duplication
  that merely costs lines stays duplicated (§2.4).
- **Discardable results express side-effect intent** — a command
  or setup helper whose primary job is mutation may use
  `@discardableResult` when callers commonly ignore optional
  convenience data. Pure queries stay non-discardable, and tests
  about command success/failure still assert the response; never
  remove coverage merely to silence a warning.
- Config/profile shape is pinned by `SettingsCodingTests` — extend
  it when adding a setting (Lua name → JSON key via `CodingKeys`;
  see [config-vocabulary.md](config-vocabulary.md)).
- Pre-release, single-user: profile JSON needs no migration — see
  [profiles.md](profiles.md) and §5.
