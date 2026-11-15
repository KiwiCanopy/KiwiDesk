import Foundation
import Testing

@testable import KiwiDesk

/// A search for the gesture bindings lands on them (#3301 ▸ the
/// ui-designer's plan, accepted): the Mouse card's binding rows
/// carry the scroll anchor and a wash, the Trackpad card's rows a
/// wash only, and neither card's Natural scrolling row is lit.
/// Source scans, off the main actor; where the echo may appear is
/// `SettingsAnchorPrimitiveTests`' and its pairing
/// `SettingsAnchorPairingTests`'.
@Suite("Gesture bindings reveal (#3301)")
struct GestureBindingsRevealTests {
    private static let gui = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    private static let bindings =
        "SettingsCatalog.shortcuts.gestures.children.gestureBindings"

    private static func source(_ file: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: gui.appendingPathComponent(file),
                encoding: .utf8
            )
        )
    }

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    private static let card =
        "Settings/Components/Gestures/GestureListCard.swift"

    /// The Mouse card anchors and washes, the Trackpad card washes,
    /// both over the bindings' one declaration: one view carries
    /// the `.id`, and both washes key on its id.
    @Test("Mouse anchors, Trackpad echoes, one control")
    func devicesSplitTheReveal() throws {
        let text = Self.squashed(
            try #require(
                SourceScan.declarationBody(
                    after: "private func revealed(",
                    in: try Self.source(Self.card)
                )
            )
        )
        let path = Self.bindings
        #expect(
            text.contains("case.mouse:rows.searchAnchored(\(path))")
        )
        #expect(
            text.contains("case.trackpad:rows.searchFlashEcho(\(path))")
        )
    }

    /// The reveal sits on the rows and footer, after the Natural
    /// row's divider, so the wash never lights the Natural pickers
    /// and a card with no rows still lays the anchor out.
    @Test("the reveal holds the rows and footer, not Natural")
    func revealSkipsNatural() throws {
        let text = try Self.source(Self.card)
        let body = Self.squashed(
            try #require(
                SourceScan.declarationBody(
                    after: "var body: some View",
                    in: text
                )
            )
        )
        #expect(body.contains("naturalRowDivider()revealed(bindings)"))
        let rows = Self.squashed(
            try #require(
                SourceScan.declarationBody(
                    after: "private var bindings: some View",
                    in: text
                )
            )
        )
        #expect(rows.contains("ForEach($entries)"))
        #expect(rows.trimmingCharacters(in: ["}"]).hasSuffix("footer"))
        let natural = Self.squashed(
            try #require(
                SourceScan.declarationBody(
                    after: "private var naturalRow: some View",
                    in: text
                )
            )
        )
        #expect(!natural.contains(".search"))
    }

    /// The part no longer wraps both cards in one anchor, which
    /// landed a hit on the Mouse card's Natural row.
    @Test("the cards' wrapper anchors nothing")
    func wrapperAnchorsNothing() throws {
        let part = try Self.source(
            "Settings/Components/Gestures/GesturesPart.swift"
        )
        let cards = try #require(
            SourceScan.declarationBody(
                after: "var gestureCards: some View",
                in: part
            )
        )
        #expect(!part.contains("gestureBindings"))
        #expect(!cards.contains(".search"))
    }
}
