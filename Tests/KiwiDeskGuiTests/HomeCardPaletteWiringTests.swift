import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// The palette hand-off behind the Home card plates (#786),
/// split from `HomeCardChromeTests` at the file ceiling: the
/// plate injects the user's colours, every schematic type
/// consults them, the fold floors against the plate, and the
/// two border-width readouts share one remap. What only these
/// can see is wiring a render loses silently — a deleted
/// consult leaves everything drawing, in brand, on a plate
/// that promised the user's desktop.
@Suite("Home card palette wiring")
struct HomeCardPaletteWiringTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// Needles are keyed PER STRUCT, because the same consult
    /// expression occurs in several types and a file-wide
    /// `contains` was satisfied by the second occurrence while
    /// the first went bare — guard-prover demonstrated exactly
    /// that (2026-08-09, the twice-occurring-expression trap).
    @Test("the plate injects and the schematics consult")
    func paletteIsWired() throws {
        #expect(
            try squashed("HomeCardPlate.swift").contains(
                ".environment(\\.schematicPalette,"
                    + "palette(settings))"
            )
        )
        let kit = try squashed(
            "Components/Layouts/LayoutSchematicKit.swift"
        )
        let tile = try structBody(kit, "SchematicTile")
        #expect(
            tile.contains("palette?.fill??LayoutSchematic.fill")
        )
        #expect(
            tile.contains(
                "palette?.stroke??LayoutSchematic.stroke"
            )
        )
        let newWindow = try structBody(
            kit,
            "SchematicNewWindow"
        )
        #expect(
            newWindow.contains(
                "palette?.newFill"
                    + "??SettingsTheme.accent.opacity(0.45)"
            )
        )
        #expect(
            newWindow.contains(
                "palette?.stroke??LayoutSchematic.stroke"
            )
        )
        let pile = try structBody(kit, "SchematicPileTile")
        // The pile's opaque base: without the consult a pile on
        // the plate flashes the light window-background under
        // the accent (#712's compounding trap, inverted). The
        // fallback is `card` since the dark pass retired
        // `.textBackgroundColor` (it follows the system window
        // background this window no longer uses).
        #expect(
            pile.contains(
                "palette?.base??SettingsTheme.card"
            )
        )
        #expect(pile.contains("palette?.newFill"))
        #expect(
            pile.contains("palette?.fill??LayoutSchematic.fill")
        )
        #expect(
            pile.contains(
                "palette?.stroke??LayoutSchematic.stroke"
            )
        )
        #expect(
            try structBody(kit, "SchematicGap").contains(
                "palette?.gapStroke"
            )
        )
        let ghost = try structBody(
            kit,
            "SchematicGhostOverflow"
        )
        #expect(ghost.contains("palette?.ghostFill"))
        #expect(ghost.contains("palette?.ghostStroke"))
        #expect(
            try squashed(
                "Components/Layouts/LayoutSchematicCanvas.swift"
            ).contains("palette?.frame")
        )
        // Totality: EVERY kit struct consults, so a new member
        // cannot fail open in brand-on-plate the way
        // `SchematicMoreChip` shipped (architect review,
        // 2026-08-09). No exemptions today; one would be named
        // here with its reason.
        var members = 0
        var rest = Substring(kit)
        while let hit = rest.range(of: "structSchematic") {
            rest = rest[hit.lowerBound...]
            let name = rest.dropFirst("struct".count)
                .prefix { $0.isLetter || $0.isNumber }
            members += 1
            #expect(
                try structBody(kit, String(name)).contains(
                    "palette"
                ),
                Comment(
                    rawValue:
                        "\(name) never consults the palette — "
                        + "it renders brand on the plate"
                )
            )
            rest = rest.dropFirst("structSchematic".count)
        }
        #expect(members >= 6)
    }

    /// The floor's ground derives from the shipped plate token,
    /// not from a dated copy of its hex: retune `previewPlate`
    /// and this reds until the arithmetic follows (architect +
    /// code review, 2026-08-09).
    @Test("the floor's ground matches the plate token")
    @MainActor
    func floorGroundMatchesTheToken() throws {
        let resolved = try #require(
            NSColor(SettingsTheme.previewPlate)
                .usingColorSpace(.sRGB)
        )
        let lum =
            0.2126 * Double(resolved.redComponent)
            + 0.7152 * Double(resolved.greenComponent)
            + 0.0722 * Double(resolved.blueComponent)
        #expect(
            abs(lum - HomeCardPlate.plateLuminance) < 0.002
        )
    }

    /// The fold's legibility floor (#786 ui-designer): the
    /// plate is KiwiDesk's fixed ground, so a user colour that
    /// sinks into it swaps for a theme fallback. Pinned with
    /// the palettes that motivated it — the shipped defaults
    /// pass (the picture IS the user's colours), the plate's
    /// own hex, black, and the translucent bar fill all fail.
    @Test("the palette fold floors against the plate")
    @MainActor
    func paletteFoldFloors() throws {
        #expect(HomeCardPlate.plateLegible("#8DB354"))
        #expect(HomeCardPlate.plateLegible("#EAF3EE"))
        #expect(!HomeCardPlate.plateLegible("#12251A"))
        #expect(!HomeCardPlate.plateLegible("#000000"))
        #expect(!HomeCardPlate.plateLegible("#14201CB3"))
        #expect(!HomeCardPlate.plateLegible("not-a-hex"))
        // And the fold consults it on both colours — a floor
        // nothing reads is the dead-resolver trap.
        let plate = try squashed("HomeCardPlate.swift")
        #expect(
            plate.contains(
                "plateLegible(accent)?Color(kiwiHex:accent)"
                    + ":SettingsTheme.accent"
            )
        )
        #expect(
            plate.contains(
                "plateLegible(ink)?Color(kiwiHex:ink)"
                    + ":SettingsTheme.plateInk"
            )
        )
    }

    /// Both border-width readouts go through the ONE remap —
    /// two textual copies of it disagree on the next retune
    /// with every suite green (#702's class; owner scale round,
    /// 2026-08-09).
    @Test("the border readouts share the one width remap")
    func borderReadoutsShareTheRemap() throws {
        #expect(
            try squashed("HomeCardPlate+Scene.swift").contains(
                "BorderPreviewScale.width("
            )
        )
        #expect(
            try squashed(
                "Components/Common/FocusBorderPreview.swift"
            ).contains("BorderPreviewScale.width(")
        )
    }

    /// The comment-stripped, squashed body of one struct — up
    /// to the next `struct` keyword — so a needle names its
    /// owning type rather than any occurrence in the file.
    private func structBody(
        _ source: String,
        _ name: String
    ) throws -> String {
        let marker = "struct\(name):View{"
        let start = try #require(
            source.range(of: marker),
            Comment(rawValue: "struct \(name) not found")
        )
        let rest = source[start.upperBound...]
        let end =
            rest.range(of: "struct")?.lowerBound
            ?? rest.endIndex
        return String(rest[..<end])
    }

    private func squashed(_ path: String) throws -> String {
        let url = Self.root
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }
}
