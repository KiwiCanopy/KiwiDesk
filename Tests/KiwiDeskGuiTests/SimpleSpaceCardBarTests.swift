import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A Simple Space card's bar picture lights the card's own Space,
/// past the eighth too (#2777 ruling 9). Main-actor spend: building
/// one bars tile.
@Suite("Simple Space card bar")
@MainActor
struct SimpleSpaceCardBarTests {
    @Test("a card past the eighth Space lights itself")
    func ninthSpaceIsLit() {
        let tile = HomeCardBarsTile(
            settings: TilingSettings(),
            pocketStands: false,
            spaceCount: 9,
            scale: 1,
            activeSpace: 8
        )
        let items = tile.spaceItems(KiwiShelf())
        #expect(items.count == 8)
        #expect(items.last?.active == true)
        #expect(items.filter(\.active).count == 1)
    }
}
