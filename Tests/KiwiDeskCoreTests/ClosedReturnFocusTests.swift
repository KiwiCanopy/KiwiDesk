import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A window returning from a CLOSE takes the focus at its
/// arrival (#1414): the gone handler marks the departure, the
/// create fold reads the mark, and the app's own make-key report
/// then reaches the placement distrust with the focus already
/// intended — measured 3 of 3 bounced in scrolling on the device
/// before this, 0 in bsp. A Desktop return keeps #636's rule; a
/// minimize carries no mark; the mark is consumed on every
/// arrival.
@Suite("A window returning from a close takes the focus (#1414)", .serialized)
@MainActor
struct ClosedReturnFocusTests {
    private final class Log {
        var lines: [String] = []
    }

    private let offscreen = CGRect(
        x: 1200,
        y: 100,
        width: 400,
        height: 300
    )

    /// `PlacementIntentTests`' fixture, kept small rather than
    /// shared (§2.4): two windows on one scrolling space, `other`
    /// focused.
    private func makeFixture() -> (
        core: KiwiCore, target: WindowID, other: WindowID
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-closed-return-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)",
                        frame: CGRect(
                            x: 500 * CGFloat(id - 1),
                            y: 0,
                            width: 400,
                            height: 300
                        )
                    )
                )
            )
        }
        let target = WindowID(1)
        let other = WindowID(2)
        let space = core.state.workspaces.space(of: target)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.tiler.placements = PlacementLedger()
        core.state.workspaces.focus(other, in: space)
        return (core, target, other)
    }

    private func reshown(_ id: WindowID) -> ManagedWindow {
        ManagedWindow(
            id: id,
            pid: pid_t(id.raw),
            appName: "App\(id.raw)",
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    @Test("A closed window re-shown takes the focus; its report is honored")
    func closedReturnTakesFocus() {
        let (core, target, other) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        // The gone handler classified a close and marked it —
        // fail-open guard for every clause below.
        #expect(core.state.closedDepartures[target] != nil)
        #expect(core.activeSpace?.focused == other)
        let log = Log()
        core.onLog = { log.lines.append($0) }
        core.handle(.windowCreated(reshown(target)))
        #expect(core.activeSpace?.focused == target)
        #expect(
            log.lines.contains {
                $0.contains("close return: w1 re-shown — focus taken")
            }
        )
        // Consumed by the arrival.
        #expect(core.state.closedDepartures[target] == nil)
        // The arrival's retile stamped it; the report still
        // lands intended — asserted on the log, since with
        // `intended == id` the bounce's re-assert would put the
        // same focus back and state alone cannot tell.
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(log.lines.contains { $0.contains("w1 (App1) honored") })
        #expect(
            !log.lines.contains {
                $0.contains("placement bounce distrusted")
            }
        )
    }

    @Test("A window that left with its Desktop steals nothing at its return")
    func vanishedReturnStealsNothing() {
        let (core, target, other) = makeFixture()
        // Inside the switch settle the #40 timer reads the
        // departure as `vanished` (no compositor answer in a
        // fixture) — the Desktop-departure class.
        core.lastDesktopSwitch = Date()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.state.closedDepartures[target] == nil)
        core.handle(.windowCreated(reshown(target)))
        #expect(core.activeSpace?.focused == other)
    }

    @Test("A minimize carries no close mark")
    func minimizeCarriesNoMark() {
        let (core, target, _) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: true))
        #expect(core.state.closedDepartures[target] == nil)
    }

    @Test("A return off the active Space steals nothing")
    func inactiveSpaceReturnStealsNothing() {
        let (core, target, other) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.state.closedDepartures[target] != nil)
        // The user is elsewhere when the window comes back to
        // its remembered Space: the grant is the active Space's
        // only, like a new window's.
        let elsewhere = SpaceID("2")
        core.state.workspaces.ensureSpace(elsewhere)
        core.state.workspaces.activate(elsewhere)
        #expect(core.state.workspaces.activeSpace == elsewhere)
        core.handle(.windowCreated(reshown(target)))
        #expect(core.state.workspaces.space(of: target) == SpaceID("1"))
        #expect(core.state.workspaces[SpaceID("1")]?.focused == other)
        // Consumed all the same.
        #expect(core.state.closedDepartures[target] == nil)
    }

    @Test("The mark rides a re-key with the departed memory")
    func markFollowsRekey() {
        let (core, target, _) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.state.closedDepartures[target] != nil)
        let new = WindowID(9)
        core.state.rekey(target, to: new)
        #expect(core.state.closedDepartures[target] == nil)
        #expect(core.state.closedDepartures[new] != nil)
    }
}
