import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `RunSize` rides the in-place restart payload (#930, #2709), a
/// stored cross-version shape: its keys are pinned here, so a rename
/// owes the crossing a stored value owes.
@Suite("Run size coding (#2709)")
struct RunSizeCodingTests {
    @Test("A run size stores share and zone")
    func storedKeysArePinned() throws {
        let data = try JSONEncoder().encode(
            RunSize(share: 0.5, zone: 7)
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(Set(object.keys) == ["share", "zone"])
        #expect(
            try JSONDecoder().decode(RunSize.self, from: data)
                == RunSize(share: 0.5, zone: 7)
        )
    }
}
