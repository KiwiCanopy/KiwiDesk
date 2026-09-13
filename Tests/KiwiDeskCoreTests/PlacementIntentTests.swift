import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An own raise is never a bounce (#1281): `focusOwnWindow` is
/// the door a GUI raise of an own window takes, and it issues
/// the focus command FIRST, so the report that follows is one
/// the distrust never reads (`intended == id`). A CLOSED own
/// window keeps its number and returns without stealing focus
/// (#636), so the door owes it the command and the arrival pays
/// (#1380). The negative controls — the same reports with no
/// intent — are the last cases here and `PlacementBounceTests`'
/// first. The GUI half, the branch that calls the door before
/// `forceFront`, is `SettingsOpenFocusSeamTests`.
@Suite(
    "A placed window the focus command intended (#1281)",
    .serialized
)
@MainActor
struct PlacementIntentTests {
    private final class Log {
        var lines: [String] = []
    }

    /// A frame straddling the screen edge (bounds end at
    /// x = 1440) — the scrolling pan's ask the distrust was
    /// measured against.
    private let offscreen = CGRect(
        x: 1200,
        y: 100,
        width: 400,
        height: 300
    )

    /// Two windows on one scrolling space, `other` focused —
    /// `PlacementBounceTests`' fixture, kept small rather than
    /// shared (§2.4).
    private func makeFixture() -> (
        core: KiwiCore, target: WindowID, other: WindowID
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-placement-intent-\(UUID().uuidString)"
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

    /// Asserted on the LOG, not on state: with `intended == id`
    /// the bounce arm's re-assert would put the same focus back,
    /// so state alone cannot tell honored from bounced.
    @Test("The door's report of a placed window is honored")
    func doorReportIsHonored() {
        let (core, target, _) = makeFixture()
        core.tiler.placements.stamp(target, target: offscreen)
        #expect(core.focusOwnWindow(number: Int(target.raw)))
        // The command's own pan re-stamped it: the ledger is
        // LIVE when the report lands.
        #expect(core.tiler.placements.recent(target) != nil)
        let log = Log()
        core.onLog = { log.lines.append($0) }
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == target)
        #expect(log.lines.contains { $0.contains("w1 (App1) honored") })
        #expect(
            !log.lines.contains {
                $0.contains("placement bounce distrusted")
            }
        )
    }

    /// The door refuses what the distrust's arm would not meet:
    /// a tracked window on another Space (reached by its report)
    /// and the `<= 0` AppKit reports for a window without a
    /// device. An untracked number is owed, never refused (#1380).
    @Test("The door takes a tracked window on the active Space only")
    func doorRefusesTheRest() {
        let (core, target, other) = makeFixture()
        let active = core.state.workspaces.activeSpace
        core.state.workspaces.focus(other, in: active!)
        _ = core.execute("move_to_space", args: [.string("2")])
        #expect(core.state.workspaces.space(of: other) != active)
        #expect(!core.focusOwnWindow(number: Int(other.raw)))
        #expect(core.ownShowFocus.owed() == nil)
        #expect(!core.focusOwnWindow(number: 0))
        #expect(!core.focusOwnWindow(number: -1))
        #expect(core.ownShowFocus.owed() == nil)
        // The bridge's own answer, since through the door an
        // untracked id rescues the sign guard (guard-prover).
        #expect(EventLoop.ownWindowID(number: 0) == nil)
        #expect(EventLoop.ownWindowID(number: -1) == nil)
        #expect(EventLoop.ownWindowID(number: 5) == WindowID(5))
        #expect(core.focusOwnWindow(number: 7))
        #expect(core.ownShowFocus.owed() == WindowID(7))
        _ = target
    }

    /// The device shape (#1380): Settings closed, then reopened
    /// from the menu bar in the active scrolling Space. The
    /// re-shown `NSWindow` keeps its number, so the arrival is a
    /// RETURN into a space whose focus stands — nothing sets
    /// intent, and the report is bounced. The door, told before
    /// the order-front, owes the command; the arrival pays it,
    /// and the report lands with `intended == id`. Asserted on
    /// the log for the reason `doorReportIsHonored` states.
    @Test("A closed window the door was told about is honored at its arrival")
    func closedWindowIsOwedAtArrival() {
        let (core, target, other) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.state.windows[target] == nil)
        #expect(core.activeSpace?.focused == other)
        #expect(core.focusOwnWindow(number: Int(target.raw)))
        #expect(core.ownShowFocus.owed() == target)
        let log = Log()
        core.onLog = { log.lines.append($0) }
        core.handle(.windowCreated(reshown(target)))
        #expect(core.ownShowFocus.owed() == nil)
        #expect(
            log.lines.contains { $0.contains("own show: focus paid to w1") }
        )
        #expect(core.activeSpace?.focused == target)
        // The arrival's retile stamped it: the ledger is LIVE
        // when the report lands.
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == target)
        #expect(log.lines.contains { $0.contains("w1 (App1) honored") })
        #expect(
            !log.lines.contains {
                $0.contains("placement bounce distrusted")
            }
        )
    }

    /// The debt is paid only where the tracked arm would have
    /// taken the window: an arrival off the active Space drops
    /// it, and the report stays the window's own to reach it by.
    @Test("An arrival off the active Space drops the debt")
    func arrivalOffTheActiveSpaceDropsTheDebt() {
        let (core, target, other) = makeFixture()
        let home = core.state.workspaces.space(of: target)!
        core.state.workspaces.focus(target, in: home)
        _ = core.execute("move_to_space", args: [.string("2")])
        core.state.workspaces.focus(other, in: home)
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.focusOwnWindow(number: Int(target.raw)))
        let log = Log()
        core.onLog = { log.lines.append($0) }
        core.handle(.windowCreated(reshown(target)))
        #expect(core.ownShowFocus.owed() == nil)
        #expect(core.state.workspaces.space(of: target) != home)
        #expect(core.activeSpace?.focused == other)
        #expect(
            log.lines.contains { $0.contains("focus debt dropped") }
        )
    }

    @Test("Without the intent the same report is bounced")
    func unintendedReportIsBounced() {
        let (core, target, other) = makeFixture()
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
    }

    /// The #1380 defect itself, kept as the negative control of
    /// `closedWindowIsOwedAtArrival`: the same re-show with the
    /// door never told.
    @Test("Without the door a re-shown window's report is bounced")
    func untoldReshowIsBounced() {
        let (core, target, other) = makeFixture()
        core.handle(.windowDestroyed(target, wasMinimized: false))
        core.handle(.windowCreated(reshown(target)))
        #expect(core.activeSpace?.focused == other)
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
    }

    /// The closed window coming back under its old number, as a
    /// re-shown `NSWindow` does.
    private func reshown(_ id: WindowID) -> ManagedWindow {
        ManagedWindow(
            id: id,
            pid: pid_t(id.raw),
            appName: "App\(id.raw)",
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

}
