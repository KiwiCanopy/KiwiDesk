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
        // An empty plan lifts the anchor, not nothing.
        #expect(restore.contains("plan.anchor.map{[$0]}??[]"))
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

    /// The offset is read ahead of the pass and asked after it, at
    /// both doors a focus move comes through: read after, every step
    /// reads as no move.
    @Test("A focus move and a report ask around their pass")
    func movesAskAroundThePass() throws {
        let focus = try body(
            of: "focusWindow",
            in: "KiwiCore+FocusRaise.swift"
        )
        try expectAskAroundPass(
            focus,
            ask: "||scrollFocusMoveOwesRestore(to:id,"
        )
        let report = try SourceScan.functionBody(
            of: "handleWindowFocused",
            in: "KiwiCore+FocusEvents.swift",
            under: "App"
        ).filter { !$0.isWhitespace }
        try expectAskAroundPass(
            report,
            ask: "armReportedScrollMove(to:id,"
        )
        let ask = try body(
            of: "scrollFocusMoveOwesRestore",
            in: "KiwiCore+ScrollingRestore.swift"
        )
        #expect(ask.contains("tiler.motionGate.owed!=nil"))
        #expect(ask.contains("floatRaiseDebt.restoresInFlight>0"))
        let arm = try body(
            of: "armReportedScrollMove",
            in: "KiwiCore+ScrollingRestore.swift"
        )
        #expect(arm.contains("!isRestoredDesktopFocus(id,now:now)"))
    }

    private func expectAskAroundPass(
        _ source: String,
        ask: String
    ) throws {
        let read = try #require(
            source.range(of: "letoffsetBefore=activeSpace?.scrollRest?.offset")
        )
        let pass = try #require(
            source.range(of: "retileWithScrollDuration(")
        )
        let asked = try #require(source.range(of: ask))
        #expect(read.upperBound <= pass.lowerBound)
        #expect(pass.upperBound <= asked.lowerBound)
    }

    /// Neither arm reaches a unit test: the drain's completion needs a
    /// live element, and with none the raise answers as a no-op.
    @Test("A focused float's raise is issued, and a restore owes it")
    func focusedFloatOwes() throws {
        let raise = try body(
            of: "raiseFloatsForFocusedFloat",
            in: "KiwiCore+FloatRaiseDebt.swift"
        )
        #expect(raise.contains("raiseLandingFloats(thenFocus:focus)"))
        let sequence = try body(
            of: "raiseSequentially",
            in: "KiwiCore+ZOrder.swift"
        )
        let reassert = try #require(
            sequence.range(of: "self.focusWindow(focused,warp:false)")
        )
        let owes = try #require(
            sequence.range(
                of: "ifletlive=self.focusedWindowID,"
                    + "self.isEffectiveFloatOnActiveSpace(live)"
                    + "{self.floatRaiseDebt.owed=live}"
            )
        )
        #expect(reassert.upperBound <= owes.lowerBound)
    }

    @Test("A close arms on another window")
    func closeArms() throws {
        let close = try SourceScan.functionBody(
            of: "armCloseReturnRestack",
            in: "KiwiCore+CloseReturnRestack.swift",
            under: "App"
        ).filter { !$0.isWhitespace }
        #expect(close.contains("||scrollingRowShowsOthers(leaving:nil)"))
    }
}
