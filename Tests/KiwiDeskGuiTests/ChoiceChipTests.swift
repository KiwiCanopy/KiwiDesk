import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// The choice chips — a layer, a preset share or weight, the
/// add-layer `+` — rest and lift on the chip tokens (#2047), not
/// on a bare opacity of a hierarchical colour, which no contrast
/// row can measure.
@MainActor
@Suite("Choice chips (#2047)")
struct ChoiceChipTests {
    @Test("an unchosen chip rests and lifts on the chip tokens")
    func fillsAreTokens() {
        #expect(
            ChoiceChip.fill(selected: false, hovering: false)
                == SettingsTheme.chipRest
        )
        #expect(
            ChoiceChip.fill(selected: false, hovering: true)
                == SettingsTheme.chipHover
        )
        #expect(
            ChoiceChip.fill(selected: true, hovering: true)
                == SettingsTheme.accent.opacity(
                    ChoiceChip.selectedWashOpacity
                )
        )
    }

    /// Every choice-chip site paints through the one surface, and
    /// none keeps a hand-rolled opacity beside it.
    @Test("every choice chip takes the one surface")
    func sitesTakeTheSurface() throws {
        let sites = [
            "Settings/Components/Common/FractionChips.swift": true,
            "Settings/Sections/ShortcutLayerChip.swift": true,
            "Settings/Sections/LayerStripEditor.swift": false,
        ]
        for (path, edged) in sites {
            let url = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk")
                .appendingPathComponent(path)
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            #expect(
                source.contains(".choiceChip("),
                Comment(rawValue: path)
            )
            // The glyph-only `+` alone opts out of the edge.
            #expect(
                source.contains("edged:false") == !edged,
                Comment(rawValue: path)
            )
            for banned in [".primary.opacity(", ".secondary.opacity("] {
                #expect(
                    !source.contains(banned),
                    Comment(rawValue: "\(path): \(banned)")
                )
            }
        }
    }

    /// The edge a text choice draws is the button chip's own.
    @Test("an edged choice chip strokes the button chip's edge")
    func edgeIsTheButtonChipEdge() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent("Chips.swift")
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            source.contains(
                "ifedged{Capsule().strokeBorder(SettingsTheme.chipEdge,"
            )
        )
    }
}
