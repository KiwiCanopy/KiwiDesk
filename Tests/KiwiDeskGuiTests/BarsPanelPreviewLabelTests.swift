import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Bars panel preview draws each Space's identifier as the
/// bar does — Core's ladder, consumed by the tile (#1538, #702).
///
/// `@MainActor` because `KiwiCore` is, and that is all this suite
/// spends there: a handful of `NSImage(systemSymbolName:)` lookups.
@Suite("Bars panel preview space labels")
@MainActor
struct BarsPanelPreviewLabelTests {
    private let spaces: [SpaceID] = [
        SpaceID("1"), SpaceID("2"), SpaceID("3"), SpaceID("4"),
        SpaceID("mail"),
    ]
    private let icons: [SpaceID: String] = [
        SpaceID("1"): "⭐",
        SpaceID("2"): "book",
        SpaceID("3"): "headphones",
        SpaceID("mail"): "",
    ]

    @Test("Labels are the bar's own ladder: symbol, emoji, digits, monogram")
    func labelsAreTheBarsLadder() {
        let labels = BarsPanelPreview.spaceLabels(
            spaces: spaces,
            icons: icons
        )
        #expect(
            labels == [
                .text("⭐", tinted: false), .symbol("book"),
                .symbol("headphones"), .text("4", tinted: true),
                .text("MA", tinted: true),
            ]
        )
        #expect(
            labels
                == spaces.map {
                    KiwiCore.spaceIdentifier(id: $0, icon: icons[$0])
                }
        )
    }

    @Test("The tile draws a symbol as a glyph and text as a label")
    func tileConsumesTheVerdict() {
        let settings = TilingSettings()
        let items = HomeCardBarsTile(
            settings: settings,
            spaceCount: 3,
            spaceLabels: [
                .symbol("book"), .text("⭐", tinted: false),
                .text("4", tinted: true),
            ]
        )
        .spaceItems(settings.kiwishelf)
        #expect(items.count == 3)
        #expect(items[0].glyph == "book")
        #expect(items[0].label == nil)
        #expect(items[0].glyphRatio == 1)
        #expect(items[1].label == "⭐")
        #expect(items[1].glyph == nil)
        #expect(items[2].label == "4")
    }
}
