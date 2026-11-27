import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Known screens keep their numbers (#3648 ▸ known-screens ruling):
/// a setup containing a stored one continues its order, newcomers
/// numbered after it left to right.
@Suite("Known screens keep their numbers (#3648)")
struct ScreenOrderContinuingTests {
    private func screen(_ name: String, x: CGFloat, y: CGFloat = 0)
        -> Display
    {
        Display(
            id: DisplayID(UInt32(x + 1000)),
            name: name,
            frame: CGRect(x: x, y: y, width: 100, height: 100)
        )
    }

    private func set(_ names: String...) -> MonitorSet {
        MonitorSet(monitors: names.map { "\($0):100x100" })
    }

    private func names(_ order: ScreenOrder?) -> [String]? {
        order?.fingerprints.map {
            String($0.prefix { $0 != ":" })
        }
    }

    @Test("a newcomer on the left takes the next number")
    func newcomerOnTheLeft() {
        let displays = [
            screen("C", x: -100), screen("A", x: 0), screen("B", x: 100),
        ]
        let order = ScreenOrder.continuing(
            [set("A", "B")],
            displays: displays
        )
        #expect(names(order) == ["A", "B", "C"])
        #expect(names(.leftToRight(displays)) == ["C", "A", "B"])
    }

    @Test("the stored order is kept, newcomers left to right")
    func storedOrderKept() {
        let displays = [
            screen("D", x: -200), screen("C", x: -100),
            screen("A", x: 0), screen("B", x: 100),
        ]
        let order = ScreenOrder.continuing(
            [set("B", "A")],
            displays: displays
        )
        #expect(names(order) == ["B", "A", "D", "C"])
    }

    @Test("of two contained sets, the first stored wins")
    func firstStoredWins() {
        let displays = [
            screen("A", x: 0), screen("B", x: 100), screen("C", x: 200),
        ]
        let order = ScreenOrder.continuing(
            [set("C"), set("A", "B")],
            displays: displays
        )
        #expect(names(order) == ["C", "A", "B"])
    }

    @Test("a set with an absent screen, or covering all, is no base")
    func noBase() {
        let displays = [screen("A", x: 0), screen("B", x: 100)]
        #expect(
            ScreenOrder.continuing([set("A", "Z")], displays: displays)
                == nil
        )
        #expect(
            ScreenOrder.continuing([set("B", "A")], displays: displays)
                == nil
        )
        #expect(ScreenOrder.continuing([], displays: displays) == nil)
    }

    @Test("a twin past the set's copies is a newcomer")
    func twinNewcomer() {
        let displays = [
            screen("T", x: 0), screen("T", x: 100), screen("A", x: 200),
        ]
        #expect(
            names(ScreenOrder.continuing([set("A", "T")], displays: displays))
                == ["A", "T", "T"]
        )
        #expect(
            ScreenOrder.continuing(
                [set("T", "T", "T")],
                displays: displays
            ) == nil
        )
    }
}
