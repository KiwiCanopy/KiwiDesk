import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An own raise is never a bounce (#1281): `focusOwnWindow` is
/// the door a GUI raise of an own tracked window takes, and it
/// issues the focus command FIRST, so the report that follows
/// is one the distrust never reads (`intended == id`). The
/// negative control — the same report with no intent — is the
/// last case here and `PlacementBounceTests`' first. The GUI
/// half, the branch that calls the door before `forceFront`, is
/// `SettingsOpenFocusSeamTests`.
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
    /// a window on another Space (reached by its report), an
    /// untracked number, and the `<= 0` AppKit reports for a
    /// window without a device.
    @Test("The door takes a tracked window on the active Space only")
    func doorRefusesTheRest() {
        let (core, target, other) = makeFixture()
        let active = core.state.workspaces.activeSpace
        core.state.workspaces.focus(other, in: active!)
        _ = core.execute("move_to_space", args: [.string("2")])
        #expect(core.state.workspaces.space(of: other) != active)
        #expect(!core.focusOwnWindow(number: Int(other.raw)))
        #expect(!core.focusOwnWindow(number: 7))
        #expect(!core.focusOwnWindow(number: 0))
        #expect(!core.focusOwnWindow(number: -1))
        // The bridge's own answer, since through the door an
        // untracked id rescues the sign guard (guard-prover).
        #expect(EventLoop.ownWindowID(number: 0) == nil)
        #expect(EventLoop.ownWindowID(number: -1) == nil)
        #expect(EventLoop.ownWindowID(number: 5) == WindowID(5))
    }

    @Test("Without the intent the same report is bounced")
    func unintendedReportIsBounced() {
        let (core, target, other) = makeFixture()
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
    }
}
