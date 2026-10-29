import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The brief pocket (#2680): pocketing and taking out play it under
/// `on_state_change` and never under Reduce Motion; the window parks
/// at once, and a take-out's one write waits for the plate to land.
/// Its placement settings, `pocket.edge` and `pocket.position`.
@Suite("Brief pocket", .serialized)
@MainActor
struct BriefPocketTests {
    private let one = WindowID(1)
    private let three = WindowID(3)

    private func makeCore(plays: Bool = true) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-brief-pocket-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.briefPocket.reduceMotion = { !plays }
        core.briefPocket.present = { _ in }
        core.briefPocket.makeFrames = { _, _ in nil }
        // An element and an inert writer, so a held write stays
        // staged rather than dropped for want of one.
        let element = AXUIElementCreateApplication(1)
        core.tiler.applier.elementProvider = { _ in element }
        core.tiler.applier.writer = FrameWriter(
            setFrame: { _, _ in },
            setPosition: { _, _ in },
            writeEUI: { _, _ in }
        )
        for raw: UInt32 in [1, 2, 3] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_001,
                        appName: "App\(raw)",
                        frame: CGRect(
                            x: 100,
                            y: 100,
                            width: 600,
                            height: 400
                        )
                    )
                )
            )
        }
        core.focusWindow(one, warp: false)
        return core
    }

    /// Counts animated applies of the window from here on.
    private func countApplies(_ core: KiwiCore) -> () -> Int {
        core.tiler.animation.isEnabled = false
        var applies = 0
        core.tiler.animation.apply = { id, _, _ in
            if id == WindowID(1) { applies += 1 }
        }
        return { applies }
    }

    @Test("pocketing plays the pocket and parks the window at once")
    func pocketingPlays() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        let applies = countApplies(core)
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketedWindows == [one])
        #expect(core.briefPocket.isPlaying)
        #expect(applies() == 0)
    }

    /// The play takes the stored placement and the gated looks.
    @Test("the play wears the stored placement and the gated looks")
    func requestWiring() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        // Reduce transparency on, glass stored on: the gated looks
        // differ from the stored ones.
        let gate = LiquidGlassGate.override
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = gate }
        core.tiler.settings.kiwishelf.liquidGlass = true
        core.tiler.settings.shortcutPanelLiquidGlass = true
        core.tiler.settings.kiwishelf.pocketEdge = .right
        core.tiler.settings.kiwishelf.pocketPosition = 30
        core.tiler.settings.kiwishelf.outerMargin = 8
        #expect(core.execute("pocket").isSuccess)
        let request = try #require(core.briefPocket.playing)
        // The one door for where the pocket is (#2678 review 5)…
        #expect(request.pocket == core.pocketLanding(on: request.display))
        // …at the stored placement: risen out of the right edge,
        // 30 % down it.
        let visible = GeometryUtils.axVisibleFrame(of: request.screen)
        let rise = KiwiCore.pocketRiseSide(
            thickness: core.tiler.settings.kiwishelf.thickness
        )
        // One outer margin in from the edge, as the bars' handles.
        let outer = core.tiler.settings.kiwishelf.outerMargin
        let band = KiwiCore.pocketHandleFrame(
            visible: visible,
            edge: .right,
            position: 30,
            depth: outer + PocketHandleView.tabDepth
                + PocketPlateView.lift + rise
        )
        let risen = PocketPlateView.risenFrame(
            in: PocketPlateView.room(in: band, edge: .right, outer: outer),
            edge: .right,
            side: rise
        )
        #expect(request.pocket == risen)
        // Risen out of its handle, the pocket wears no plate.
        #expect(!request.platePiece)
        let settings = core.tiler.settings
        #expect(request.shelf != settings.kiwishelf)
        #expect(request.shelf == LiquidGlassGate.rendered(settings.kiwishelf))
        #expect(!request.plateGlass)
    }

    @Test("taking out plays the pocket and holds the one write")
    func takeOutPlaysAndHolds() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        #expect(core.execute("pocket").isSuccess)
        core.briefPocket.end()
        let applies = countApplies(core)
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketedWindows.isEmpty)
        #expect(core.briefPocket.isPlaying)
        #expect(core.tiler.applier.held.isHeld(one))
        // The restore's one write is staged, not sent ahead of it.
        #expect(core.tiler.applier.held.isStaged(one))
        // Its ring waits with it, and lets go at the landing.
        #expect(core.borders.stateChange?.window == one)
        core.borders.stateChangeSettled(one)
        core.borders.noteStateChangeReport(
            one,
            frame: core.tiler.commandedFrame(of: one) ?? .zero
        )
        #expect(core.borders.stateChange == nil)
        #expect(applies() == 0)
    }

    @Test("off under the toggle or Reduce Motion: nothing plays or holds")
    func gated() {
        guard NSScreen.main != nil else { return }
        for (toggle, plays) in [(false, true), (true, false)] {
            let core = raisingCore(plays: plays)
            core.tiler.settings.animations.onStateChange = toggle
            #expect(core.execute("pocket").isSuccess)
            #expect(!core.briefPocket.isPlaying)
            // Nothing plays, so nothing waits: the raise is now.
            let next = core.state.workspaces.lastFocused
            #expect(next != nil && next != one)
            #expect(next.map { raised(core, $0) } == true)
            #expect(core.execute("pocket").isSuccess)
            #expect(!core.briefPocket.isPlaying)
            #expect(!core.tiler.applier.held.isHeld(one))
            #expect(raised(core, one))
        }
    }

    /// #2703: a raise mid-play activates an app on the thread the
    /// plate's frames tick on, so it waits for the play to end.
    /// Read off the raise's own stamp: state focus moves at once.
    @Test("pocketing raises the next window once the play ends")
    func putInRaiseWaits() async {
        guard NSScreen.main != nil else { return }
        let core = raisingCore()
        core.deferred.sleep = { _ in }
        #expect(core.execute("pocket").isSuccess)
        #expect(core.briefPocket.isPlaying)
        let next = core.activeSpace?.focused
        #expect(next != nil && next != one)
        #expect(next.map { !raised(core, $0) } == true)
        await core.deferred.task(for: .pocketFocus)?.value
        #expect(next.map { raised(core, $0) } == true)
    }

    @Test("taking out raises the window once the play ends")
    func takeOutRaiseWaits() async {
        guard NSScreen.main != nil else { return }
        let core = raisingCore()
        core.deferred.sleep = { _ in }
        #expect(core.execute("pocket").isSuccess)
        await core.deferred.task(for: .pocketFocus)?.value
        core.briefPocket.end()
        #expect(core.execute("pocket").isSuccess)
        #expect(!raised(core, one))
        await core.deferred.task(for: .pocketFocus)?.value
        #expect(raised(core, one))
    }

    @Test("a press before the play ends takes the waiting hand-off over")
    func secondPressReplaces() async {
        guard NSScreen.main != nil else { return }
        let core = raisingCore()
        core.deferred.sleep = { _ in }
        #expect(core.execute("pocket").isSuccess)
        let next = core.activeSpace?.focused
        let first = core.deferred.task(for: .pocketFocus)
        #expect(core.execute("pocket").isSuccess)
        await first?.value
        await core.deferred.task(for: .pocketFocus)?.value
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(raised(core, one))
        #expect(next.map { !raised(core, $0) } == true)
        // State focus moved at the put-in, so it came out over it.
        #expect(next != nil && core.state.pocket.first?.cameFrom == next)
    }

    /// The window it came out over is not the Space's successor,
    /// the last window of the row once the pocket window joined it:
    /// state focus goes there at the press, so the pass pans to it.
    @Test("pocketing moves state focus to where it came out at once")
    func stateFocusLeadsTheRaise() async {
        guard NSScreen.main != nil else { return }
        let core = raisingCore()
        let two = WindowID(2)
        core.deferred.sleep = { _ in }
        #expect(core.execute("pocket").isSuccess)
        await core.deferred.task(for: .pocketFocus)?.value
        core.briefPocket.end()
        core.focusWindow(two, warp: false)
        #expect(core.execute("pocket").isSuccess)
        await core.deferred.task(for: .pocketFocus)?.value
        core.briefPocket.end()
        #expect(core.state.pocket.first?.cameFrom == two)
        #expect(core.activeSpace?.windows.last == one)
        core.selfRaiseStamps = [:]
        #expect(core.execute("pocket").isSuccess)
        #expect(core.focusedWindowID == two)
        #expect(!raised(core, two))
        core.eventLoop.lastCommandedFocus = nil
        await core.deferred.task(for: .pocketFocus)?.value
        #expect(raised(core, two))
        // Told what it leaves, the raise counts as a commanded focus
        // change (#1088), as the immediate hand-off did.
        #expect(core.eventLoop.lastCommandedFocus != nil)
    }

    @Test("a focus moved before the play ends keeps its window")
    func movedFocusDrops() async {
        guard NSScreen.main != nil else { return }
        let core = raisingCore()
        core.deferred.sleep = { _ in }
        #expect(core.execute("pocket").isSuccess)
        await core.deferred.task(for: .pocketFocus)?.value
        core.briefPocket.end()
        // Every slot the focus below schedules waits on it too.
        let flight = Flight()
        core.deferred.sleep = { _ in
            while !flight.landed { await Task.yield() }
        }
        #expect(core.execute("pocket").isSuccess)
        let landing = core.deferred.task(for: .pocketFocus)
        // The user moves on while the pocket still plays.
        core.focusWindow(three, warp: false)
        core.selfRaiseStamps[one] = nil
        flight.landed = true
        await landing?.value
        #expect(core.focusedWindowID == three)
        #expect(!raised(core, one))
    }

    @Test("a Space switch before the play ends drops the raise")
    func movedSpaceDrops() async {
        guard NSScreen.main != nil else { return }
        let core = raisingCore()
        let flight = Flight()
        core.deferred.sleep = { _ in
            while !flight.landed { await Task.yield() }
        }
        #expect(core.execute("pocket").isSuccess)
        let next = core.activeSpace?.focused
        let landing = core.deferred.task(for: .pocketFocus)
        #expect(
            core.execute("focus_space", args: [.string("9")]).isSuccess
        )
        core.selfRaiseStamps = [:]
        flight.landed = true
        await landing?.value
        #expect(next.map { !raised(core, $0) } == true)
    }

    /// A core whose windows have elements, so a raise is stamped.
    private func raisingCore(plays: Bool = true) -> KiwiCore {
        let core = makeCore(plays: plays)
        let element = AXUIElementCreateSystemWide()
        core.eventLoop.elements[900_001] = [
            one: element, WindowID(2): element, three: element,
        ]
        return core
    }

    private func raised(_ core: KiwiCore, _ id: WindowID) -> Bool {
        core.selfRaiseStamps[id] != nil
    }

    private final class Flight: @unchecked Sendable {
        var landed = false
    }
}
