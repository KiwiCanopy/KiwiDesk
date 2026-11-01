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
        var light = 0
        for palette in palettes {
            let holds = HomeCardPlate.holdsLightPlate(painted(palette))
            #expect(
                holds != Self.darkPalettes.contains(palette.name),
                Comment(rawValue: "\(palette.name) holds: \(holds)")
            )
            if holds { light += 1 }
        }
        #expect(light == 8)
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

    /// Every ring that holds the light plate stays apart from the
    /// unfocused outline under protan simulation — the verdict's
    /// own clause, measured where a reader sees it.
    @Test("every light-holding ring separates from the outline")
    func lightRingsSeparate() throws {
        for palette in PaletteCatalog.bundled() {
            let settings = painted(palette)
            guard HomeCardPlate.holdsLightPlate(settings) else {
                continue
            }
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
        }
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
}
