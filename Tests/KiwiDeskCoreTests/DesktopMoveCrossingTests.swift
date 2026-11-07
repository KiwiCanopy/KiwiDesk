import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop move across screens on shared Desktops (#3048), through
/// the real dispatch: the frame write ahead of an away window's move,
/// a tracked window's write at its departure, and the read-back. The
/// named Space lays out on the host's real screen, since the frame is
/// derived from an `NSScreen`; the window's own Space on another.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move across screens, shared Desktops (#3048)", .serialized)
@MainActor
struct DesktopMoveCrossingTests {
    private let away = WindowID(9)
    private let tracked = WindowID(7)
    private let pid: pid_t = 900_001
    private let mail = SpaceID("mail")
    private let elsewhere = DisplayID(UInt32.max)
    private var awayID: JSONValue { .number(Double(away.raw)) }
    private let offScreen = CGRect(x: 90_000, y: 0, width: 400, height: 300)

    private final class Writes {
        var sent: [(WindowID, CGRect)] = []
        var answers: [(Bool) -> Void] = []
        var timers: [(TimeInterval, () -> Void)] = []

        func fire(after delay: TimeInterval) {
            let due = timers.filter { $0.0 == delay }
            timers.removeAll { $0.0 == delay }
            due.forEach { $0.1() }
        }
    }

    private func makeCore(_ writes: Writes) throws -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = [
            authoritySpace(10, display: "Main", current: true),
            authoritySpace(11, display: "Main"),
            authoritySpace(12, display: "Main"),
        ]
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { desktopVerbBridgeClasses[$0] }
        let core = makeTestCore()
        let shown = try #require(ScreenList.all.first?.kiwiDisplayID)
        for (id, name) in [(shown, "A"), (elsewhere, "B")] {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: id,
                    name: name,
                    frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
                )
            )
        }
        core.state.workspaces.assign(mail, to: shown)
        core.state.workspaces.assign("1", to: elsewhere)
        core.windowServer.readWindowBounds = { [offScreen] _ in offScreen }
        core.awayFrameWrite = { id, frame, _, _, landed in
            writes.sent.append((id, frame))
            writes.answers.append(landed)
        }
        core.desktopMemory.scheduleCrossing = { delay, work in
            writes.timers.append((delay, work))
        }
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// An away window on hidden Desktop 2, its element kept.
    private func fileAway(_ core: KiwiCore, element: Bool = true) {
        core.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: pid,
            appName: "Away",
            appBundleID: "com.example.away",
            title: "Elsewhere",
            nativeSpace: 11
        )
        core.state.rememberedSpaces[away] = .departed("1")
        guard element else { return }
        core.eventLoop.awayElements.noteRelease(
            away,
            AXUIElementCreateApplication(pid)
        )
        core.eventLoop.awayElements.keep(
            away,
            away: Set(core.state.awayWindows.keys)
        )
    }

    private func moveAway(
        _ core: KiwiCore,
        to desktop: Double = 3,
        verb: String = "move_to_desktop"
    ) -> CommandResponse {
        core.execute(verb, args: [.number(desktop), .string("mail"), awayID])
    }

    @Test("an away window moves only once its frame is written")
    func frameLandsBeforeTheMove() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        #expect(moveAway(core).isSuccess)
        #expect(writes.sent.count == 1)
        #expect(DesktopVerbBridge.moves.isEmpty)
        #expect(core.state.rememberedSpace(of: away) != mail)
        writes.answers[0](true)
        #expect(DesktopVerbBridge.moves.count == 1)
        #expect(core.state.rememberedSpace(of: away) == mail)
    }

    @Test("the frame sits on the named Space's screen")
    func frameIsOnTheSpacesScreen() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        _ = moveAway(core)
        let screen = try #require(ScreenList.all.first)
        let dest = GeometryUtils.axVisibleFrame(of: screen)
        let frame = try #require(writes.sent.first?.1)
        #expect(dest.contains(frame))
        #expect(frame.size == offScreen.size)
    }

    @Test("a window larger than the target screen is fitted to it")
    func oversizedIsFitted() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        let screen = try #require(ScreenList.all.first)
        let dest = GeometryUtils.axVisibleFrame(of: screen)
        let huge = CGRect(
            x: 90_000,
            y: 0,
            width: dest.width * 2,
            height: dest.height * 2
        )
        core.windowServer.readWindowBounds = { _ in huge }
        _ = moveAway(core)
        let frame = try #require(writes.sent.first?.1)
        #expect(frame.width == dest.width)
        #expect(frame.height == dest.height)
        #expect(dest.contains(frame))
    }

    /// A parked window's WindowServer frame is the stash corner.
    @Test("a parked float carries its capture, and the capture ends")
    func parkedCarriesTheCapture() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        let capture = CGRect(x: 90_000, y: 0, width: 640, height: 480)
        core.tiler.seedStash(away, frame: capture)
        _ = moveAway(core)
        let frame = try #require(writes.sent.first?.1)
        #expect(frame.size == capture.size)
        #expect(core.tiler.stashOriginal(away) == capture)
        writes.answers[0](true)
        #expect(core.tiler.stashOriginal(away) == nil)
    }

    @Test("an app that stalls is passed at the deadline, once")
    func stalledAppMovesAtTheDeadline() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        _ = moveAway(core)
        #expect(DesktopVerbBridge.moves.isEmpty)
        writes.fire(after: KiwiCore.crossingWriteDeadline)
        #expect(DesktopVerbBridge.moves.count == 1)
        writes.answers[0](true)
        #expect(DesktopVerbBridge.moves.count == 1)
    }

    /// The command answered before the move, so a second press would
    /// start a second write and a second move of one window.
    @Test("a second move while the first is landing is refused")
    func repeatWhileLandingRefuses() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        _ = moveAway(core)
        #expect(moveAway(core).error?.contains("still moving") == true)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(2), .string(""), awayID]
            )
            .error?.contains("still moving") == true
        )
        #expect(writes.sent.count == 1)
        #expect(DesktopVerbBridge.moves.isEmpty)
        writes.answers[0](true)
        #expect(DesktopVerbBridge.moves.count == 1)
        // Filed under `mail` now, so the next move crosses nothing.
        #expect(moveAway(core).isSuccess)
        #expect(DesktopVerbBridge.moves.count == 2)
    }

    @Test("an element naming another window moves nothing")
    func staleElementMovesNothing() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        _ = moveAway(core)
        writes.answers[0](false)
        #expect(DesktopVerbBridge.moves.isEmpty)
        #expect(moveAway(core).isSuccess)
        #expect(core.state.rememberedSpace(of: away) != mail)
    }

    /// The window was pocketed, say, while its frame was written.
    @Test("a window refused by the time its frame lands is not moved")
    func refusedAtTheLandingMovesNothing() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        _ = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(3), .string("mail"), awayID]
        )
        core.state.awayWindows[away]?.isUp = false
        writes.answers[0](true)
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    @Test("a follow answers switched, and switches after the write")
    func followSwitchesAfterTheWrite() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        let response = moveAway(core, verb: "move_to_desktop_and_follow")
        #expect(response.isSuccess)
        #expect(response == .ok(.object(["switched": .bool(true)])))
        #expect(DesktopVerbBridge.switches.isEmpty)
        writes.answers[0](true)
        #expect(DesktopVerbBridge.moves.count == 1)
        #expect(DesktopVerbBridge.switches.count == 1)
    }

    @Test("a shown Desktop crosses by the same write")
    func shownDesktopCrosses() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        #expect(moveAway(core, to: 1).isSuccess)
        #expect(writes.sent.count == 1)
    }

    @Test("a window with no element, or not up, is refused")
    func unwritableRefuses() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core, element: false)
        #expect(moveAway(core).error?.contains("cross screens") == true)
        fileAway(core)
        core.state.awayWindows[away]?.isUp = false
        #expect(moveAway(core).error?.contains("cross screens") == true)
        #expect(writes.sent.isEmpty)
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    /// A Space on the window's own screen writes nothing.
    @Test("no crossing, no write")
    func sameScreenWritesNothing() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        fileAway(core)
        core.state.workspaces.assign(mail, to: elsewhere)
        #expect(moveAway(core).isSuccess)
        #expect(writes.sent.isEmpty)
        #expect(DesktopVerbBridge.moves.count == 1)
    }
}
