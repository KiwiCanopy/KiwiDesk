import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Bars panel preview's Space chips take Core's reading of a
/// configured icon (#1538): a symbol name is drawn as the symbol,
/// never as its name — the preview once handed the raw string to
/// the tile and showed "book" and "headphones" in place of the
/// glyphs, while the bar drew them.
@Suite("Bars panel preview space labels")
@MainActor
struct BarsPanelPreviewLabelTests {
    private let spaces: [SpaceID] = [
        SpaceID("1"), SpaceID("2"), SpaceID("3"), SpaceID("4"),
    ]

    @Test("A symbol icon is a glyph, an emoji is text, none is the ordinal")
    func labelsFollowCoreClassification() {
        let labels = BarsPanelPreview.spaceLabels(
            spaces: spaces,
            icons: [
                SpaceID("1"): "⭐",
                SpaceID("2"): "book",
                SpaceID("3"): "headphones",
            ]
        )
        #expect(
            labels == [
                .text("⭐"), .symbol("book"), .symbol("headphones"),
                .text("4"),
            ]
        )
    }

    @Test("The preview and the bar classify an icon alike")
    func previewAgreesWithTheBar() {
        for icon in ["book", "⭐", "AB", "star.fill"] {
            let label = BarsPanelPreview.spaceLabels(
                spaces: [SpaceID("1")],
                icons: [SpaceID("1"): icon]
            )[0]
            #expect(
                (label == .symbol(icon)) == KiwiCore.iconIsSymbol(icon),
                Comment(rawValue: icon)
            )
        }
    }
}
