import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)

/// The instant path's commanded frame (#881, owner QA): monocle
/// park's focus switch snaps through `applyInstant`, and the
/// steady-state overlay sync read only the echo-fed state frame
/// — under fast switching the ring trailed a whole switch
/// behind. The commanded target leads while its echo is
/// pending, and the first self-echo retires it so a clamping
/// app's real frame wins the moment reality reports.
@Suite("Instant-set commanded frame (#881)")
struct InstantTargetSyncTests {
    private let spec = CGRect(x: 5, y: 5, width: 400, height: 300)
    private let held = CGRect(x: 9, y: 9, width: 400, height: 300)
    private let target = CGRect(
        x: 200,
        y: 200,
        width: 800,
        height: 600
    )

    @Test("The commanded target leads a steady sync")
    func commandedLeadsWhenQuiet() {
        #expect(
            FollowSource.syncFrame(
                spec: spec,
                held: held,
                animating: false,
                commanded: target
            ) == target
        )
        // No pending command: the echo-fed spec stays the
        // steady-state answer.
        #expect(
            FollowSource.syncFrame(
                spec: spec,
                held: held,
                animating: false,
                commanded: nil
            ) == spec
        )
    }

    @Test("Mid-animation the hold still wins over the command")
    func animationHoldOutranksCommand() {
        // The tick channel owns an animating window's ring; the
        // instant stamp must not fight it (#596's hold).
        #expect(
            FollowSource.syncFrame(
                spec: spec,
                held: held,
                animating: true,
                commanded: target
            ) == held
        )
    }
}

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// The stamp's lifecycle through the engine seams: written at
/// the instant set, read back, and retired by the first
/// self-echo (injected through `echoGraceOverride`, the #677
/// fixture seam — a severed applier writes no real stamp for
/// `askEchoLikely` to read).
@Suite("Instant-target stamp lifecycle (#881)", .serialized)
@MainActor
struct InstantTargetStampTests {
    @Test("setFrame stamps; the first self-echo clears")
    func stampAndEchoClear() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w1, pid: 1, appName: "A")
            )
        )
        let target = CGRect(
            x: 10,
            y: 10,
            width: 500,
            height: 400
        )
        #expect(core.tiler.recentInstantTarget(w1) == nil)
        core.tiler.setFrame(w1, target)
        #expect(core.tiler.recentInstantTarget(w1) == target)
        // The echo of our own set arrives: reality reported,
        // the stamp retires.
        core.tiler.echoGraceOverride = { _ in true }
        core.handle(.windowMoved(w1, target))
        #expect(core.tiler.recentInstantTarget(w1) == nil)
    }
}
