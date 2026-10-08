import AppKit
import Foundation

@testable import KiwiDeskCore

/// A `HotkeyRegistrar` that touches no OS state (#565) — the
/// GUI-target twin of the Core test target's fake, for suites
/// that don't assert on registration calls.
final class NoopHotkeyRegistrar: HotkeyRegistrar {
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        return nextID
    }

    func unregister(id: UInt32) {}
}

/// GUI-target twin of `Tests/KiwiDeskCoreTests/TestCore.swift` —
/// test targets cannot see each other, so each carries one copy.
/// `MachineTouchTests` pins the two copies to the same
/// neutralization set, and pins every `KiwiCore(` call in the
/// test trees to these two files, so a new suite cannot
/// re-inherit a live production default by forgetting one
/// argument (#565: the live `CarbonHotkeyCenter` seized the
/// developer's global ⌃⌥ chords; a nil `configDirectory`
/// resolves to the real `~/.config/KiwiDesk`).
///
/// Defaults a test must never inherit, all neutralized here:
/// - `hotkeyRegistrar` — no-op, not the live Carbon center.
/// - `configDirectory` — throwaway temp dir, not `~/.config`.
/// - `reduceMotion` — pinned false, not the host's real
///   `NSWorkspace` Reduce-Motion state.
/// - `windowServerTrackingDisabled` — pinned false, not the
///   host's exported `KIWIDESK_NO_WS_TRACKING` QA lever (#596).
/// - `allScreenBounds` — pinned `[]` (the single-screen
///   verdict), not the host's real screen arrangement (#878).
/// - `applier.clock` — frozen, not the host's `systemUptime`,
///   so the echo grace cannot age out under a starved runner
///   (#1456).
/// - `placements.clock` — frozen likewise, so a placement
///   cannot age out of its echo window (#1161).
@MainActor
func makeTestCore(
    configDirectory: URL? = nil,
    hotkeyRegistrar: HotkeyRegistrar = NoopHotkeyRegistrar()
) -> KiwiCore {
    let directory =
        configDirectory
        ?? FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwi-test-\(UUID().uuidString)"
        )
    let core = KiwiCore(
        configDirectory: directory,
        hotkeyRegistrar: hotkeyRegistrar
    )
    core.tiler.animation.reduceMotion = { false }
    // The Monocle flip's own read (#1391), pinned the OTHER way:
    // the flip defers a commanded `focusWindow` to its midpoint,
    // so with it playing every suite that navigates a Monocle
    // Space would read the focus before it landed. A flip suite
    // states the read itself.
    core.monocleFlip.reduceMotion = { true }
    // The plate slide's read (#1956), pinned the same way: a
    // playing slide holds the incoming windows' writes until it
    // lands, which every switching suite would read too early. A
    // slide suite states the read, and keeps the panel and the
    // WindowServer stack read inert, which default live.
    core.spaceSlide.reduceMotion = { true }
    core.spaceSlide.present = { _ in }
    core.spaceSlide.stackOrder = { [:] }
    // The focused ring's arrival hold (#1959) reads the render
    // clock, the host's Reduce Motion and a live timer: frozen and
    // inert here, so ring visibility after a switch never depends
    // on how fast the runner is. An arrival suite steps them.
    core.borders.arrivalClock = { 0 }
    core.borders.scheduleArrivalCheck = { _, _ in }
    core.borders.reduceMotion = { true }
    core.borders.windowServerTrackingDisabled = false
    // A front-order ring reads its target's level from WindowServer
    // on every sync otherwise (#1868).
    core.borders.windowLevel = { _ in nil }
    core.borders.movePanel = { _, _ in false }
    // Every ring would build a real panel, and every sync read
    // its window's corner radius from WindowServer (#1894); a suite
    // testing the panel builds its own manager.
    core.borders.backendFactory = { InertBorderBackend(orderMode: $0) }
    core.borders.readCornerRadius = { _ in nil }
    // `prepare_restart` reads the developer's real LaunchAgent
    // plist otherwise (#930); a suite that means one injects it.
    core.inPlaceRestart.serviceProgram = { nil }
    // The #1385 measurement reads a real user default otherwise,
    // which `defaults write -g` reaches; a suite opts in itself.
    core.crash.restoreKeys.isOptedIn = { false }
    // The snapshot's login-session stamp reads the host's audit
    // session (#1385); a session suite states its own.
    core.crash.loginSession = { 1 }
    // Same class, third time (#673): `openOrFocus`'s four seams
    // default LIVE, and unlike the two above their touch fires on
    // COMMAND EXECUTION, not on init — so a suite that executes
    // `focus_or_spawn` inherits a real `NSWorkspace` lookup, a real
    // `activate()` and a real app launch without naming any of
    // them. That already shipped once: a command-path test brought
    // the real Finder forward on every run. Making "no app is
    // running" the default means the safe state is what a suite
    // gets by forgetting; a test that wants the branch states a
    // pid itself.
    core.openOrFocus.runningAppPID = { _ in nil }
    core.openOrFocus.openApp = { _, _ in false }
    // A Space Bar menu pops modally and would hang the run (#1528).
    core.spaceBars.glyphActions.present = { _, _ in }
    // A hover's dwell would open the peek's panel on a live
    // timer (#1946); a peek suite steps its own.
    core.shelves.peek.schedule = { _, _ in }
    // The hold reads the live pointer (#1946): off every screen.
    core.shelves.peek.pointerOnScreen = { CGPoint(x: -1e6, y: -1e6) }
    // The cool-down is age-bounded (#1456): its clock frozen, as
    // the applier's is; a peek suite moves its own.
    core.shelves.peek.now = { 0 }
    // A bar menu's Quit row terminates a real app (#1518).
    core.shelves.contextMenus.terminateApp = { _ in }
    // New Window activates the target's app and both window
    // actions press another app's AX element (#1518).
    core.openOrFocus.activate = { _ in }
    // Open or Focus's first press asks the app's AX-focused
    // window when nothing is stamped yet (#1840).
    core.eventLoop.shadows.focusedWindow = { _ in nil }
    core.windowActions.newWindow = { _, _ in }
    core.windowActions.close = { _, _ in }
    // The scroll-gesture tap (#1656): a live one would take a
    // real session-wide event tap in any suite that binds a
    // chord. A suite that means the tap injects its own.
    core.mouse.scroll.makeTap = { _ in nil }
    // Same class, fourth time (#878): the per-retile neighbor
    // scan defaults to the real screen list, so on a
    // multi-screen dev Mac an engine fixture would inherit the
    // host's arrangement and wall a scrolling edge that a
    // single-screen CI runner leaves open — the #523 leak, one
    // hook over. Pin the single-screen verdict (no neighbors:
    // every edge open); an adjacency suite injects a fabricated
    // list itself.
    core.tiler.allScreenBounds = { [] }
    // The WindowServer z-order and screen frames the
    // presentation verdict reads (#1787): live, they hand every
    // fixture the host desk.
    core.shelves.frontWindowFrames = { [] }
    core.tiler.allScreenFrames = { [] }
    // Same class, fifth time (#933): the own-key-window seam
    // defaults to a live `NSApplication.shared` read, so a
    // runner that happens to hold a key window would suppress
    // the focused ring in every border suite. Pin "no own key
    // window"; the stand-down suites inject their own reading.
    core.eventLoop.ownKeyWindow = { nil }
    // Same class, again (#1785): the process-table and
    // LaunchServices reads behind the ownership gate and the
    // sibling focus gate default LIVE, and a fixture pid can be a
    // real process on the host. Pin "runs, no record"; the
    // identity suites inject their own readings.
    core.eventLoop.processIdentity.runs = { _ in true }
    core.eventLoop.processIdentity.isActive = { _ in nil }
    core.eventLoop.processIdentity.appAt = { _ in nil }
    // Same class, sixth time (#1146): the compositor reads behind
    // the gone classifier and the away ledger default LIVE, and
    // a fixture id can be a real CGWindowID on the host — one
    // hosted on an unshown Desktop would read `vanished`, file
    // the ledger and arm a live census. Pin "no compositor"; a
    // suite that wants a verdict states it on `desktopMemory`.
    core.desktopMemory.readWindowSpace = { _ in .unavailable }
    core.windowIsOnScreen = { _ in nil }
    core.windowIsOnShownDesktop = { _ in nil }
    core.desktopMemory.readCensus = { _ in nil }
    // Same class, seventh time (#1147): the Desktop stamp write
    // defaults LIVE, and a fixture space id is a real Desktop id
    // on the host — Desktop 1 is id 1 — so any suite that boots a
    // core or switches Desktops would stamp the developer's own
    // Desktops through the real bridge. Pin "the write is
    // refused", which is exactly the bridge-absent host; the
    // stamping suite takes the live writer back explicitly, with
    // the bridge itself faked.
    core.desktopMemory.writeStamp = { _, _ in false }
    // Same class, eighth time (#1103/#1199): the mouse-button
    // read defaults LIVE, and three gesture decisions consult
    // it — the warp gate, `isResizeGesture` and the drag
    // pipeline — so a developer holding a button while the
    // suite ran decided whichever test was running. Pin
    // "nothing held"; a test that wants the branch states the
    // mask itself.
    core.mouse.pressedButtons = { 0 }
    // The motion gate's mouse-quiet read defaults LIVE (#804):
    // pin "the mouse is at rest", so every pass is admitted
    // unless a test states otherwise.
    core.tiler.motionGate.quiescence.sinceMouseMoved = { .infinity }
    // Same class, tenth time (#1532): the reveal-strip read
    // defaults LIVE, so a developer parking the pointer at the
    // top edge with the bar auto-hidden would have every focus
    // suite return foreign reports to an own window. Pin "not in
    // the strip"; the return suite states the reading itself.
    core.mouse.pointerInMenuBarStrip = { false }
    // Same class, process-wide (#1971's flake): every core hears
    // EVERY key-window change in the test process, so another
    // suite's window or post re-synced this one's rings mid-test.
    // Unhook it; `OwnKeyWindowRefreshTests` re-wires explicitly.
    for token in core.borders.ownKeyWindowObservers {
        NotificationCenter.default.removeObserver(token)
    }
    core.borders.ownKeyWindowObservers = []
    // Same class again (#1665): a bar item's hover is re-read from
    // the resting pointer at every shelf relayout, and a fixture's
    // bar sits at the top of the primary screen, where a hand on
    // the menu bar rests. Pin "off every window".
    BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
    // A shelf panel is a real window on the developer's screen,
    // and a core outlives its test while a task still holds it
    // (#1894): placed, never ordered in, unless the suite asks.
    core.shelves.ordersPanels = false
    // The drawn-menu-bar read (#1386) lists the host's real
    // WindowServer windows; a test's displays are fake.
    core.eventLoop.displayWatch.readDrawnMenuBars = { [] }
    // A screen-count change settles on a timer in production
    // (#1612); a fixture's reports are final, so it decides now.
    core.timings.monitorSettleDelay = nil
    // Same class, ninth time (#1103) — but PRECAUTIONARY, not
    // load-bearing like the eighth: `wireDrag` also makes the
    // drop-target cursor read live and a run reaches it, yet no
    // assertion today depends on the value, so no hostile cursor
    // flips a verdict (guard-prover, 2026-09-06). Kept for the
    // next drag test that forgets its own pin, which the two
    // pinning it per file are the precedent for.
    core.drag.cursorLocation = { .zero }
    // The host's CLOCK, not its state: frozen, so the applier's
    // echo grace cannot age a stamp out under a starved runner
    // (#1456, tests.md ▸ age-bounded ledgers).
    core.tiler.applier.clock = { 0 }
    // Same clock class (#1161): the placement ledger's echo
    // window is measured on its own seam; a test wanting the
    // expiry moves this clock ahead.
    core.tiler.placements.clock = { 0 }
    // And the focus-report ledgers' (#1852): a stamp read across
    // a starved runner's second aged out of its echo window.
    let frozen = Date()
    core.wallClock = { frozen }
    // The host's menu-bar setting decides which correction a
    // fixture's usable area takes (#1894): pinned to a drawn bar.
    GeometryUtils.menuBarAutoHidesOverride = false
    // The screen list is a WindowServer round trip on every
    // retile (#1894): read once per process.
    ScreenList.override = {
        if let known = testScreens { return known }
        let live = NSScreen.screens
        testScreens = live
        return live
    }
    // So is the main display's id (#1894): read once per process.
    PositionalDisplays.mainIDOverride = {
        if let known = testMainID { return known }
        let live = DisplayID(CGMainDisplayID())
        testMainID = live
        return live
    }
    // AppKit's screen area is a WindowServer round trip (#1868):
    // read once per screen; the #1386 correction stays live.
    GeometryUtils.appKitVisibleFrameOverride = { screen in
        let key = screen.kiwiDisplayID
        if let key, let known = testAppKitFrames[key] { return known }
        let frame = GeometryUtils.liveAppKitVisibleFrame(of: screen)
        if let key { testAppKitFrames[key] = frame }
        return frame
    }
    return core
}

/// `makeTestCore`'s per-process memo of the screen list.
@MainActor private var testScreens: [NSScreen]?

/// `makeTestCore`'s per-process memo of the main display's id.
nonisolated(unsafe) private var testMainID: DisplayID?

/// `makeTestCore`'s per-process memo of AppKit's screen areas.
@MainActor private var testAppKitFrames: [DisplayID: CGRect] = [:]
