import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The production plumbing that carries confirmed app bounds
/// into the layout (#677) — the `ScreenNeighborsPlumbingTests`
/// shape, one context field over. The layout suites inject
/// `context.sizeBounds` by hand, so without these a deleted
/// threading line would keep every suite green while every
/// residue silently reverts to the reserved-slot gap.
@Suite("Size-bound plumbing (#677)")
@MainActor
struct SizeBoundPlumbingTests {
    private let bounds = CGRect(
        x: 0,
        y: 0,
        width: 1920,
        height: 1080
    )

    @Test("context(bounds:space:) defaults to no bounds")
    func contextDefaultsEmpty() {
        // The default the probes and previews reason from: no
        // bound, every layout asks what it always did.
        let settings = TilingSettings()
        let context = settings.context(
            bounds: bounds,
            space: Space(id: "1", mode: .scrolling),
            sticky: []
        )
        #expect(context.sizeBounds.isEmpty)
    }

    @Test("context(bounds:space:) threads the bounds")
    func contextThreadsBounds() {
        let settings = TilingSettings()
        let bound = EffectiveSizeBound(
            width: .init(asked: 900, answered: 715)
        )
        let context = settings.context(
            bounds: bounds,
            space: Space(id: "1", mode: .scrolling),
            sticky: [],
            sizeBounds: [WindowID(1): bound]
        )
        #expect(context.sizeBounds[WindowID(1)] == bound)
    }

    @Test("layoutInput threads the learner's confirmed bounds")
    func layoutInputThreadsLearner() throws {
        let core = makeTestCore()
        let screen = try #require(
            NSScreen.main ?? NSScreen.screens.first
        )
        core.tiler.visibleBounds = { _ in bounds }
        core.state.workspaces.setMode(SpaceID(1), .monocle)
        let w = WindowID(1)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w, pid: 1, appName: "App")
            )
        )
        // Teach the learner directly: two identical refusals
        // of one ask (the ladder itself is
        // `SizeBoundLearnerTests`; this is only the wire).
        let asked = CGSize(width: 900, height: 800)
        let answered = CGSize(width: 715, height: 800)
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(w, size: asked)
            core.tiler.boundLearner.observe(
                w,
                currentSize: answered,
                settledRead: true
            )
        }
        let space = try #require(
            core.state.workspaces[SpaceID(1)]
        )
        let input = core.tiler.layoutInput(
            state: core.state,
            space: space,
            screen: screen
        )
        #expect(
            input.context.sizeBounds[w]?.width.first?.answered
                == 715
        )
    }
}
