import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// One translation from a screen to the key its bar values take
/// (#3647 ▸ lane 3c): a screen and its areas read the same number,
/// the lower NUMBERED place for twins, and the numbers a profile's
/// bar values are kept under leave a twin's higher one out.
@Suite("Bar slot door (#3647)")
@MainActor
struct BarSlotDoorTests {
    private let twin = "T:1000x1000"
    private let other = "B:1000x1000"

    @Test("a twin's areas read the number its screen reads")
    func twinAreasAgree() throws {
        // The lower place is a hole, so the twin answers to 3.
        let order = ScreenOrder([twin, other, twin], unnumbered: [1])
        #expect(order.number(of: twin) == 3)
        let lead = ScreenAreaKey(fingerprint: twin, areaID: 0)
        let area = ScreenAreaKey(fingerprint: twin, areaID: 2)
        #expect(order.slot(of: lead) == ScreenSlotKey(number: 3))
        #expect(order.slot(of: area) == ScreenSlotKey(number: 3, areaID: 2))
        let core = makeTestCore()
        #expect(core.barKey(of: area, order: order) == "3#2")
        // A runtime pin to the twin is stored under the number it
        // reads, never dropped.
        #expect(
            order.storing(runtime: ["9": twin], over: [:])
                == ["9": ScreenSlotKey(number: 3)!]
        )
    }

    @Test("a twin's higher number keeps no bar values")
    func barNumbersSkipTheTwin() {
        let core = makeTestCore()
        #expect(
            core.barNumbers(
                count: 3,
                order: ScreenOrder([twin, other, twin])
            ) == [1, 2]
        )
        // With the lower place a hole, the hole keeps its number and
        // the twin answers to the higher one.
        #expect(
            core.barNumbers(
                count: 3,
                order: ScreenOrder([twin, other, twin], unnumbered: [1])
            ) == [1, 2, 3]
        )
        // Numbers past the order are the profile's own.
        #expect(
            core.barNumbers(count: 3, order: ScreenOrder([twin]))
                == [1, 2, 3]
        )
        #expect(core.barNumbers(count: 0, order: ScreenOrder([])) == [])
    }

    /// The scope a forget keeps holds a twin's higher number: on
    /// another setup that number is another screen.
    @Test("a twin's higher number stays in the kept scope")
    func scopeKeepsTheTwinsNumber() {
        let core = makeTestCore()
        let scope = core.screenEdgeScope(
            monitorSets: [
                MonitorSet(monitors: [twin, twin]),
                MonitorSet(monitors: [twin, other]),
            ],
            shares: [:],
            order: ScreenOrder([twin, twin])
        )
        #expect(scope.screens == ["1", "2"])
    }
}
