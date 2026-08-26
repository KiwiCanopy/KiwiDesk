import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The comply-then-snap-back app class end to end (#1049): the
/// Android emulator performs the full asked size, holds it, then
/// snaps back to its aspect ratio — two echoes per probe cycle,
/// a transient compliance before the real refusal. The event
/// flow must let the ladder confirm across that pair instead of
/// wiping it, and the confirmed bound must end the re-issue.
/// The pure compliance rule is `SizeBoundInvalidationTests`';
/// this suite proves the echo channels thread it.
@Suite(
    "Size-bound transient compliance (#1049)",
    .serialized
)
@MainActor
struct SizeBoundTransientComplianceTests {
    private let w = WindowID(1)

    @MainActor
    private final class Applied {
        var frames: [WindowID: CGRect] = [:]
    }

    private func makeCore(applied: Applied) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied.frames[id] = frame
        }
        core.state.workspaces.setMode(SpaceID(1), .monocle)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w, pid: 1, appName: "App")
            )
        )
        return core
    }

    @Test("The snap-back pattern confirms and stops the dance")
    func snapBackConfirmsAndStops() throws {
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        // The severed applier never stamps; every echo below is
        // "ours".
        core.tiler.echoGraceOverride = { _ in true }
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let snapped = CGRect(
            origin: target.origin,
            size: CGSize(width: 439, height: target.height)
        )
        // Cycle 1: ask, the transient compliance echo, then the
        // snap-back. The compliance must not wipe the fresh
        // ladder — pre-#1049 it did, and the candidate re-seeded
        // here every ~0.85 s forever.
        core.retile()
        core.handle(.windowResized(w, target))
        core.handle(.windowResized(w, snapped))
        // The first refusal's probe re-asked by itself
        // (`observeSizeAnswer`); cycle 2 answers it the same
        // way and must confirm.
        core.handle(.windowResized(w, target))
        core.handle(.windowResized(w, snapped))
        #expect(
            core.tiler.sizeBound(for: w)?
                .consumedWidth(asking: target.width) == 439
        )
        // The dance is over: with the bound believed and the
        // window at the learned answer, a further retile
        // re-issues nothing (monocle centers the residue, so
        // the window sits at the centered slot).
        let centered = try #require(applied.frames[w])
        #expect(abs(centered.midX - target.midX) < 0.01)
        core.state.apply(.windowResized(w, centered))
        applied.frames = [:]
        core.retile()
        #expect(applied.frames[w] == nil)
    }
}
