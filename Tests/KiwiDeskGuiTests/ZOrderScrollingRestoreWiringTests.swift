import Foundation
import Testing

/// #2985's production wiring: no unit test reaches the live restore
/// or its drain, so a call site dropping the plan's floor or the
/// drain's front leaves `ZOrderScrollingRestoreTests` green while the
/// shown windows stack anyhow again.
@Suite("Scrolling restore wiring (#2985)")
struct ZOrderScrollingRestoreWiringTests {
    private func flat(_ body: String) -> String {
        body.filter { !$0.isWhitespace }
    }

    @Test("The restore raises the plan, above its floor, after the focus")
    func restoreTakesThePlan() throws {
        let body = flat(
            try SourceScan.functionBody(
                of: "restoreScrollingZOrder",
                in: "KiwiCore+ZOrder.swift",
                under: "Commands"
            )
        )
        #expect(body.contains("Self.scrollingRestorePlan("))
        #expect(body.contains("plan.raise,"))
        #expect(body.contains("above:plan.floor"))
        #expect(body.contains("front:anchor"))
        // The slots: a residue wider than its slot reads as a pile
        // to anything judging overlap (#934).
        #expect(body.contains("tiler.calculatedFrames(state:state)"))
    }

    @Test("The front reaches the drain the sequence builds")
    func frontReachesTheDrain() throws {
        let sequence = flat(
            try SourceScan.functionBody(
                of: "raiseSequentially",
                in: "KiwiCore+ZOrder.swift",
                under: "Commands"
            )
        )
        #expect(sequence.contains("front:front"))
        let perform = flat(
            try SourceScan.functionBody(
                of: "performZOrderSequence",
                in: "KiwiCore+ZOrderFloats.swift",
                under: "Commands"
            )
        )
        #expect(perform.contains("front:front"))
        let drain = flat(
            try SourceScan.functionBody(
                of: "zOrderDrain",
                in: "KiwiCore+ZOrderFloats.swift",
                under: "Commands"
            )
        )
        #expect(drain.contains("front:front"))
    }
}
