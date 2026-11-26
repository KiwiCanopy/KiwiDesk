import Foundation
import Testing

@testable import KiwiDesk

/// Which ink the update window's text takes (#3650): text drawn
/// on the window's glass follows what the glass shows through the
/// hierarchical styles, and text on a card, which has a fill of
/// its own, keeps a concrete `SettingsTheme` ink. The glass adapts
/// to the backdrop, so no offscreen render can tell the two
/// apart; the guard is a scan of the eight Updates files that
/// draw text. Off the main actor: one read of those files.
@Suite("Update window text on glass and on cards (#3650)")
struct UpdateGlassTextTests {
    /// Files whose text sits on the glass, with the hierarchical
    /// styles each one draws.
    private static let onGlass: [(file: String, styles: [String])] = [
        ("UpdateWindowView.swift", [".primary", ".secondary"]),
        ("UpdateCheckingWindowController.swift", [".primary"]),
        ("UpdateWindowFooter.swift", [".secondary"]),
    ]

    /// Files whose text sits on a card or the Highlights panel.
    private static let onCards = [
        "UpdateNotesGroups.swift",
        "UpdateSpotlightRows.swift",
        "UpdateNotesMarkdown.swift",
        "NextOnMyListPanel.swift",
    ]

    private static func source(_ name: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Updates")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// `ink`, `ink2` or `ink3`; `warningInk` is a status colour,
    /// not a text ink, and stays.
    private static var fixedInk: Regex<Substring> {
        /SettingsTheme\.ink\d?\b/
    }

    /// A fixed ink DRAWN on text: the ground's fallback inks hand
    /// `ink` and `ink2` to `glassFallbackInks`, which is no text.
    private static var drawnInk: Regex<Substring> {
        /(?:foregroundStyle\(|foregroundColor = )SettingsTheme\.ink\d?\b/
    }

    @Test("text on the glass takes the hierarchical styles")
    func glassTextIsHierarchical() throws {
        for (file, styles) in Self.onGlass {
            let text = try Self.source(file)
            #expect(
                !text.contains(Self.drawnInk),
                "\(file) draws a fixed ink on the glass"
            )
            for style in styles {
                #expect(
                    text.contains(".foregroundStyle(\(style))"),
                    "\(file) lost its \(style) text"
                )
            }
        }
    }

    /// A hierarchical style on a card would follow the glass while
    /// the card's fill does not: light text on a white card.
    @Test("text on a card keeps a concrete ink")
    func cardTextIsConcrete() throws {
        let hierarchical = /\.foregroundStyle\(\.(primary|secondary)\)/
        for file in Self.onCards {
            let text = try Self.source(file)
            #expect(
                text.contains(Self.fixedInk),
                "\(file) lost its concrete ink"
            )
            #expect(
                !text.contains(hierarchical),
                "\(file) draws a hierarchical style on a card"
            )
        }
    }
}
