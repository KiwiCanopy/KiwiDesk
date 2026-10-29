import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An issued corroboration probe survives the placement pass its
/// own confirmation raises (#2758): that pass re-asks the anchor's
/// answer in the same slot before the app has answered the probe,
/// and superseding the probe there left the bound uncorroborated
/// for good. The probe's ladder is
/// `SizeBoundCorroborationProbeEngineTests`; this suite is the
/// hold through the engine, `SizeBoundProbeHoldTests` its
/// bookkeeping. Needs a screen: a headless host SKIPS it.
@Suite(
    "Size-bound probe in flight (#2758)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct SizeBoundProbeInFlightTests {
    private let w = WindowID(1)

    @MainActor
    private final class Captured {
        var frames: [WindowID: CGRect] = [:]
    }

    /// The engine suite's fixture: one monocle window, a captured
    /// frame pipeline with animation off.
    private func makeCore(captured: Captured) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            captured.frames[id] = frame
        }
        core.state.workspaces.setMode(SpaceID(1), .monocle)
        core.state.apply(
            .windowCreated(ManagedWindow(id: w, pid: 1, appName: "App"))
        )
        return core
    }

    private func wireSettledRead(
        _ core: KiwiCore,
        returning frame: CGRect
    ) {
        core.eventLoop.axReads.reader = { _ in frame }
        core.eventLoop.axReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        core.eventLoop.axReads.dispatchOverride = { _, work in
            work()
        }
        core.eventLoop.elements[1] = [
            w: AXUIElementCreateSystemWide()
        ]
    }

    /// Confirms the ceiling inside a retile whose placement pass
    /// cannot read the probe's answer yet — the echo of the
    /// pass's own write is pending, as on the device.
    private func confirmWithEchoPending(
        _ core: KiwiCore,
        captured: Captured
    ) throws -> (target: CGRect, refused: CGRect) {
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        core.state.apply(.windowResized(w, refused))
        core.retile()
        captured.frames = [:]
        core.tiler.echoGraceOverride = { _ in
            captured.frames[self.w] != nil
        }
        core.retile()
        return (target, refused)
    }

    @Test("The placement pass keeps the probe's ask")
    func placementPassKeepsTheProbe() throws {
        let captured = Captured()
        let core = makeCore(captured: captured)
        let (target, _) = try confirmWithEchoPending(
            core,
            captured: captured
        )
        // Believed, not corroborated; the last frame out and the
        // open ask are the probe's, not the centred residue.
        #expect(core.tiler.sizeBound(for: w)?.maxWidth == nil)
        let probed = target.width + SizeBoundLearner.probeDistance
        let sent = try #require(captured.frames[w])
        #expect(abs(sent.width - probed) < 0.01)
        let ask = try #require(core.tiler.boundLearner.lastAsks[w])
        #expect(abs(ask.size.width - probed) < 0.01)
    }

    @Test("The probe's settled refusal corroborates the bound")
    func settledRefusalPairs() throws {
        let captured = Captured()
        let core = makeCore(captured: captured)
        let (target, refused) = try confirmWithEchoPending(
            core,
            captured: captured
        )
        core.tiler.echoGraceOverride = { _ in false }
        wireSettledRead(core, returning: refused)
        captured.frames = [:]
        core.runSizeBoundProbe(w)
        #expect(core.tiler.sizeBound(for: w)?.maxWidth == 715)
        // Answered: the hold ends and the residue goes out.
        let residue = try #require(captured.frames[w])
        #expect(residue.width == 715)
        #expect(abs(residue.midX - target.midX) < 0.01)
    }

    @Test("A re-issuing pass keeps its own ask")
    func reissuingPassKeepsItsAsk() throws {
        let captured = Captured()
        let core = makeCore(captured: captured)
        _ = try confirmWithEchoPending(core, captured: captured)
        core.tiler.echoGraceOverride = { _ in true }
        // Control: an ordinary pass holds the residue back.
        captured.frames = [:]
        core.retile()
        #expect(captured.frames[w] == nil)
        // A Space activation re-issues it, probe or not.
        core.retile(pass: .reissue)
        let reissued = try #require(captured.frames[w])
        #expect(reissued.width == 715)
    }

    @Test("A forced pass keeps its own ask")
    func forcedPassKeepsItsAsk() throws {
        let captured = Captured()
        let core = makeCore(captured: captured)
        let (target, _) = try confirmWithEchoPending(
            core,
            captured: captured
        )
        core.tiler.echoGraceOverride = { _ in true }
        captured.frames = [:]
        core.retile(pass: .apply)
        let forced = try #require(captured.frames[w])
        let probed = target.width + SizeBoundLearner.probeDistance
        #expect(abs(forced.width - probed) > 1)
    }
}
