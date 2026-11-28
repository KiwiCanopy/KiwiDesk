import Foundation
import Testing

@testable import KiwiDesk

/// Which ink the update window's text takes (#3650): text drawn
/// on the window's glass follows what the glass shows through the
/// hierarchical styles, and text on a card, which has a fill of
/// its own, keeps a concrete `SettingsTheme` ink. The glass adapts
/// to the backdrop, so no offscreen render can tell the two
/// apart; the guard is a scan of the Updates files that draw text
/// or name an ink, each of which is ruled into one list below.
///
/// A control draws its label on a face of its own, so it sits on
/// the opaque control ground instead (#3666).
///
/// Ruled per file, so a file holding both kinds is ruled by its
/// card text: `UpdateNotesScroll.swift`'s links sit on the glass,
/// and a fixed ink added to them would pass both scans.
/// Off the main actor: one read of the Updates folder.
@Suite("Update window text on glass and on cards (#3650)")
struct UpdateGlassTextTests {
    /// Files whose text sits on the glass, with the hierarchical
    /// styles each one draws.
    private static let onGlass: [String: [String]] = [
        "UpdateWindowView.swift": [".primary", ".secondary"],
        "UpdateCheckingWindowController.swift": [".primary"],
        "UpdateWindowFooter.swift": [".secondary"],
    ]

    /// Files whose text sits on a card or the Highlights panel.
    private static let onCards: Set<String> = [
        "UpdateNotesGroups.swift",
        "UpdateSpotlightRows.swift",
        "UpdateNotesMarkdown.swift",
        "NextOnMyListPanel.swift",
        // The "no notes" card; its links on the glass name no ink.
        "UpdateNotesScroll.swift",
    ]

    /// Files whose text a control draws on the opaque control
    /// ground (#3666): its face's fixed ink on `card`, which the
    /// contrast suite measures, and no text of their own.
    private static let onControlGround: Set<String> = [
        "UpdateNotesTabStrip.swift",
        "WhatsNewReleasePicker.swift",
        "UpdatePopUp.swift",
    ]

    private static var updates: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Updates")
    }

    private static func source(_ name: String) throws -> String {
        try String(
            contentsOf: updates.appendingPathComponent(name),
            encoding: .utf8
        )
    }

    /// `ink`, `ink2` or `ink3`; `warningInk` is a status colour,
    /// not a text ink, and stays.
    private static var fixedInk: Regex<Substring> {
        /SettingsTheme\.ink\d?\b/
    }

    /// A fixed ink DRAWN on text, as a style or an attribute.
    private static var drawnInk: Regex<Substring> {
        /(?:foregroundStyle\(|foregroundColor = )SettingsTheme\.ink\d?\b/
    }

    /// The controls that draw a label of their own.
    private static let controls = ["SegmentedPicker(", "UpdatePopUp("]

    /// Every Updates file that draws text or names an ink is ruled
    /// into exactly one list, so a new one cannot go unseen.
    @Test("every text-drawing Updates file is ruled")
    func everyFileIsRuled() throws {
        let files = try SourceScan.swiftSources(under: Self.updates)
        #expect(files.count >= 20, "scanned \(files.count) files")
        var drawing: Set<String> = []
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            if text.contains("Text(") || text.contains(Self.fixedInk)
                || Self.controls.contains(where: text.contains)
            {
                drawing.insert(file.lastPathComponent)
            }
        }
        let lists = [
            Set(Self.onGlass.keys), Self.onCards, Self.onControlGround,
        ]
        let ruled = lists.reduce(Set<String>()) { $0.union($1) }
        let unruled = drawing.subtracting(ruled).sorted()
        let stale = ruled.subtracting(drawing).sorted()
        #expect(drawing == ruled, "unruled: \(unruled), stale: \(stale)")
        #expect(
            lists.map(\.count).reduce(0, +) == ruled.count,
            "a file is ruled twice"
        )
    }

    /// A file on the control ground draws text only through a
    /// control: `UpdatePopUp`'s label, in a concrete ink, while
    /// a `Text` or a style beside the controls would sit on the
    /// glass unruled.
    @Test("text on the control ground is a control's")
    func controlGroundTextIsAControls() throws {
        let hierarchical = /\.foregroundStyle\(\.(?:primary|secondary)\)/
        for file in Self.onControlGround {
            var text = try SourceScan.strippedSource(
                at: Self.updates.appendingPathComponent(file)
            )
            if file == "UpdatePopUp.swift" {
                let body = try #require(
                    SourceScan.declarationBody(
                        after: "struct UpdatePopUp",
                        in: text
                    ),
                    "UpdatePopUp is gone"
                )
                #expect(body.contains(Self.drawnInk))
                #expect(!body.contains(hierarchical))
                text = text.replacingOccurrences(of: body, with: "")
            }
            #expect(
                !text.contains("Text(")
                    && !text.contains(".foregroundStyle("),
                "\(file) draws text of its own beside its controls"
            )
        }
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

    /// The fallback's 4.5:1 rests on the ground handing `ink` and
    /// `ink2` to `glassWindowGround`; without it the fallback draws
    /// the system's styles, which the contrast suite never measures.
    @Test("the ground hands the fallback its inks")
    func groundHandsTheInks() throws {
        let source = try SourceScan.strippedSource(
            at: Self.updates.appendingPathComponent("UpdateWindowView.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func updateWindowGround",
                in: source
            ),
            "updateWindowGround is gone"
        )
        let squashed = body.split(whereSeparator: \.isWhitespace).joined()
        let arguments = try #require(
            SourceScan.callArguments(of: "glassWindowGround(", in: squashed),
            "updateWindowGround no longer applies glassWindowGround"
        )
        #expect(arguments.contains("primary:SettingsTheme.ink,"))
        #expect(arguments.contains("secondary:SettingsTheme.ink2"))
    }

    /// A card's ground is fixed, so the card itself resolves
    /// `.primary` / `.secondary` to concrete inks: a link's
    /// `linkHover()` styles, and any text that drops its own ink.
    @Test(
        "a card resolves the hierarchical styles to its inks",
        arguments: ["func updateNotesCard", "struct UpdateHighlightsPanel"]
    )
    func cardResolvesTheInks(declaration: String) throws {
        let source = try SourceScan.strippedSource(
            at: Self.updates.appendingPathComponent("UpdateNotesGroups.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(after: declaration, in: source),
            "\(declaration) is gone"
        )
        let squashed = body.split(whereSeparator: \.isWhitespace).joined()
        #expect(
            squashed.contains(
                ".foregroundStyle(SettingsTheme.ink,SettingsTheme.ink2)"
            ),
            "\(declaration) no longer hands its text the inks"
        )
    }

    /// A hierarchical style on a card would follow the glass while
    /// the card's fill does not: light text on a white card.
    @Test("text on a card keeps a concrete ink")
    func cardTextIsConcrete() throws {
        let hierarchical = /\.foregroundStyle\(\.(?:primary|secondary)\)/
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
