---
paths:
  - "Tests/**"
---

# Tests

Canonical for this tree (AGENTS.md §5 indexes it). The rules that
bite large test PRs:

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
  `min_window_size` until the same threshold trips — below
  `2 * min_window_size` BSP correctly falls back to an
  `OverlapStack` pile, which is how three reachability assertions
  failed on a narrow runner and passed on a dev Mac (#523). A
  pile's signature is equal `minX` with midYs exactly
  `OverlapStack.offset` (40 pt, vertical-only) apart.
- **Split suites early** — the 79-char limit and 350-line ceiling
  bite large test files. Break a suite into focused files *before*
  it approaches the ceiling.
- **Per-file private helpers are the convention** — small
  duplication across suites is fine; no shared test harness.
  Five ratified exceptions, all *stateless primitives* with no
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
  - *colour-vision maths* in `ColorVision.swift` — the
    Viénot protanopia transform plus luminance/contrast, shared
    by `SpaceBarAccentSeparationTests` and
    `DragPairSeparationTests`. Extracted at the **second** copy
    (#511): those guards assert on the numbers it returns, and
    the numbers *are* the argument the palette decisions rest
    on, so a drifted copy silently moves a threshold without
    failing anything. It also owns the shared separation
    **floor**: the two families share hexes (the drop-zone amber
    *is* the Space Bar's focused accent), so one threshold over
    one colour is deliberate, not policy misfiled into a maths
    helper.
  - *source-scanning primitives* in `SourceScan.swift` and its
    `SourceScan+*.swift` extensions — the walkers, matchers and
    file enumeration shared by the parity guards that scan Swift
    source. Deliberately **not** enumerated member by member
    here: the family grows a helper whenever a second guard
    needs the same walk, and a list in this file went stale
    within two additions. Extracted at the **second** copy, on
    drift risk alone: harden a walker in one copy and not the
    other and the over-matching copy swallows the very call
    sites its guard exists to catch, so the guard passes for
    the wrong reason. `SettingsCatalogFiles.swift` belongs to
    this family rather than counting as a further exception —
    it is the *which files* half of the same machinery, and the
    named harm is identical: narrow the predicate in one copy
    and not the other and the wider copy silently exempts a
    file from a fail-open guard (#573 proved that exact bug
    with a one-file probe that passed every check).
  - *test-core construction* in `TestCore.swift` — the
    `makeTestCore` factory and its `NoopHotkeyRegistrar` (#565),
    one copy per test target since test targets cannot see each
    other; `MachineTouchTests` pins the twins identical and pins
    every `KiwiCore(` in the test trees to them.
    It clears the statelessness bar (a per-instance id counter, no
    assertions, no setup/teardown coupling), but it is admitted on
    a **second, distinct ground** from the four above. Their risk
    is *divergence*: a drifted copy silently weakens a guard or
    changes what a suite observes. This one's risk is *omission*:
    every copy is identically harmless, but a **forgotten** copy
    re-enables a dangerous production default — the live
    `CarbonHotkeyCenter` (and the real `~/.config/KiwiDesk`)
    seizing the developer's global chords and live config, 2414
    conflict lines a run. Forget-proofing every one of those
    call sites — well over a hundred, and the count climbs with
    each new suite, which is the point — is a legitimate basis
    for sharing; it is simply not
    the divergence-weakens-a-guard basis the closing paragraph
    below names. The admission gate therefore has two grounds, not
    one — state both when weighing a further one.
  (The status-item seam deliberately does NOT add a shared
  factory here: its fake is a per-file `StatusItemHandle`
  stub, because the live wrapper is sealed file-`private` and
  `StatusItemSeamGuardTests` pins every construction route —
  the omission risk the `makeTestCore` factory carries is
  closed by the seal instead.)

  **The drift risk is the bar; the copy count is only the
  evidence that prompted the look.** Each case above happened
  to be caught at a threshold, but "we're at three copies" is
  not on its own an argument — a further shared helper needs a
  named way that a divergent copy would weaken a guard or
  change what a suite observes, plus statelessness. Duplication
  that merely costs lines stays duplicated (§2.4).
- **A production default that grabs live host state gets an
  injection seam, a fake in tests, and a guard.** An `init`
  that seizes a real resource drags that seizure into every
  suite constructing the type: the #565 hotkey chords first,
  then the menu-bar slots a full GUI run parked in the real
  menu bar (up to 15, WindowServer at 40%+ CPU). Keep the
  production default live — never test-detection in
  production — inject a no-op fake in tests, and forget-proof
  the injection, because every forgotten call site re-enables
  the default. The standing enforcement: `MachineTouchTests`
  pins every `KiwiCore(` to the `makeTestCore` factories (and
  the seam class generally — spawns, the production status-bar
  touch), and `StatusItemSeamGuardTests` pins the menu-bar
  seam's construction routes and its sealed wrapper.
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
  [profiles.md](profiles.md).
- Mirrored field lists need a forget-proof parity test — see
  [parity-tests.md](parity-tests.md).

## Async tests: a generous hang-guard, never a tight deadline (#344)

A test that spawns a real subprocess (`ExecTests`) or schedules an
unstructured `Task` (`DragCoordinatorTests`) and then awaits its
**main-actor callback** cannot use a sub-second or few-second poll
deadline. swift-testing runs suites concurrently, so under
full-suite load the shared main actor is starved for seconds and
the tight deadline trips spuriously (the callback landed, just
late) while the suite passes in isolation.

Each such wait uses one shared generous hang-guard
(`execHangGuard` / `dragSettleHangGuard`, 30 s): the poll exits
the instant the condition holds, so a passing run is never slowed
— the deadline only bounds a genuine hang. Prove the *behavior* by
the gap (a short watchdog against a much longer sleep), never by a
tight wait. New async tests here follow suit.

## Running the suite

**A test reaches the machine only through a seam it injects,
never through a production default it inherited.** The touch a
test-tree grep cannot see is the one inside a *production*
initializer the test merely calls: a bare `KiwiCore()` seizes
the live Carbon chords and the real `~/.config/KiwiDesk`
(#565), and a bare `StatusItemController()` put a live item in
the menu bar per construction — fifteen leaked slots and a
sustained WindowServer spike per run — while `NSStatusBar` had
zero hits anywhere in `Tests/`. Two guards split the beat:
`MachineTouchTests` pins `KiwiCore(` constructions to the
`makeTestCore` factories, the twins identical, the production
`NSStatusBar.system` touch to its sealed wrapper, and
exec-child suites inside the `ExecTests` partition;
`StatusItemSeamGuardTests` pins the status-item seam's
construction routes. Adding a production type whose
*initializer* reaches the OS? Give it the same seam shape
(live default in production, an injected fake in tests) and a
needle in one of those guards.

Deliberate residue a run does still touch, as audited
2026-07-29 — a change adding a residue class extends and
re-dates this list in the same change set: throwaway AF_UNIX
sockets under temp paths (`SocketTests`), real `CADisplayLink`s
from animation-keyed suites, repo-script children drained by
`ScriptFixture`, one inert `true` child when
`FirstRunSeedTests`' executed hooks fixture fires, scratch
`UserDefaults` suites cleaned on both sides, one live
`NSEvent.pressedMouseButtons` read —
`MouseFollowsFocusTests` fails if a human holds a mouse button
mid-run — and `GeometryUtils.menuBarAutoHides`, a read-only
global-defaults lookup that only reaches fixtures which didn't
pin their bounds. The service tests only parse `launchctl`
strings; nothing spawns it. **Unit tests never need the running
app**; its run state is irrelevant to them.

**A run writes `KiwiDesk: …` lines to the unified log**, so a
`log stream` during one shows test diagnostics that read exactly
like the app's. Most come through `KiwiCore.onLog`, whose default
has always been the syslog write; since #624 a subsystem
constructed bare — `KeybindingManager(registrar:)`,
`CrashRecovery(directory:)` — adds its own, because a seam
defaults to `CoreLog.write` rather than to a no-op
(`LogSeamDefaultTests`). That is the intended trade: a suite
triggering a diagnostic path prints it instead of swallowing it,
which is how the settle-watchdog fixtures came to assert on the
line they were silently dropping. A suite that wants quiet
assigns `onLog = { _ in }` on the instance it builds, and one
that wants the coverage captures instead. Do not read a
`keybinding conflict` or `unclean shutdown detected` line seen
during a run as the app misbehaving.

Run the full suite as one command (~2 min):

```bash
swift test
```

It used to stall for minutes at the tail; that was two bugs,
both fixed in #494 — a `SocketClient` double-close that
`EXC_GUARD`-killed the runner mid-suite, and fire-and-forget
exec children inheriting the runner's stdout, so whoever read
it waited for an EOF that never came. Fire-and-forget children
now get `FileHandle.nullDevice` and callback children write to
launcher-owned pipes (`ExecLauncher`), so no child holds the
runner's stdio on either path. CI keeps its `--skip` /
`--filter` two-step over `ExecTests` for failure attribution,
which is why every suite spawning real shell children is
*named* under the `ExecTests` prefix (`MachineTouchTests` pins
that partition).

**Device QA launches the app direct**, not via `service start`:
`.build/release/KiwiDesk` in a terminal (Ctrl-C to stop, `NSLog`
output visible, including the #292 preflight-denial and settle
lines). Stop the service first if loaded, or the single-instance
guard keeps the OLD binary running. Every release rebuild changes
the binary hash, which drops the TCC Accessibility grant (re-grant
in System Settings), and a restart flattens session state (spaces,
float flags) — plan QA around it.

**With a Developer ID certificate in the keychain you can stop
paying that cost**: `./scripts/build-app.sh` (#89, shipped)
produces a signed `.app` whose code identity is stable across
rebuilds, so the grant survives. Without one the script falls
back to ad-hoc and says so — it prints that the grant will reset
on every rebuild — which leaves you exactly where the paragraph
above starts. Check the identity line it echoes rather than
assuming. See [packaging-and-release.md](packaging-and-release.md).

Two env levers exist for device QA, both off by default and both
read once at wiring:

| Lever | Does |
|---|---|
| `KIWIDESK_STRAND_LOG` | Logs any window that did not land on its settled target (#47). Purely a logger — inert otherwise. |
| `KIWIDESK_NO_WS_TRACKING` | Forces the ring and mark onto the **AX-fallback** path for the whole run (#596), so fallback-only symptoms are reachable on a healthy Mac. Kills a production fast path — see [borders.md](borders.md). |

Window geometry can be sampled without any screen-recording
grant: `CGWindowListCopyWindowInfo` returns frames for every
on-screen window, so a small poller that logs only frame
*changes* turns "does the overlay lag or wobble?" into a diff. A
ring's frame is its window's outset by `border.width`, so the two
can be compared arithmetically.
