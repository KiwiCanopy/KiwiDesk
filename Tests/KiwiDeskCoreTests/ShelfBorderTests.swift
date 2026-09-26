import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.border` (#1679): an optional stroke on the plate's
/// edge, or each box's under Boxed — off by default, its width
/// clamped at decode and set, and kept while the switch is off.
@Suite("KiwiShelf border")
struct ShelfBorderTests {
    /// The default is the look that shipped before the setting:
    /// no stroke at all, so an old profile draws as it was saved.
    @Test("The default draws no border")
    func defaultDrawsNone() throws {
        let shelf = KiwiShelf()
        #expect(!shelf.border)
        #expect(shelf.drawnBorderWidth == 0)
        let decoded = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data("{}".utf8)
        )
        #expect(decoded == shelf)
    }

    /// The width is the user's while the switch is off: turning
    /// the border back on draws the width they left.
    @Test("The width is kept while the border is off")
    func widthIsKept() {
        var shelf = KiwiShelf()
        shelf.borderWidth = 3
        #expect(shelf.drawnBorderWidth == 0)
        shelf.border = true
        #expect(shelf.drawnBorderWidth == 3)
    }

    @Test("A drawing reads the width clamped, whoever wrote it")
    func readersClamp() {
        var shelf = KiwiShelf()
        shelf.border = true
        shelf.borderWidth = 20
        #expect(
            shelf.drawnBorderWidth == KiwiShelf.borderWidthRange.upperBound
        )
    }

    @Test(
        "Decode clamps to the range",
        arguments: [(0.2, 1.0), (40.0, 4.0), (2.5, 2.5)]
    )
    func decodeClamps(stored: Double, drawn: Double) throws {
        let json =
            #"{"border": true, "border_width": \#(stored), "#
            + ##""border_color": "#11223344"}"##
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(json.utf8)
        )
        #expect(shelf.border)
        #expect(shelf.borderWidth == CGFloat(drawn))
        #expect(shelf.borderColor == "#11223344")
    }

    @Test("The three keys round-trip through JSON")
    func roundTrip() throws {
        var shelf = KiwiShelf()
        shelf.border = true
        shelf.borderWidth = 3
        shelf.borderColor = "#1C1C1E"
        let data = try JSONEncoder().encode(shelf)
        let back = try JSONDecoder().decode(KiwiShelf.self, from: data)
        #expect(back == shelf)
    }

    @Test(
        "The setter clamps to the range",
        arguments: [(-3.0, 1.0), (0.5, 1.0), (9.0, 4.0), (2.5, 2.5)]
    )
    func setterClamps(value: Double, stored: Double) throws {
        let setting = try KiwiShelfCommandSetting.parse(
            field: "border_width",
            args: [.number(value)]
        ).get()
        var shelf = KiwiShelf()
        setting.apply(to: &shelf)
        #expect(shelf.borderWidth == CGFloat(stored))
    }

    @Test("The switch and the colour set their fields")
    func switchAndColour() throws {
        var shelf = KiwiShelf()
        try KiwiShelfCommandSetting.parse(
            field: "border",
            args: [.bool(true)]
        ).get().apply(to: &shelf)
        try KiwiShelfCommandSetting.parse(
            field: "border_color",
            args: [.string("#FFFFFF59")]
        ).get().apply(to: &shelf)
        #expect(shelf.border)
        #expect(shelf.borderColor == "#FFFFFF59")
        let refused = KiwiShelfCommandSetting.parse(
            field: "border",
            args: [.string("yes")]
        )
        #expect((try? refused.get()) == nil)
    }
}
