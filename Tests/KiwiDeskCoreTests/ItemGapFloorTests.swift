import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.item_gap` is floored at `KiwiShelf.minItemGap` where
/// it is stored — decode and setter — so every reader draws the
/// gap the shelf's plan reserves (#1695).
@Suite("Shelf item gap floor")
struct ItemGapFloorTests {
    @Test(
        "Decode floors at 0 and sets no ceiling",
        arguments: [(-5.0, 0.0), (6.0, 6.0), (90.0, 90.0)]
    )
    func decodeFloors(stored: Double, drawn: Double) throws {
        let json = #"{"item_gap": \#(stored)}"#
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(json.utf8)
        )
        #expect(shelf.itemGap == CGFloat(drawn))
    }

    @Test(
        "The setter floors at 0 and sets no ceiling",
        arguments: [(-5.0, 0.0), (6.0, 6.0), (90.0, 90.0)]
    )
    func setterFloors(value: Double, stored: Double) throws {
        let setting = try KiwiShelfCommandSetting.parse(
            field: "item_gap",
            args: [.number(value)]
        ).get()
        var shelf = KiwiShelf()
        setting.apply(to: &shelf)
        #expect(shelf.itemGap == CGFloat(stored))
    }
}
