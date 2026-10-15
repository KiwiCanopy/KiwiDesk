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

    /// Ordered after the focus hand-back: the restack is the last
    /// order of the landing, so nothing the landing does can
    /// separate the ring from its window again.
    @Test("The landing re-stacks the anchor's ring after focusing")
    func landingRestacksTheRing() throws {
        let landing = try SourceScan.functionBody(
            of: "landFloatRaise",
            in: "KiwiCore+ZOrderFloats.swift",
            under: "Commands"
        )
        let focus = landing.range(of: "focusWindow(focused,")
        let restack = landing.range(of: "borders.restack(focused)")
        #expect(focus != nil)
        #expect(restack != nil)
        if let focus, let restack {
            #expect(focus.lowerBound < restack.lowerBound)
        }
    }
}
