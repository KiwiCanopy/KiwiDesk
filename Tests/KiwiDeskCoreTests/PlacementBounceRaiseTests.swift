import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-placement-raise-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

/// Two windows on one scrolling space, `other` focused, the
/// ledger cleared after the mode's retile — the
/// `PlacementBounceTests` fixture, per-file by convention.
@MainActor
private func makeFixture(
    _ core: KiwiCore,
    mode: String = "scrolling"
) -> (target: WindowID, other: WindowID) {
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
        args: [.string(space.raw), .string(mode)]
    )
    core.tiler.placements = PlacementLedger()
    core.state.workspaces.focus(other, in: space)
    return (target, other)
}

/// Wholly on screen (bounds start at y = 25, end at x = 1440) at
/// the window's own 400 × 300, so neither geometric arm fires
/// and only the raise reading can — a placement AT the state
/// frame would straddle the top edge and pass on the edge arm.
private let complied = CGRect(x: 800, y: 100, width: 400, height: 300)

/// Older than `selfRaiseEchoWindow`, younger than the placement
/// window — the emulator's last echo of a step onto it (device,
/// 2026-09-05 19:25, at +1.28 s).
@MainActor
private var lateEcho: TimeInterval {
    -(KiwiCore.selfRaiseEchoWindow + PlacementLedger.echoWindow) / 2
}

@MainActor
private func focused(_ core: KiwiCore) -> WindowID? {
    core.activeSpace?.focused
}

/// The scrolling arm's third disjunct (#1161): a step onto a
/// window and off again leaves it placed on-screen, complying,
/// and RAISED by us — and the emulator's last echo of that raise
/// lands past the 1 s self-echo window. Inside the placement
/// window, our own raise is the discriminator.
@Suite("Placement bounce — the raise reading (#1161)", .serialized)
@MainActor
struct PlacementBounceRaiseTests {
    @Test("A late echo of our raise on a complied placement bounces")
    func lateEchoOfOurRaiseIsDistrusted() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        core.tiler.placements.stamp(target, target: complied)
        core.selfRaiseStamps[target] = Date(
            timeIntervalSinceNow: lateEcho
        )
        #expect(!core.freshSelfRaise(target, now: Date()))
        core.handle(.windowFocused(target))
        #expect(focused(core) == other)
    }

    @Test("Our raise past the placement window is honored")
    func raisePastThePlacementWindowIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.stamp(target, target: complied)
        core.selfRaiseStamps[target] = Date(
            timeIntervalSinceNow: -PlacementLedger.echoWindow - 0.1
        )
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    /// A raise with no placement beside it is the #887 duplicate
    /// echo, ruled by the 1 s window alone — the reading does not
    /// widen that.
    @Test("Our raise without a placement is honored")
    func raiseWithoutAPlacementIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.selfRaiseStamps[target] = Date(
            timeIntervalSinceNow: lateEcho
        )
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    /// Outside scrolling a clickless focus is how a parked window
    /// is REACHED; the raise reading is the scrolling arm's only.
    @Test("Outside scrolling our raise does not bounce")
    func raiseOutsideScrollingIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core, mode: "monocle")
        core.tiler.placements.stamp(target, target: complied)
        core.selfRaiseStamps[target] = Date(
            timeIntervalSinceNow: lateEcho
        )
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    @Test("A click on the raised window escapes")
    func clickEscapes() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.stamp(target, target: complied)
        core.selfRaiseStamps[target] = Date(
            timeIntervalSinceNow: lateEcho
        )
        core.lastLeftClick = (Date(), CGPoint(x: 10, y: 10), target)
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    /// The writer retains a stamp for the PLACEMENT window: a
    /// second step between the raise and its late echo must not
    /// prune the stamp the echo is told by.
    @Test("The writer retains stamps for the placement window")
    func writerRetainsThePlacementWindow() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        let now = Date()
        core.selfRaiseStamps[target] = now.addingTimeInterval(lateEcho)
        core.stampSelfRaise(other, now: now)
        #expect(core.selfRaiseStamps[target] != nil)
        #expect(core.selfRaiseStamps[other] == now)
        core.selfRaiseStamps[target] = now.addingTimeInterval(
            -PlacementLedger.echoWindow - 0.1
        )
        core.stampSelfRaise(other, now: now)
        #expect(core.selfRaiseStamps[target] == nil)
    }
}
