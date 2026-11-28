import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Known screens keep their numbers (#3648 ▸ known-screens and
/// Sitting A rulings): a setup containing a stored one continues its
/// order, newcomers numbered after it left to right; at the same
/// count a stand-in takes the absent screen's number.
@Suite("Known screens keep their numbers (#3648)")
struct ScreenOrderContinuingTests {
    private func screen(_ name: String, x: CGFloat, y: CGFloat = 0)
        -> Display
    {
        Display(
            id: DisplayID(UInt32(x + y * 10 + 3000)),
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
        // Newcomers listed out of order, one pair tied on x.
        let displays = [
            screen("A", x: 0), screen("B", x: 100),
            screen("C", x: -100), screen("D", x: -200),
            screen("E", x: -100, y: 100),
        ]
        let order = ScreenOrder.continuing(
            [set("B", "A")],
            displays: displays
        )
        #expect(names(order) == ["B", "A", "D", "E", "C"])
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

    @Test("no shared screen, or a set covering all, is no base")
    func noBase() {
        let displays = [screen("A", x: 0), screen("B", x: 100)]
        #expect(
            ScreenOrder.continuing([set("Y", "Z")], displays: displays)
                == nil
        )
        #expect(
            ScreenOrder.continuing(
                [set("A", "Z")],
                displays: displays + [screen("C", x: 200)]
            ) == nil
        )
        #expect(
            ScreenOrder.continuing([set("B", "A")], displays: displays)
                == nil
        )
        #expect(ScreenOrder.continuing([], displays: displays) == nil)
        // An empty set is no base, even stored first.
        let flipped = [screen("A", x: 100), screen("B", x: 0)]
        #expect(
            names(
                ScreenOrder.continuing(
                    [MonitorSet(monitors: []), set("A")],
                    displays: flipped
                )
            ) == ["A", "B"]
        )
    }

    @Test("a stand-in takes the absent screen's number")
    func standIn() {
        let displays = [screen("C", x: -100), screen("A", x: 0)]
        #expect(
            names(ScreenOrder.continuing([set("A", "B")], displays: displays))
                == ["A", "C"]
        )
        #expect(names(.leftToRight(displays)) == ["C", "A"])
        // B, known as Screen 2, sits leftmost.
        let three = [
            screen("B", x: -200), screen("D", x: 0), screen("E", x: 100),
        ]
        #expect(
            names(
                ScreenOrder.continuing([set("A", "B", "C")], displays: three)
            ) == ["D", "B", "E"]
        )
        #expect(names(.leftToRight(three)) == ["B", "D", "E"])
    }

    @Test("the set sharing the most screens wins, the first on a tie")
    func mostSharedWins() {
        let displays = [
            screen("A", x: 0), screen("B", x: 100), screen("D", x: 200),
        ]
        #expect(
            names(
                ScreenOrder.continuing(
                    [set("A", "X", "Y"), set("Z", "A", "B")],
                    displays: displays
                )
            ) == ["D", "A", "B"]
        )
        #expect(
            names(
                ScreenOrder.continuing(
                    [set("B", "A", "X"), set("A", "B", "Y")],
                    displays: displays
                )
            ) == ["B", "A", "D"]
        )
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
        let oneTwin = [
            screen("T", x: 0), screen("A", x: 100), screen("B", x: 200),
        ]
        #expect(
            ScreenOrder.continuing([set("T", "T")], displays: oneTwin)
                == nil
        )
    }
}
