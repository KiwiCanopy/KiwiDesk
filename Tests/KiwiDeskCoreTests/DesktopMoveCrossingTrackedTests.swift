import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `DesktopMoveCrossingTests`' second half (#3048): the read-back of
/// a written frame, and a tracked window's write at its departure.
/// Split at the §2.1 ceiling, over a copy of that suite's fixture.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite(
    "Desktop move across screens: read-back and tracked (#3048)",
    .serialized
)
@MainActor
struct DesktopMoveCrossingTrackedTests {
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

    // MARK: - The read-back

    private func landedCore(_ writes: Writes) throws -> KiwiCore {
        let core = try makeCore(writes)
        fileAway(core)
        _ = moveAway(core)
        writes.answers[0](true)
        return core
    }

    @Test("a frame that did not land resends once, then only logs")
    func missResendsOnce() throws {
        let writes = Writes()
        let core = try landedCore(writes)
        defer { teardown() }
        writes.fire(after: KiwiCore.crossingCheckDelay)
        #expect(writes.sent.count == 2)
        writes.answers[1](true)
        writes.fire(after: KiwiCore.crossingCheckDelay)
        #expect(writes.sent.count == 2)
        _ = core
    }

    @Test("a frame that landed is left alone")
    func hitResendsNothing() throws {
        let writes = Writes()
        let core = try landedCore(writes)
        defer { teardown() }
        let written = try #require(writes.sent.first?.1)
        core.windowServer.readWindowBounds = { _ in written }
        writes.fire(after: KiwiCore.crossingCheckDelay)
        #expect(writes.sent.count == 1)
    }

    /// The layout owns the frame then, so a resend would undo it.
    @Test("an arrived window is never resent")
    func arrivedStandsDown() throws {
        let writes = Writes()
        let core = try landedCore(writes)
        defer { teardown() }
        core.state.awayWindows[away] = nil
        writes.fire(after: KiwiCore.crossingCheckDelay)
        #expect(writes.sent.count == 1)
    }

    // MARK: - A tracked window

    private func track(_ core: KiwiCore) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: tracked,
                    pid: pid,
                    appName: "Here",
                    frame: offScreen
                )
            )
        )
        let origin = core.state.workspaces.space(of: tracked)!
        core.state.workspaces.assign(origin, to: elsewhere)
        core.eventLoop.elements[pid] = [
            tracked: AXUIElementCreateApplication(pid)
        ]
    }

    private func departTracked(_ core: KiwiCore) {
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        core.eventLoop.releaseWindowRegistration(tracked, pid: pid)
        core.handle(.windowDestroyed(tracked, wasMinimized: false))
    }

    @Test("a tracked window writes at its departure, not at the command")
    func trackedWritesAtTheDeparture() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        track(core)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [
                    .number(2), .string("mail"),
                    .number(Double(tracked.raw)),
                ]
            ).isSuccess
        )
        #expect(DesktopVerbBridge.moves.count == 1)
        #expect(writes.sent.isEmpty)
        departTracked(core)
        #expect(writes.sent.map(\.0) == [tracked])
        #expect(core.state.rememberedSpace(of: tracked) == mail)
    }

    @Test("a tracked window with no element is refused")
    func trackedNoElementRefuses() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        track(core)
        core.eventLoop.elements[pid] = nil
        #expect(
            core.execute(
                "move_to_desktop",
                args: [
                    .number(2), .string("mail"),
                    .number(Double(tracked.raw)),
                ]
            ).error?.contains("cross screens") == true
        )
    }

    /// `departEagerly` folds ahead of its release, so it notes the
    /// element itself or a follow keeps nothing and writes nothing.
    @Test("a follow keeps the element and writes in the switch's turn")
    func followWritesInItsTurn() throws {
        let writes = Writes()
        let core = try makeCore(writes)
        defer { teardown() }
        track(core)
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [
                    .number(2), .string("mail"),
                    .number(Double(tracked.raw)),
                ]
            ).isSuccess
        )
        #expect(writes.sent.map(\.0) == [tracked])
    }
}
