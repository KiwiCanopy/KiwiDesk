import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The light plate's verdict (#2859 ruling 1) over the bundled
/// palettes and looks, and the paint it resolves: a look holds
/// the light plate only where its bar ink and focus ring pass on
/// it, dark mode and a failing look keep the dark plate's paint
/// unchanged.
@MainActor
@Suite("Plate ground verdict")
struct PlateGroundTests {
    /// The two bundled palettes ruled onto the dark plate.
    private static let darkPalettes: Set<String> = [
        "True Dark", "Monochrome",
    ]

    private func painted(_ palette: ColorPalette) -> TilingSettings {
        var settings = TilingSettings()
        palette.apply(to: &settings)
        return settings
    }

    @Test("the bundled palettes earn the ruled plates")
    func bundledPalettesEarnTheirPlates() {
        let palettes = PaletteCatalog.bundled()
        #expect(palettes.count == 10)
        #expect(
            Set(palettes.map(\.name)).isSuperset(of: Self.darkPalettes)
        )
        for palette in palettes {
            let holds = HomeCardPlate.holdsLightPlate(painted(palette))
            #expect(
                holds != Self.darkPalettes.contains(palette.name),
                Comment(rawValue: "\(palette.name) holds: \(holds)")
            )
        }
    }

    /// The looks carry their palettes' colours, so only the one
    /// drawn in True Dark keeps the dark plate.
    @Test("the bundled looks follow their palettes")
    func bundledLooksFollowTheirPalettes() {
        let looks = makeTestModel().core.bundledLooks
        #expect(looks.count >= 6)
        let darkPalettes = PaletteCatalog.bundled()
            .filter { Self.darkPalettes.contains($0.name) }
        for look in looks {
            var settings = TilingSettings()
            look.apply(to: &settings)
            let drawnDark = darkPalettes.contains {
                $0.isApplied(to: settings)
            }
            #expect(
                HomeCardPlate.holdsLightPlate(settings) != drawnDark,
                Comment(rawValue: "\(look.name)")
            )
        }
        #expect(
            looks.contains { look in
                var settings = TilingSettings()
                look.apply(to: &settings)
                return !HomeCardPlate.holdsLightPlate(settings)
            }
        )
    }

    /// The ruling's eight light palettes each keep their ring apart
    /// from the unfocused outline under protan simulation, measured
    /// on its own rather than through the verdict that contains it;
    /// Sunset is the tightest, at 72.9.
    @Test("the ruled light rings separate from the outline")
    func lightRingsSeparate() throws {
        let bundled = PaletteCatalog.bundled()
        let ruled = bundled.filter { !Self.darkPalettes.contains($0.name) }
        #expect(!ruled.isEmpty)
        #expect(ruled.count == bundled.count - Self.darkPalettes.count)
        for palette in ruled {
            let settings = painted(palette)
            let ring = try #require(
                ColorVision.composite(
                    settings.borderStyle.focusedColor,
                    over: HomeCardPlate.lightGround
                )
            )
            let separation = try #require(
                ColorVision.separation(ring, HomeCardPlate.lightOutline)
            )
            #expect(
                separation >= ColorVision.separationFloor,
                Comment(rawValue: "\(palette.name): \(separation)")
            )
            if palette.name == "Sunset" {
                #expect(separation >= 72.9)
            }
        }
        #expect(ruled.contains { $0.name == "Sunset" })
    }

    /// Light mode paints the light plate for a holder; dark mode,
    /// and a failing look in light mode, take the dark paint as
    /// it shipped before #2859.
    @Test("the paint follows the verdict and the appearance")
    func paintFollowsTheVerdict() throws {
        let palettes = PaletteCatalog.bundled()
        let holder = painted(try #require(palettes.first))
        let failing = painted(
            try #require(palettes.first { $0.name == "True Dark" })
        )
        let lit = HomeCardPlate.palette(holder, in: .light)
        #expect(lit.ground == .light)
        #expect(lit.base == SettingsTheme.lightPlate)
        #expect(lit.ink == SettingsTheme.lightInk)
        #expect(lit.accent == SettingsTheme.lightInk)
        #expect(
            lit.focus == Color(kiwiHex: holder.borderStyle.focusedColor)
        )
        for (settings, scheme) in [
            (holder, ColorScheme.dark), (failing, .dark),
            (failing, .light),
        ] {
            let paint = HomeCardPlate.palette(settings, in: scheme)
            #expect(paint == HomeCardPlate.darkPalette(settings))
            #expect(paint.ground == .dark)
            #expect(paint.focus == nil)
        }
    }

    /// The default look holds the plate, and loses it once its ink
    /// sinks into its bar or its ring into the plate or outline.
    @Test("a sunk ink or ring fails the verdict")
    func sunkColoursFail() throws {
        let base = TilingSettings()
        #expect(HomeCardPlate.holdsLightPlate(base))
        var sunkInk = base
        sunkInk.kiwishelf.itemColor = try #require(
            ColorVision.composite(
                base.kiwishelf.fillColor,
                over: HomeCardPlate.lightGround
            )
        )
        #expect(!HomeCardPlate.holdsLightPlate(sunkInk))
        var paleRing = base
        paleRing.borderStyle.focusedColor = HomeCardPlate.lightGround
        #expect(!HomeCardPlate.holdsLightPlate(paleRing))
        var outlineRing = base
        outlineRing.borderStyle.focusedColor = HomeCardPlate.lightOutline
        #expect(!HomeCardPlate.holdsLightPlate(outlineRing))
    }

    /// One ring per ring clause that passes the other two and
    /// fails only that one, so deleting any clause reds.
    @Test("each ring clause fails the verdict alone")
    func ringClausesFailAlone() throws {
        let plate = HomeCardPlate.lightGround
        let outline = HomeCardPlate.lightOutline
        let floor = HomeCardPlate.legibilityFloor
        let outlineContrast = try #require(
            ColorVision.contrast(outline, plate)
        )
        // A vivid green: far from the plate in luma, yet no
        // stronger than the outline by contrast.
        func measures(_ ring: String) throws -> (
            luma: Double, contrast: Double, separation: Double
        ) {
            (
                try #require(ColorVision.lumaDistance(ring, over: plate)),
                try #require(ColorVision.contrast(ring, plate)),
                try #require(ColorVision.separation(ring, outline))
            )
        }
        let flat = "#00F000"
        let flatly = try measures(flat)
        #expect(flatly.luma >= floor)
        #expect(flatly.contrast <= outlineContrast)
        #expect(flatly.separation >= ColorVision.separationFloor)
        // A teal: clears floor and contrast, collapses onto the
        // outline under protan simulation.
        let twin = "#00B4B4"
        let twinly = try measures(twin)
        #expect(twinly.luma >= floor)
        #expect(twinly.contrast > outlineContrast)
        #expect(twinly.separation < ColorVision.separationFloor)
        // A pale sky blue: out-contrasts the outline and separates
        // from it, yet sits just under the luma floor.
        let faint = "#87C8FF"
        let faintly = try measures(faint)
        #expect(faintly.luma < floor)
        #expect(faintly.contrast > outlineContrast)
        #expect(faintly.separation >= ColorVision.separationFloor)
        for ring in [flat, twin, faint] {
            var settings = TilingSettings()
            settings.borderStyle.focusedColor = ring
            #expect(
                !HomeCardPlate.holdsLightPlate(settings),
                Comment(rawValue: "\(ring) held the light plate")
            )
        }
    }

    /// A schematic on the light plate strokes the paint's own ring,
    /// even one the dark plate's floor would refuse.
    @Test("the light plate's schematic ring is the paint's")
    func lightRingIsThePaints() {
        let ring = "#1A1A1A"
        var settings = TilingSettings()
        settings.borderStyle.enabled = true
        settings.borderStyle.focusedColor = ring
        #expect(HomeCardPlate.holdsLightPlate(settings))
        #expect(
            !HomeCardPlate.plateLegible(ring, on: HomeCardPlate.darkGround)
        )
        let paint = HomeCardPlate.palette(settings, in: .light)
        #expect(
            LayoutSchematicView.focusStroke(settings, on: paint)
                == Color(kiwiHex: ring)
        )
    }

    /// With borders off no ring draws, so the plate's focus mark
    /// and the verdict both take the active item colour.
    @Test("borders off judge and paint the active item colour")
    func bordersOffUseTheActiveColour() {
        var settings = TilingSettings()
        settings.borderStyle.enabled = false
        settings.borderStyle.focusedColor = HomeCardPlate.lightGround
        #expect(HomeCardPlate.holdsLightPlate(settings))
        let paint = HomeCardPlate.palette(settings, in: .light)
        #expect(
            paint.focus
                == Color(kiwiHex: settings.kiwishelf.activeItemColor)
        )
        #expect(
            LayoutSchematicView.focusStroke(settings, on: paint) == nil
        )
        settings.kiwishelf.activeItemColor = HomeCardPlate.lightGround
        #expect(!HomeCardPlate.holdsLightPlate(settings))
    }
}
