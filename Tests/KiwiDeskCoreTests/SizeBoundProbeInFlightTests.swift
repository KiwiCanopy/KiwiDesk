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
/// hold.
@Suite("Size-bound probe in flight (#2758)", .serialized)
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
        guard NSScreen.main != nil else { return }
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
        guard NSScreen.main != nil else { return }
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

    @Test("The hold is the probe's spans alone, and ends answered")
    func holdIsTheProbesSpansAlone() throws {
        // The device's axis: a height floor, Telegram's 550 pt
        // answering a 324 pt slot (#2758).
        var learner = SizeBoundLearner()
        let held = CGSize(width: 380, height: 550)
        let slot = CGSize(width: 380, height: 324)
        learner.recordAsk(w, size: slot, settledFrom: held)
        learner.observe(w, currentSize: held, settledRead: true)
        let taken = learner.takeCorroborationProbe(
            w,
            current: held,
            target: slot
        )
        let issue = try #require(taken)
        // Before the issue is recorded nothing is in flight.
        #expect(!learner.probeInFlight(w, target: held))
        learner.recordAsk(
            w,
            size: issue.size,
            settledFrom: issue.baseline
        )
        // The anchor's answer and its ask are what it stands in
        // for; a third height, or a changed width, are not.
        #expect(learner.probeInFlight(w, target: held))
        #expect(learner.probeInFlight(w, target: slot))
        let taller = CGSize(width: 380, height: 700)
        #expect(!learner.probeInFlight(w, target: taller))
        let wider = CGSize(width: 500, height: 550)
        #expect(!learner.probeInFlight(w, target: wider))
        // The settled refusal pairs the floor and retires the
        // probe, so the hold ends.
        learner.observe(w, currentSize: held, settledRead: true)
        #expect(learner.bound(for: w)?.minHeight == 550)
        #expect(!learner.probeInFlight(w, target: held))
    }
}
