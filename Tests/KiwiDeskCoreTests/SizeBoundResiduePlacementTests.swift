import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The confirmation EDGE places the residue in its own turn
/// (#677, device QA 2026-08-18), split from
/// `SizeBoundAnswerChannelTests` at the file ceiling when the
/// #1439 probe joined that placement pass. Same fixture, one
/// test.
@Suite("Size-bound residue placement (#677)", .serialized)
@MainActor
struct SizeBoundResiduePlacementTests {
    private let w = WindowID(1)

    /// Captured frame sink — a class so the capture in the
    /// engine's `apply` closure and the suite's reads never
    /// overlap in an exclusivity-checked `inout` (which traps).
    @MainActor
    private final class Applied {
        var frames: [WindowID: CGRect] = [:]
    }

    /// A core with a captured frame pipeline: `animate` is
    /// disabled, so every issued frame lands synchronously in
    /// `applied` — a skipped window simply never appears there.
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

    @Test("A confirmation places the residue in its own turn")
    func confirmPlacesResidueImmediately() throws {
        // The device-QA finding (2026-08-18): learning waited
        // on the NEXT retile, so the re-pack/centering arrived
        // only after "many visits". The confirmation EDGE
        // retiles right then, whichever channel carries it —
        // monocle centers at the confirming observation, not at
        // some later event.
        //
        // Repointed from the echo channel to the settle probe
        // by #1083 (a raw echo no longer promotes). What is
        // unique to this test is the tail: the placement's own
        // echo must not read as a new edge and re-issue. The
        // confirm-and-place half it shares with
        // `settleProbeAnswersSilentRefusal`.
        guard NSScreen.main != nil else { return }
        let applied = Applied()
        let core = makeCore(applied: applied)
        // The severed applier never stamps, so inject the
        // "this is our echo" verdict.
        core.tiler.echoGraceOverride = { _ in true }
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        // Probe 1: ask, then the app's echo seeds the candidate.
        core.retile()
        core.handle(.windowResized(w, refused))
        #expect(core.tiler.sizeBound(for: w) == nil)
        // The confirming observation is the settled read since
        // #1083 — the immediacy this test exists for is
        // unchanged, and it is what the assertions below hold:
        // the confirmation edge places the residue in its OWN
        // turn rather than waiting for a later event.
        core.eventLoop.axReads.reader = { _ in refused }
        core.eventLoop.axReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        core.eventLoop.axReads.dispatchOverride = {
            _,
            work in
            work()
        }
        core.eventLoop.elements[1] = [
            w: AXUIElementCreateSystemWide()
        ]
        applied.frames = [:]
        core.runSizeBoundProbe(w)
        #expect(core.tiler.sizeBound(for: w) != nil)
        let placed = try #require(applied.frames[w])
        // #1439: the placement pass carries the corroboration
        // probe — the residue's origin with the probe's width;
        // the window refuses the width and lands centered.
        #expect(abs(placed.minX - (target.midX - 715 / 2)) < 0.01)
        let probe =
            target.width
            + EffectiveSizeBound.corroborationDistinctness + 1
        #expect(placed.width == probe)
        // The placement's own echo — the app taking the origin
        // and refusing the probe's width — is no new ENTRY: it
        // seeds the probe's candidate and re-asks it once (the
        // #1439 re-issue), nothing else.
        applied.frames = [:]
        core.handle(
            .windowResized(
                w,
                CGRect(
                    origin: placed.origin,
                    size: CGSize(width: 715, height: placed.height)
                )
            )
        )
        #expect(core.tiler.sizeBound(for: w)?.width.count == 1)
        #expect(applied.frames[w]?.width == probe)
    }
}
