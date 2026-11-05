import Foundation
import Testing

/// #2985's production wiring: no unit test reaches the live restore
/// or its drain, so a call site dropping the plan's floor or the
/// drain's front leaves `ZOrderScrollingRestoreTests` green while the
/// shown windows stack anyhow again.
@Suite("Scrolling restore wiring (#2985)")
struct ZOrderScrollingRestoreWiringTests {
    private func body(of name: String, in file: String) throws -> String {
        try SourceScan.functionBody(
            of: name,
            in: file,
            under: "Commands"
        ).filter { !$0.isWhitespace }
    }

    @Test("The restore raises the plan, above its floor")
    func restoreTakesThePlan() throws {
        let restore = try body(
            of: "restoreScrollingZOrder",
            in: "KiwiCore+ScrollingRestore.swift"
        )
        #expect(restore.contains("plan.raise,"))
        #expect(restore.contains("front:plan.anchor"))
        // The floor reaches both arms, the empty plan's included.
        let floors = restore.components(separatedBy: "above:plan.floor")
        #expect(floors.count == 3)
        let plan = try body(
            of: "scrollingPlan",
            in: "KiwiCore+ScrollingRestore.swift"
        )
        #expect(plan.contains("Self.scrollingRestorePlan("))
        // The slots: a residue wider than its slot reads as a pile
        // to anything judging overlap (#934).
        #expect(plan.contains("tiler.calculatedFrames(state:state)"))
    }

    @Test("The mode switch reaches the scrolling restore")
    func modeSwitchReachesIt() throws {
        let run = try body(
            of: "runPendingZOrderRestore",
            in: "KiwiCore+ZOrder.swift"
        )
        #expect(run.contains("restoreScrollingZOrder(space)"))
    }

    @Test("The front reaches the drain the sequence builds")
    func frontReachesTheDrain() throws {
        for (name, file) in [
            ("raiseSequentially", "KiwiCore+ZOrder.swift"),
            ("performZOrderSequence", "KiwiCore+ZOrderFloats.swift"),
            ("zOrderDrain", "KiwiCore+ZOrderFloats.swift"),
        ] {
            #expect(
                try body(of: name, in: file).contains("front:front"),
                "\(name)"
            )
        }
    }

    @Test("A step and a close arm on a window coming into view")
    func stepAndCloseArm() throws {
        let focus = try body(
            of: "focusWindow",
            in: "KiwiCore+FocusRaise.swift"
        )
        #expect(focus.contains("||scrollFocusStepShowsOthers(to:id,"))
        let close = try SourceScan.functionBody(
            of: "armCloseReturnRestack",
            in: "KiwiCore+CloseReturnRestack.swift",
            under: "App"
        ).filter { !$0.isWhitespace }
        #expect(close.contains("||scrollingRowShowsOthers(leaving:nil)"))
    }
}
