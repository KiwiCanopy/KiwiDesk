import Foundation
import Testing

@testable import KiwiDeskCore

/// A Screen pin may name an area (#3517): a numbered pin keeps its
/// area through the stored key and through the screen order, and a
/// pin to an area of a screen the order does not hold drops (#3647).
@Suite("Numbered area pins")
struct MonitorSetAreaPinTests {
    private let screen = "Wide:3440x1440"

    @Test func areaPinOfAScreenInTheOrderIsKept() throws {
        let area = ScreenAreaKey(fingerprint: screen, areaID: 2)
        let order = ScreenOrder([screen])
        let stored = order.storing(
            runtime: [
                SpaceID("1"): area.description,
                SpaceID("2"): "Other:1920x1080#1",
            ],
            over: [:]
        )
        #expect(stored == [SpaceID("1"): ScreenSlotKey(number: 1, areaID: 2)!])
        let data = try JSONEncoder().encode(stored)
        let back = try JSONDecoder().decode(
            [SpaceID: ScreenSlotKey].self,
            from: data
        )
        #expect(back == stored)
        #expect(order.runtime(back) == [SpaceID("1"): area.description])
    }
}
