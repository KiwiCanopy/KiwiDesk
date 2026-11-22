import Foundation
import Testing

@testable import KiwiDeskCore

/// A Screen pin may name an area (#3517): a monitor set keeps a pin
/// whose key's screen is in the set, so a Settings Save, which
/// writes the draft's pins into the set, keeps an area pin, and a
/// stored one survives the decode.
@Suite("Monitor set area pins")
struct MonitorSetAreaPinTests {
    private let screen = "Wide:3440x1440"

    @Test func areaPinOfAScreenInTheSetIsKept() throws {
        let area = ScreenAreaKey(fingerprint: screen, areaID: 2)
        let set = MonitorSet(
            monitors: [screen],
            spaceMonitorMap: [
                SpaceID("1"): area.description,
                SpaceID("2"): "Other:1920x1080#1",
            ]
        )
        #expect(set.spaceMonitorMap == [SpaceID("1"): area.description])
        let data = try JSONEncoder().encode(set)
        let back = try JSONDecoder().decode(MonitorSet.self, from: data)
        #expect(back.spaceMonitorMap == set.spaceMonitorMap)
    }
}
