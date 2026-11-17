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
        // The chosen chip is a selected segment: solid accent under
        // the ink drawn on it, whatever the pointer does.
        #expect(
            ChoiceChip.fill(selected: true, hovering: true)
                == SettingsTheme.accent
        )
        #expect(ChoiceChip.ink(selected: true) == SettingsTheme.accentInk)
        #expect(ChoiceChip.ink(selected: false) == SettingsTheme.ink)
    }

    /// Every choice-chip site paints through the one surface, and
    /// none keeps a hand-rolled opacity beside it.
    @Test("every choice chip takes the one surface")
    func sitesTakeTheSurface() throws {
        let sites = [
            "Settings/Components/Common/FractionChips.swift": true,
            "Settings/Sections/ShortcutLayerChip.swift": true,
            "Settings/Sections/LayerStripEditor.swift": false,
            "Settings/Components/Keybindings/KeyboardChrome.swift": true,
            "Settings/Components/SpaceOverrides/SpacesPanelPreview.swift":
                true,
            // Its `+` is glyph-only; its lens chips are edged.
            "Settings/Components/KiwiVision/KiwiVisionLensStrip.swift":
                false,
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
            // The hover is the surface's own: a site holding hover
            // state beside it is a second copy of the gate.
            // The chosen weight is the surface's too (5.0.0).
            for banned in [
                ".primary.opacity(", ".secondary.opacity(",
                ".onHover{", "hovering", "Hovered", ".fontWeight(",
            ] {
                #expect(
                    !source.contains(banned),
                    Comment(rawValue: "\(path): \(banned)")
                )
            }
        }
    }

    /// The surface owns its hover the way `HoverChip` does: it
    /// lifts only while enabled, drops a lift its control loses
    /// the enable under, and names its Reduce Motion gate.
    @Test("the choice chip owns its hover in one home")
    func hoverHasOneHome() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent("Chips.swift")
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let surface = try #require(
            SourceScan.declarationBody(
                after: "struct ChoiceChipSurface",
                in: source
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        for needle in [
            // The fill reads the chip's own selection (guard-prover).
            "ChoiceChip.fill(selected:selected,hovering:hovering&&isEnabled)",
            ".onHover{hovering=isEnabled&&$0}",
            ".onChange(of:isEnabled){_,nowinif!now{hovering=false}}",
            ".animation(reduceMotion?nil:",
            // The chosen weight, over a reserved semibold width.
            "content.fontWeight(.semibold).hidden()",
            "content.fontWeight(selected?.semibold:nil)",
            ".foregroundStyle(ChoiceChip.ink(selected:selected))",
        ] {
            #expect(surface.contains(needle), Comment(rawValue: needle))
        }
        // The view extension is the surface's one way in.
        #expect(
            source.split(whereSeparator: \.isWhitespace).joined()
                .contains(
                    "modifier(ChoiceChipSurface(selected:selected,"
                        + "edged:edged,emboldens:edged&&emboldens))"
                )
        )
    }

    /// A weight chip is a sample of its weight, so the chosen one
    /// keeps it rather than going semibold (5.0.0).
    @Test("a weight sample opts out of the chosen weight")
    func weightSamplesKeepTheirWeight() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent("Components/Bars/FontWeightRow.swift")
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            source.contains(
                "font:.callout.weight(named.swiftUIWeight),"
                    + "selected:shown==named.value,emboldens:false"
            )
        )
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
