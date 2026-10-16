import Foundation
import Testing

/// The float raise's drain needs live `AXUIElement`s, so no unit
/// test reaches its completion; `FloatRaiseRingRestackTests` pins
/// what the landing does, and this pins that the raise still
/// lands through it and that the landing re-stacks the anchor's
/// ring (#2284). Deleting either call leaves the ring under a
/// float the raise slotted beneath the frontmost window, with
/// every behaviour test green.
@Suite("Float raise landing wiring (#2284)")
struct FloatRaiseLandingWiringTests {
    @Test("The float raise lands through landFloatRaise")
    func raiseTakesTheLanding() throws {
        let raise = try SourceScan.functionBody(
            of: "raiseFloatsAndSticky",
            in: "KiwiCore+ZOrderFloats.swift",
            under: "Commands"
        )
        #expect(raise.contains("self?.landFloatRaise("))
    }

    /// After the focus hand-back, so nothing the landing does can
    /// separate the ring from its window again, and through the
    /// watch's fan-out, so every overlay consumer re-stacks in the
    /// reorder event's order (borders.md ▸ KiwiVision).
    @Test("The landing re-stacks through the watch after focusing")
    func landingRestacksTheRing() throws {
        let landing = try SourceScan.functionBody(
            of: "landFloatRaise",
            in: "KiwiCore+ZOrderFloats.swift",
            under: "Commands"
        )
        let focus = landing.range(of: "focusWindow(focused,")
        let restack = landing.range(of: "windowServer.restack(focused)")
        #expect(focus != nil)
        #expect(restack != nil)
        if let focus, let restack {
            #expect(focus.lowerBound < restack.lowerBound)
        }
        let watch = try SourceScan.functionBody(
            of: "restack",
            in: "WindowServerWatch.swift",
            under: "OS"
        )
        #expect(watch.contains("hooks[consumer]?.restack?(id)"))
    }

    /// Scrolling defers the tile's raise to the pan's settle, and
    /// the raise there would land the tile over the floats a
    /// float raise issued at the command had lifted, so the
    /// deferred raise schedules its own, after the tile's
    /// (`CommandedFocusFloatRaiseTests` holds the immediate arm).
    @Test("The deferred focus raise re-raises the float layer")
    func deferredRaiseLiftsFloats() throws {
        let body = try SourceScan.functionBody(
            of: "runPendingFocusRaise",
            in: "KiwiCore+FocusRaise.swift",
            under: "Commands"
        )
        let raise = body.range(of: "raiseWindow(id)")
        let floats = body.range(of: "raiseFloatsAbove(afterFocusing: id)")
        #expect(raise != nil)
        #expect(floats != nil)
        if let raise, let floats {
            #expect(raise.lowerBound < floats.lowerBound)
        }
    }

    /// The owed raise is paid where the tiled plane comes to rest,
    /// through the one `tiledPlaneCameToRest` (#2343): the settle,
    /// an owed pass drawing with nothing to animate, and a tiled
    /// restore's completion. No unit test reaches the restore's
    /// drain or the live settle, and a lost payment leaves the
    /// floats buried with every behaviour test green.
    @Test("The owed float raise is paid at every rest")
    func debtIsPaidAtRest() throws {
        let core = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let door = try SourceScan.functionBody(
            of: "tiledPlaneCameToRest",
            in: "KiwiCore+FloatRaiseDebt.swift",
            under: "Commands"
        )
        // The restore, then the focus raise, then the floats.
        let order = [
            "runPendingZOrderRestore()",
            "runPendingFocusRaise()",
            "runPendingFloatRaise()",
        ].map { door.range(of: $0)?.lowerBound }
        #expect(!order.contains(nil), "door pays all three")
        let found = order.compactMap { $0 }
        #expect(found == found.sorted(), "door pays in order")
        // The payer is spelled at the door alone.
        var payers: [String: Int] = [:]
        for url in try SourceScan.swiftSources(under: core) {
            let source = try SourceScan.strippedSource(at: url)
            let hits =
                source.components(separatedBy: "runPendingFloatRaise(")
                .count - 1
            if hits > 0 { payers[url.lastPathComponent] = hits }
        }
        #expect(
            payers == ["KiwiCore+FloatRaiseDebt.swift": 2],
            "the float raise is paid beside the door: \(payers)"
        )
        // Each rest site takes the door with its own payments.
        let rests = [
            (
                "App/KiwiCore+Settle.swift",
                "tiledPlaneCameToRest(restore:true,focusRaise:true)"
            ),
            (
                "App/KiwiCore+Retile.swift",
                "ifpaying,tiler.animation.activeCount==0{"
                    + "tiledPlaneCameToRest(restore:true,focusRaise:false)}"
            ),
            (
                "App/KiwiCore+MotionCause.swift",
                "ifself.tiler.animation.activeCount==0{"
                    + "self.tiledPlaneCameToRest(restore:true,"
                    + "focusRaise:false)}"
            ),
            (
                "Commands/KiwiCore+ZOrder.swift",
                "defer{self.tiledPlaneCameToRest(restore:false,"
                    + "focusRaise:false)}"
            ),
        ]
        for (file, needle) in rests {
            let source = try SourceScan.strippedSource(
                at: core.appendingPathComponent(file)
            ).filter { !$0.isWhitespace }
            #expect(source.contains(needle), "\(file)")
        }
        let restoreSequence = try SourceScan.functionBody(
            of: "raiseSequentially",
            in: "KiwiCore+ZOrder.swift",
            under: "Commands"
        )
        #expect(
            restoreSequence.contains("floatRaiseDebt.restoresInFlight += 1")
        )
        #expect(
            restoreSequence.contains("floatRaiseDebt.restoresInFlight -= 1")
        )
        // Ahead of the staleness guard, or a superseded restore
        // never pays the debt it held up.
        let pays = restoreSequence.range(of: "tiledPlaneCameToRest(")
        let stale = restoreSequence.range(
            of: "guard generation == self.zOrderRaiseGeneration.value"
        )
        #expect(pays != nil)
        #expect(stale != nil)
        if let pays, let stale {
            #expect(pays.lowerBound < stale.lowerBound)
        }
    }
}
