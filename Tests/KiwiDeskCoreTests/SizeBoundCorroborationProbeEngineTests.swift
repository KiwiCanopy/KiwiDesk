import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The corroboration probe through the engine (#1439): the
/// placement retile a confirmation triggers ISSUES the probe in
/// place of the ask the entry already answers, narrates it, and
/// the next settled read corroborates. The pure bookkeeping is
/// `SizeBoundCorroborationProbeTests`; this suite is the wiring —
/// the loop's substitution, the log, and the overlay pin.
@Suite("Size-bound corroboration probe, engine (#1439)", .serialized)
@MainActor
struct SizeBoundCorroborationProbeEngineTests {
    private let w = WindowID(1)

    /// Captured frame sink and log — a class so the captures in
    /// the engine's closures and the suite's reads never overlap
    /// in an exclusivity-checked `inout`.
    @MainActor
    private final class Captured {
        var frames: [WindowID: CGRect] = [:]
        var log: [String] = []
    }

    /// The `SizeBoundBaselineTests` fixture: one space in `mode`,
    /// `count` windows, a captured frame pipeline with animation
    /// off.
    private func makeCore(
        captured: Captured,
        mode: LayoutMode = .monocle,
        count: Int = 1
    ) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            captured.frames[id] = frame
        }
        core.onLog = { captured.log.append($0) }
        core.state.workspaces.setMode(SpaceID(1), mode)
        for n in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(n)),
                        pid: 1,
                        appName: "App"
                    )
                )
            )
        }
        return core
    }

    private var probeDistance: CGFloat {
        SizeBoundLearner.probeDistance
    }

    /// Wires the settle probe's read to answer `frame`
    /// synchronously.
    private func wireSettledRead(
        _ core: KiwiCore,
        returning frame: CGRect
    ) {
        core.eventLoop.frameReads.reader = { _ in frame }
        core.eventLoop.frameReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        core.eventLoop.frameReads.dispatchOverride = { _, work in
            work()
        }
        core.eventLoop.elements[1] = [
            w: AXUIElementCreateSystemWide()
        ]
    }

    @Test("The confirmation's placement pass issues the probe")
    func placementPassIssuesTheProbe() throws {
        guard NSScreen.main != nil else { return }
        let captured = Captured()
        let core = makeCore(captured: captured)
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        // Settled at the refused width before the ask: the entry
        // confirms from the first settled read (#1083).
        core.state.apply(.windowResized(w, refused))
        core.retile()
        wireSettledRead(core, returning: refused)
        captured.frames = [:]
        core.runSizeBoundProbe(w)
        // Believed, and not yet corroborated: `maxWidth` is what
        // the pill, the re-pack and the Track count read.
        let bound = try #require(core.tiler.sizeBound(for: w))
        #expect(bound.maxWidth == nil)
        // The placement pass asked the probe instead of the
        // consumed span: one point past the bar, wider (a
        // ceiling), the height untouched — and said so.
        let placed = try #require(captured.frames[w])
        let bar = EffectiveSizeBound.corroborationDistinctness
        #expect(abs(placed.width - (target.width + bar + 1)) < 0.01)
        #expect(abs(placed.height - target.height) < 0.01)
        #expect(
            captured.log.contains {
                $0.contains("corroboration probe for window 1")
            }
        )
        // The window refuses it too; the next settled read
        // corroborates, and the layout's own span goes out.
        captured.frames = [:]
        core.runSizeBoundProbe(w)
        #expect(core.tiler.sizeBound(for: w)?.maxWidth == 715)
        let residue = try #require(captured.frames[w])
        #expect(residue.width == 715)
        #expect(abs(residue.midX - target.midX) < 0.01)
    }

    @Test("A non-consuming layout issues the probe past the skip")
    func splitLayoutIssuesTheProbePastTheExplainedSkip() throws {
        // A split layout never consumes the entry: its slot
        // re-asks the anchor's own ask with the window at the
        // answer and the same origin — the "already there" skip,
        // which the probe must ride through. The owner's #1355
        // Track sitting is this shape; bsp draws it at this
        // fixture's bounds (two windows, two slots).
        guard NSScreen.main != nil else { return }
        let captured = Captured()
        let core = makeCore(captured: captured, mode: .bsp, count: 2)
        let slot = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        #expect(slot.width < 720)
        let refused = CGRect(
            origin: slot.origin,
            size: CGSize(width: 720, height: slot.height)
        )
        core.state.apply(.windowResized(w, refused))
        core.retile()
        wireSettledRead(core, returning: refused)
        captured.frames = [:]
        core.runSizeBoundProbe(w)
        #expect(core.tiler.sizeBound(for: w) != nil)
        // The placement pass re-asks the slot for this window —
        // explained, and skipped without the probe — and issues
        // the probe instead: a floor, so narrower.
        let placed = try #require(captured.frames[w])
        #expect(abs(placed.width - (slot.width - probeDistance)) < 0.01)
        #expect(placed.origin == slot.origin)
    }

    @Test("A placement pass is bounded and leaves no flag standing")
    func placementPassLeavesNoFlag() throws {
        // The severed applier never stamps, so every pass reads
        // settled and the unchanged pre-ask frame answers the
        // probe in the same turn — a confirmation edge raised
        // INSIDE the placement pass. Bounded to two placements,
        // and the flag is clear afterwards; a stale flag paid a
        // placement on the next unrelated retile. (The drain
        // after the loop is belt: a third edge in one turn.)
        guard NSScreen.main != nil else { return }
        let captured = Captured()
        let core = makeCore(captured: captured)
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        core.state.apply(.windowResized(w, refused))
        for _ in 0..<3 { core.retile() }
        // Corroborated within the third retile: the probe was
        // issued and answered by the placement passes.
        #expect(core.tiler.sizeBound(for: w)?.maxWidth == 715)
        let placements = captured.log.filter {
            $0.contains("confirmed during retile")
        }
        #expect(placements.count <= 2)
        #expect(!core.tiler.takePendingBoundPlacement())
    }

    @Test("A forced pass keeps the layout's own ask")
    func forcedPassKeepsTheLayoutsAsk() throws {
        // An explicit apply re-issues everything and probes past
        // corroborated bounds itself (#1055); the corroboration
        // probe stands down there and waits for the next
        // ordinary pass.
        guard NSScreen.main != nil else { return }
        let captured = Captured()
        let core = makeCore(captured: captured)
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let answered = CGSize(width: 715, height: target.height)
        core.state.apply(
            .windowResized(
                w,
                CGRect(origin: target.origin, size: answered)
            )
        )
        core.tiler.boundLearner.recordAsk(
            w,
            size: target.size,
            settledFrom: answered
        )
        core.tiler.boundLearner.observe(
            w,
            currentSize: answered,
            settledRead: true
        )
        core.tiler.echoGraceOverride = { _ in true }
        captured.frames = [:]
        core.retile(force: true)
        let forced = try #require(captured.frames[w])
        #expect(forced.width == 715)
        captured.frames = [:]
        core.retile()
        let probed = try #require(captured.frames[w])
        #expect(
            abs(probed.width - (target.width + probeDistance)) < 0.01
        )
    }

    @Test("A performed probe is re-asked by the layout")
    func performedProbeIsReasked() throws {
        // The echo reports the window AT the probe's ask: it
        // holds a size no layout drew, and the compliance sweep
        // would leave it there until an unrelated retile.
        guard NSScreen.main != nil else { return }
        let captured = Captured()
        let core = makeCore(captured: captured)
        let target = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        let refused = CGRect(
            origin: target.origin,
            size: CGSize(width: 715, height: target.height)
        )
        core.state.apply(.windowResized(w, refused))
        core.retile()
        wireSettledRead(core, returning: refused)
        captured.frames = [:]
        core.runSizeBoundProbe(w)
        let probe = try #require(captured.frames[w])
        core.tiler.echoGraceOverride = { _ in true }
        captured.frames = [:]
        core.handle(.windowResized(w, probe))
        #expect(
            captured.log.contains {
                $0.contains("corroboration probe complied")
            }
        )
        let reasked = try #require(captured.frames[w])
        #expect(reasked.width == 715)
    }

    @Test("A probe in flight pins the ring at the anchor's answer")
    func probeInFlightPinsTheRing() throws {
        guard let screen = NSScreen.main else { return }
        let core = makeTestCore()
        let asked = CGSize(width: 1000, height: 800)
        let answered = CGSize(width: 715, height: 800)
        core.tiler.boundLearner.recordAsk(
            w,
            size: asked,
            settledFrom: answered
        )
        core.tiler.boundLearner.observe(
            w,
            currentSize: answered,
            settledRead: true
        )
        let bar = EffectiveSizeBound.corroborationDistinctness
        // In flight toward the probe's span: the ring renders the
        // answer, as it does for the second probe's candidate.
        core.tiler.animation.animate(
            window: w,
            on: screen,
            from: CGRect(origin: .zero, size: answered),
            to: CGRect(
                x: 0,
                y: 0,
                width: 1000 + bar + 1,
                height: 800
            )
        )
        #expect(
            core.tiler.animationSizePin(for: w)
                == SizePin(width: 715)
        )
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
