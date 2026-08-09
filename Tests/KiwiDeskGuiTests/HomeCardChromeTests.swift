import Foundation
import Testing

@testable import KiwiDesk

/// The Home cards' plate-era chrome (#786): the two deliberate
/// card heights, the desktop plate's shape and silence, and the
/// palette injection that turns the schematics from brand to
/// the user's colours inside a plate.
///
/// This is the chrome suite `SettingsThemeMetricTests` requires
/// for the `cardHeight`/`cardHeightCompact` pair — both weights
/// named together, so they cannot drift apart unseen — and the
/// needle net for the wiring a render can lose silently: a
/// plate that stops injecting the palette still renders, in
/// brand, with every other guard green (the surfacing-gate
/// silence, `MonitorsGateWiringTests`' lesson).
@Suite("Home card chrome")
struct HomeCardChromeTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// Both heights, named together, with the relations that
    /// make them two REGISTERS rather than two numbers: the
    /// tall card must hold the whole plate plus a text band at
    /// least the size of nothing — and stay above the compact
    /// card, or the group split reads backwards.
    @Test("the two card heights hold their registers")
    func heightsHoldTheirRegisters() {
        #expect(SettingsTheme.cardHeight == 152)
        #expect(SettingsTheme.cardHeightCompact == 105)
        #expect(SettingsTheme.plateHeight == 92)
        #expect(
            SettingsTheme.cardHeight
                > SettingsTheme.cardHeightCompact
        )
        // The plate plus the text band's minimum (title row +
        // subtitle + paddings ≈ 60) is what the tall height IS;
        // a plate growing past the band is a card that clips
        // its own answer.
        #expect(
            SettingsTheme.cardHeight
                >= SettingsTheme.plateHeight + 56
        )
    }

    /// The height CHOICE derives from the one group partition —
    /// `HomeCardOrder.thisProfile` — never a second hand-kept
    /// list of which cards are tall.
    @Test("the tall register derives from the group partition")
    func tallDerivesFromTheGroup() throws {
        let card = try squashed("HomeCard.swift")
        #expect(
            card.contains(
                "height:tall?SettingsTheme.cardHeight"
                    + ":SettingsTheme.cardHeightCompact"
            )
        )
        #expect(
            card.contains(
                "vartall:Bool{"
                    + "HomeCardOrder.thisProfile"
                    + ".contains(destination)}"
            )
        )
    }

    /// The plate's frame is the theme's height on the theme's
    /// ground, silent to VoiceOver and inert to the pointer —
    /// the card is ONE button whose value is its subtitle, and
    /// the renderers inside carry AX elements of their own that
    /// must not leak into the card's voicing.
    @Test("the plate draws its frame and stays silent")
    func plateShapeAndSilence() throws {
        let plate = try squashed("HomeCardPlate.swift")
        #expect(
            plate.contains(
                ".frame(height:SettingsTheme.plateHeight)"
            )
        )
        #expect(
            plate.contains(
                ".background(SettingsTheme.previewPlate)"
            )
        )
        #expect(plate.contains(".accessibilityHidden(true)"))
        #expect(plate.contains(".allowsHitTesting(false)"))
    }

    /// The palette hand-off, at both ends: the plate injects
    /// the user's colours, and the schematic tiles consult
    /// them. Either end deleted leaves everything rendering —
    /// in brand, on a plate that promised the user's desktop —
    /// with every behaviour suite green.
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
        #expect(
            kit.contains("palette?.fill??LayoutSchematic.fill")
        )
        #expect(
            kit.contains(
                "palette?.stroke??LayoutSchematic.stroke"
            )
        )
        // The pile's opaque base: without the consult a pile on
        // the plate flashes the light window-background under
        // the accent (#712's compounding trap, inverted).
        #expect(
            kit.contains(
                "palette?.base"
                    + "??Color(nsColor:.textBackgroundColor)"
            )
        )
    }

    /// The grid the two heights live in: the adaptive column
    /// band the responsive pass will measure against, and the
    /// width `MonitorArrangementFitTests`' card canvas is
    /// derived from.
    @Test("the grid keeps its column band")
    func gridKeepsItsBand() throws {
        #expect(
            try squashed("HomeScreen.swift").contains(
                "GridItem(.adaptive(minimum:240,maximum:360),"
                    + "spacing:16)"
            )
        )
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
