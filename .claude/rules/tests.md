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
  Eight ratified exceptions, none with setup/teardown coupling or
  assertions of their own, and all but the fake WindowServer
  *stateless primitives*:
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
  - *the packaged-bundle plist reader* in
    `BuildPlistValue.swift` — one `Info.plist` value from
    `scripts/build-app.sh`, spawned through `read-plist-key`
    rather than parsed again. `build-app.sh` is the one owner of
    what every shipped bundle declares, and the guards that
    assert on the feed URL, the public key and the deployment
    floor all have to agree with it; a per-suite copy of the
    parse would keep agreeing with the shape the plist USED to
    have, which is the drift those guards exist to catch.
    Extracted at the **third** caller (#874), and it re-uses
    `ScriptFixture.swift`'s spawn primitive rather than
    duplicating it.
  - *colour-vision maths* in `ColorVision.swift` — the
    Viénot protanopia transform and the measures the CVD guards
    assert on. **Which suites share it is that file's own doc
    comment**, not a list here; a suite joining the family
    extends it there (`PaletteHighlightRoleTests` was the third,
    and the pair named here went stale the day it landed).
    Extracted at the **second** copy
    (#511): every one of them asserts on the numbers it returns,
    and the numbers *are* the argument the palette decisions rest
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
  - *the schematic placement promise* in
    `SchematicPlacementPromise.swift` — the four-arm statement of
    where a preview's `+` lands, read by
    `LayoutSchematicPlacementTests` and
    `LayoutSchematicScrollingTests`. Admitted on the divergence
    ground in its sharpest form: the copies would be of **the
    rule under guard**, so retuning it in one suite leaves the
    other green on the retired rule while both read as covering
    the same promise. The two suites cannot simply be one — the
    350-line ceiling is what split them. Only the statement is
    shared; each suite keeps its own `check` wrapper, so no
    assertion lives here.
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
  - *the fake WindowServer* in `ZOrderDrainFake.swift` — the late-
    landing, fake-clock window server the drain suites run
    against, shared by `ZOrderDrainTests` (#684) and
    `ZOrderTeardownDrainTests` (#688). Admitted on the
    divergence ground, with the harm already on record rather
    than hypothesized: a fake that models every raise as reaching
    index 0 makes a landing condition no real raise can satisfy
    look reachable, and that is what hid an unachievable check
    under twelve green tests until `pinned` was added. #688's
    suite is built on that property, so a second copy is a place
    to lose it again in the suite that needs it most.
    **It is the one entry here that carries state**, so it is
    also the case that says what the statelessness bar was
    protecting: cross-suite coupling. Each test builds its own
    instance and the state is that instance's clock and window
    order — nothing is shared or carried between tests, so the
    isolation the bar stood for holds. Weigh a further stateful
    helper against that, not against the word.
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
- **A test that touches process-global state proves itself alone
  AND in a full run.** The bar above governs what suites share
  on purpose; this governs what they share without meaning to.
  A scratch suite does not isolate a test that registers
  defaults, sets an environment variable or writes a shared
  domain — the worked case is
  `UserDefaults.register(defaults:)`, whose mechanism and
  passed-locally/red-on-CI history `ToolTipDelayTests` owns
  (2026-08-03). Neither a `--filter` run nor a `guard-prover`
  mutation can reach this class: both observe the test on its
  own, which is the state it passes in.
- **A test asserting localized output pins the locale first.**
  `L()` routes through `LocalizationManager.shared`, whose
  "System default" resolves the *host's* preferred languages, so
  a suite comparing against English asserts whatever the
  developer's Mac happens to be set to — #740's failures were a
  German machine rather than a defect, and they blocked
  `scripts/release.sh` on it. Pin with
  `LocalizationManager.shared.select("en")` as the first line of
  each test **body**, never `init`: suites interleave on the main
  actor at the init→body hop and another suite's `select()` lands
  in that window. `MonitorReadoutTests` owns that argument and is
  the worked example.

  **It is not only English literals.** An assertion on argument
  *order* reads a localized frame just as much, and positional
  specifiers exist so that a locale may reorder them
  ([localization.md](localization.md)) — `HomeCardContentTests`'
  gaps case asserts outer-before-inner and passed on a German
  host for no better reason than `de` keeping English's order.
  Ask what the assertion *reads*, not whether it looks like
  prose.

  **Nothing enforces this, and that is a ruling rather than an
  omission.** The one candidate signal — a test literal that is
  verbatim an `en.json` value — cannot discriminate in either
  direction: the localization guard suites read catalog values as
  data because that is their job, ordinary identifiers collide
  with catalog values by coincidence, and substring or
  interpolated assertions never match at all. The exemption map
  would be larger than the thing guarded, which is not the
  `allowed`-map idiom. So this row is the enforcement and review
  is where it bites. Re-opening it needs a *new* signal, not a
  re-run of that one.
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
- **One seam runs the OTHER way, and it is named here rather
  than left in a doc comment.** The rule above keeps a live
  production default and injects a fake; the updater seam (#874)
  defaults INERT and `AppDelegate` opts into the live
  `SparkleUpdater`. The reason is that its live object starts a
  scheduled network channel and spawns XPC services on
  construction, so a live default would run in every GUI suite
  that builds a `StatusItemController` — not a resource seized
  and released, but a background service. The inversion is only
  safe because it is guarded from BOTH sides:
  `UpdaterSeamGuardTests` pins the construction, the conformer
  and the wiring by exact count, so deleting the wiring reds
  exactly as loudly as duplicating it. That matters more than it sounds — a forgotten
  wiring greys one menu row, which is visible, while the
  scheduled channel silently never starts, which is not, and
  `docs/design-decisions.md` ▸ *No distribution channel without
  an update path* calls that failure unrecoverable. **A further
  inverted seam takes the same two-sided guard**, or it is the
  omission risk this rule exists to prevent wearing the other
  polarity.
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

## What a change owes, and what a test must earn to be removed

### Owed

- **A behavior change owes a test that fails without it.** Not a
  test that exercises the new code — one that reds when the
  change is reverted. Those differ more often than they sound.
- **A test whose assertions are new or changed owes a
  `guard-prover` run** before the PR: mutate the thing each one
  watches and watch it fail. Keyed on what the assertions claim
  and on what feeds them, never on their text: renaming or
  reflowing the test itself owes nothing, but a split that
  repoints a test at a different fixture, fake or helper — or a
  rename sweep that moves a scan guard's needle — changes what
  it claims with its bytes untouched — that is how a canary ends up aimed at a
  fixture no longer feeding the consumer. Why the run is owed at
  all is
  [rule-authoring.md](rule-authoring.md)'s ("Prove a new guard
  reds") and is not restated here; what this row adds is *who*
  runs it and *when*.

  The *when* is the change, not the test's shape — guard, canary,
  parity test and plain behavior suite alike — because the bullet
  above cannot stand in for any of them. A
  behavior suite over a fake reds on a reverted change whatever
  its assertions do, so a revert-red proves the test **reads**
  the feature, not that it discriminates the behavior it names.

  What has slipped through that gap here was always a sub-diff
  mutation — the smallest edit that violates the invariant, which
  is what the agent designs for and a revert never is.
  `TeardownRestackTests` shipped a draft that could not tell a
  `return` from a `continue`, and another whose silence passed on
  a run that did nothing; `FullscreenLayoutExemptionTests`'
  fixture never reached the filter term it named;
  `ShortcutsFamilyRowsTests` read a `nil` the same as an empty
  list. `ZOrderSequenceWiringTests` is the outer case — its two
  catches were *production* decisions no unit test could reach,
  found by removing them and watching the whole suite stay green.

  **Spawn it with `isolation: "worktree"`, or run it alone.** It
  breaks working source on purpose, so unisolated it is mutating
  the tree every other agent is reading, and a run that is
  cancelled or dies on a timeout leaves the sabotage behind. The
  obligation is stated here because this row is where a caller
  outside a review round meets it; inside one,
  [the `review-change` skill](../skills/review-change/SKILL.md)
  owns the sequencing and the argument, and
  `.claude/agents/guard-prover.md` owns what the agent itself
  does about it.
- **A perf change owes the correctness half.** A skip, a cache or
  an early return whose safety rests on something else running
  later pins that dependency with a test, never with a comment —
  three prose copies of a promise is three places to forget it,
  not fewer (#662).
- **A default that other tests reason from owes them a pin.** A
  fixture that inherits a default silently re-derives its
  expectations when that default moves. Moving the Space Bar's
  default edge for #660 shifted a stack-resize cliff by exactly
  the bar's thickness, in a suite that pinned the display (#531)
  and not the bar — the strip is carved off the display frame
  before any layout sees it, so pinning one without the other
  buys half a fixture.

### Not owed

- A test per branch of a `switch` the compiler already
  enumerates.
- A test asserting what the type system guarantees.
- A second test of one invariant at another altitude, unless the
  two fail apart — say so in the docstring when they do
  (`AppFontResourceTests`' `kiwiDeskGlyph` asserts the map and
  the font separately because a map can name a ligature the font
  lacks — the suite name is its own span so
  `RuleCitationTests` resolves it).

### Removal

**Runtime is not the criterion, and a test that merely looks
trivial is not a candidate.** A periodic impulse to delete the
sleep-heavy suites is worth resisting once, in writing: a
`Task.sleep` inside a hang-guard costs a passing run nothing (the
poll exits the instant the condition holds — see the async
section below), and where a suite sleeps *deliberately long*, the
gap between a short watchdog and a long sleep **is** the
assertion. `ExecTests`' dedup coverage is the case in point: it
is the only thing holding the #467 contract that caps a wedged
receiver at one stuck child instead of thousands, and its cost is
seconds on a suite already bounded by its slowest suite, not its
sum.

Pure-maths and enum-mapping suites are likewise cheap and are
only "unbreakable" as a claim about today's implementation.

Three questions actually decide it:

1. **Would it have failed on a defect this repo shipped?**
2. **Does anything else watch the same invariant?** A test that
   is the only net is load-bearing however thin it reads.
3. **Does it test the code, or the fixture?** This is the real
   removal criterion and has nothing to do with runtime — a
   classify-change once flipped fixture ownership and left two
   canaries green while testing nothing (#116).

A scan for a **retired** API is not dead-path coverage; it is
what keeps the path retired, and the same holds for the
first-run and managed-config adoption suites — "no user reaches
that phase any more" is precisely why nothing but a test would
notice it breaking.

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

**Where the thing waited on IS an awaitable handle, await it
rather than polling for its effect.** A wall-clock deadline
bounds a hang the test caused *and* starvation it did not: under
a full concurrent run one 10 ms `Task.sleep` resumption measured
65 s (#791), after which the poll exits on a stale deadline
without giving the pending continuation a turn, and the result
comes down to which continuation drains first. Reach for a poll
only when there is nothing to await — a real subprocess
(`ExecTests`), a `DisplayLink` callback (`DragCoordinatorTests`).
When a `Task` or a `DeferredTasks` slot exists, take it:
`await core.deferred.task(for: .startupSweep)?.value`,
`await manager.pendingReplay?.value`. **Expose such a handle with
a doc comment barring production from reading it, and say what it
does NOT mean.** `pendingReplay` is not an in-flight predicate —
the task is never cleared — so awaiting it after a leg that
early-returned awaits the *previous* cycle's finished task and
asserts nothing. A handle whose staleness goes undocumented is a
vacuous await waiting to be written.

The tell that a suite is on the wrong side of this: a green that
takes the *whole* hang guard. `SleepWakeManagerTests` was
reported as failing only while KiwiDesk itself ran, which read as
shared state and was not — it was CPU contention against that
deadline, and no amount of injection-seam hardening would have
touched it. The measurement behind that is argued once, on
`SleepWakeManager.pendingReplay`; do not copy it here.

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
2026-08-17 — a change adding a residue class extends and
re-dates this list in the same change set: throwaway AF_UNIX
sockets under temp paths (`SocketTests`), real `CADisplayLink`s
from animation-keyed suites, repo-script children drained by
`ScriptFixture`, one inert `true` child when
`FirstRunSeedTests`' executed hooks fixture fires, scratch
`UserDefaults` suites cleaned on both sides, one live
`NSEvent.pressedMouseButtons` read —
`MouseFollowsFocusTests` fails if a human holds a mouse button
mid-run — `GeometryUtils.menuBarAutoHides`, a read-only
global-defaults lookup that only reaches fixtures which didn't
pin their bounds, and one read-only `NSScreen.screens` read per
lifecycle suite that drives `EventLoop.beginScan()` with faked
seams (`publishDisplays`; the suites set
`registersWorkspaceObservers = false`, so no live workspace
observer outlives the test), and two read-only console-session
reads (`CGSessionCopyCurrentDictionary`) per
`WakeSessionPresenceWiringTests` run — one in the suite's
`.enabled(if:)` trait and one through the seam it asserts on
(#835), whose docstring owns why a session-less host SKIPs that
suite rather than reds it. **The host text-metric read is
back** — `PresetGridFloorTests` lays out an `NSButton` per
shipped catalog and calls `sizeToFit()`, so a run takes host
font metrics once per catalog per measured key (#862, 2026-08-17).
It replaces the one that had gone away with the sidebar's fixed
label column (#678 turn 9), and it is a deliberate re-admission
rather than a regression: the thing under test IS whether real
translated labels fit a real control, which no fixture can
answer. What it inherits is what #523's fixtures inherited from
`NSScreen` — the host's metrics — so a runner with different
system font metrics measures different widths, and the suite
pins no font of its own. The service tests only parse
`launchctl` strings; nothing spawns it. **Unit tests never need
the running app**; its run state is irrelevant to them.

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
