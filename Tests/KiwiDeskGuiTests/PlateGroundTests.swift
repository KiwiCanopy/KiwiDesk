import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The light plate's ring (#2859 ruling 1, #3041) over the bundled
/// palettes and looks, and the paint it resolves: in light mode every
/// look draws on the light plate, a ring that fails there darkened
/// until it reads; dark mode keeps the dark plate's paint.
@MainActor
@Suite("Plate ground")
struct PlateGroundTests {
    /// The two bundled palettes whose own ring fails the plate.
    private static let darkPalettes: Set<String> = [
        "True Dark", "Monochrome",
    ]

    private func painted(_ palette: ColorPalette) -> TilingSettings {
        var settings = TilingSettings()
        palette.apply(to: &settings)
        return settings
    }

    @Test("only the ruled palettes have their ring adjusted")
    func bundledPalettesRing() throws {
        let palettes = PaletteCatalog.bundled()
        #expect(palettes.count == 10)
        #expect(
            Set(palettes.map(\.name)).isSuperset(of: Self.darkPalettes)
        )
        for palette in palettes {
            let settings = painted(palette)
            let own = settings.borderStyle.focusedColor
            let ring = try #require(HomeCardPlate.lightRingHex(settings))
            #expect(HomeCardPlate.holdsLightRing(ring))
            #expect(
                (ring != own) == Self.darkPalettes.contains(palette.name),
                Comment(rawValue: "\(palette.name): \(ring)")
            )
        }
    }

    /// Every bundled look draws on the light plate in light mode.
    @Test("the bundled looks take the light plate")
    func bundledLooksTakeTheLightPlate() {
        let looks = makeTestModel().core.bundledLooks
        #expect(looks.count >= 6)
        for look in looks {
            var settings = TilingSettings()
            look.apply(to: &settings)
            let paint = HomeCardPlate.palette(settings, in: .light)
            #expect(paint.ground == .light, Comment(rawValue: look.name))
        }
    }

    /// The first of `steps` darkenings of `hex` that holds.
    private func firstHolding(_ hex: String, steps: Int = 40) -> String? {
        (1..<steps).lazy.compactMap {
            HomeCardPlate.scaled(hex, by: 1 - Double($0) / Double(steps))
        }
        .first(where: HomeCardPlate.holdsLightRing)
    }

    /// Adjusting scales the look's own colour, so a blue stays that
    /// blue, and stops at the first step that holds.
    @Test("an adjusted ring is the first darkening that holds")
    func adjustedRingIsMinimal() throws {
        var settings = TilingSettings()
        settings.borderStyle.focusedColor = "#64D2FF"
        #expect(!HomeCardPlate.holdsLightRing("#64D2FF"))
        let ring = try #require(HomeCardPlate.lightRingHex(settings))
        #expect(ring == firstHolding("#64D2FF"))
    }

    /// A colour that does not parse has no ring to darken, so the
    /// paint falls back to the plate's own ink.
    @Test("a malformed ring takes the plate's ink")
    func malformedRing() {
        var settings = TilingSettings()
        settings.borderStyle.focusedColor = "not-a-hex"
        #expect(HomeCardPlate.lightRingHex(settings) == nil)
        let paint = HomeCardPlate.palette(settings, in: .light)
        #expect(paint.focus == SettingsTheme.lightInk)
    }

    /// The ruling's eight light palettes each keep their ring apart
    /// from the unfocused outline under protan simulation, measured
    /// on its own rather than through `holdsLightRing`;
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

    /// Light mode paints the light plate for every look; dark mode
    /// takes the dark paint as it shipped before #2859.
    @Test("the paint follows the appearance alone")
    func paintFollowsTheAppearance() throws {
        let palettes = PaletteCatalog.bundled()
        let holder = painted(try #require(palettes.first))
        let adjusted = painted(
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
        let ring = try #require(HomeCardPlate.lightRingHex(adjusted))
        let moved = HomeCardPlate.palette(adjusted, in: .light)
        #expect(moved.ground == .light)
        #expect(moved.focus == Color(kiwiHex: ring))
        for settings in [holder, adjusted] {
            let paint = HomeCardPlate.palette(settings, in: .dark)
            #expect(paint == HomeCardPlate.darkPalette(settings))
            #expect(paint.ground == .dark)
            #expect(paint.focus == nil)
        }
    }

    /// A ring lost in the plate or the outline fails, and is
    /// adjusted until it holds.
    @Test("a sunk ring fails and is adjusted")
    func sunkRingsFail() {
        for sunk in [HomeCardPlate.lightGround, HomeCardPlate.lightOutline] {
            #expect(!HomeCardPlate.holdsLightRing(sunk))
            var settings = TilingSettings()
            settings.borderStyle.focusedColor = sunk
            #expect(HomeCardPlate.lightRingHex(settings) == firstHolding(sunk))
        }
    }

    /// One ring per ring clause that passes the other two and
    /// fails only that one, so deleting any clause reds.
    @Test("each ring clause fails alone")
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
            #expect(
                !HomeCardPlate.holdsLightRing(ring),
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
        #expect(HomeCardPlate.holdsLightRing(ring))
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
    /// takes the active item colour, adjusted the same way.
    @Test("borders off paint the active item colour")
    func bordersOffUseTheActiveColour() {
        var settings = TilingSettings()
        settings.borderStyle.enabled = false
        settings.borderStyle.focusedColor = HomeCardPlate.lightGround
        let paint = HomeCardPlate.palette(settings, in: .light)
        #expect(
            paint.focus
                == Color(kiwiHex: settings.kiwishelf.activeItemColor)
        )
        #expect(
            LayoutSchematicView.focusStroke(settings, on: paint) == nil
        )
        settings.borderStyle.focusedColor = "#0000FF"
        settings.kiwishelf.activeItemColor = HomeCardPlate.lightGround
        #expect(
            HomeCardPlate.lightRingHex(settings)
                == firstHolding(HomeCardPlate.lightGround)
        )
    }
}
