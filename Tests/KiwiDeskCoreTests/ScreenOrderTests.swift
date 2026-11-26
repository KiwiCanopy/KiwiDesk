import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The crossing between numbered and fingerprint pins (#3647): the
/// suggested numbering, the stored key's grammar and the two
/// projections.
@Suite("Screen order (#3647)")
struct ScreenOrderTests {
    private func display(
        _ id: UInt32,
        _ name: String,
        x: CGFloat,
        y: CGFloat = 0
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: y, width: 100, height: 100)
        )
    }

    @Test("the suggestion runs left to right, ties top to bottom")
    func leftToRight() {
        let order = ScreenOrder.leftToRight([
            display(1, "Right", x: 200),
            display(2, "Low", x: 0, y: -100),
            display(3, "High", x: 0, y: 100),
        ])
        #expect(
            order.fingerprints
                == ["High:100x100", "Low:100x100", "Right:100x100"]
        )
    }

    @Test(
        "a stored key is N or N#area, nothing else",
        arguments: ["0", "01", "1#0", "1#", "#1", "a", "1#2#3", "-1", ""]
    )
    func refusesOtherKeys(raw: String) {
        #expect(ScreenSlotKey(parsing: raw) == nil)
    }

    @Test("a stored key round-trips its area")
    func parsesKeys() {
        #expect(ScreenSlotKey(parsing: "2") == ScreenSlotKey(number: 2))
        #expect(
            ScreenSlotKey(parsing: "3#4")
                == ScreenSlotKey(number: 3, areaID: 4)
        )
        #expect(ScreenSlotKey(number: 3, areaID: 4)?.description == "3#4")
    }

    @Test("twins number by the lower, and both resolve")
    func twins() {
        let order = ScreenOrder(["A:1x1", "T:1x1", "T:1x1"])
        let key = ScreenAreaKey(fingerprint: "T:1x1")
        #expect(order.slot(of: key) == ScreenSlotKey(number: 2))
        #expect(order.numbers(of: "T:1x1") == [2, 3])
        #expect(
            order.runtimeKey(of: ScreenSlotKey(number: 3)!)?.description
                == "T:1x1"
        )
    }

    @Test("storing drops a screen outside the order, keeps a waiting number")
    func storing() {
        let order = ScreenOrder(["A:1x1"])
        let stored = order.storing(
            runtime: ["1": "A:1x1#2", "2": "Gone:1x1"],
            over: [
                "2": ScreenSlotKey(number: 1)!,
                "3": ScreenSlotKey(number: 2)!,
            ]
        )
        #expect(
            stored == [
                "1": ScreenSlotKey(number: 1, areaID: 2)!,
                "3": ScreenSlotKey(number: 2)!,
            ]
        )
        #expect(order.runtime(stored) == ["1": "A:1x1#2"])
    }
}
