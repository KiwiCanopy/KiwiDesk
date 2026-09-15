import Foundation
import Testing

@testable import KiwiDeskCore

/// The ring pair's colour-vision clause (#1384) — the sibling of
/// `SpaceBarAccentSeparationTests` for `border.focused_color`
/// against `border.unfocused_color`.
///
/// The vanish #1384 reported was a LIGHTNESS defect: six dark
/// palettes shipped a dark grey at 40–60 % alpha over dark
/// wallpaper, which recedes twice. The retune lifts the grey per
/// palette and moves alpha to one D9–E6 band, and this suite
/// measures what that has to preserve — the pair still separating
/// under simulated protanopia, and the unfocused ring still
/// sitting BELOW the focused one on the palette's home backdrop.
///
/// Both rings are measured **composited over the wallpaper
/// extremes**, the way `PaletteHighlightRoleTests` measures an
/// accent against its plate: the unfocused ring is translucent,
/// so what a reader compares against the opaque focused ring
/// sweeps the whole grey range as the wallpaper changes, and a
/// grey can clear one end while collapsing at the other.
///
/// **Sunset's light-extreme figure is structural, not margin.**
/// `#FF8099` simulates to a neutral grey (≈150, 150, 154) under
/// protanopia, so only lightness separates it from any grey ring,
/// and over a white wallpaper the composited grey rises toward
/// it. The ruled `#6C6860E6` measured 59.9 on this instrument
/// (the designer's tool read 62), so the shipped hex sits one
/// step darker at `#6A665EE6` and clears at 63 — a LIFT, which is
/// what a reader retuning the vanish will reach for, walks
/// straight into the collapse. Sunset is the weakest ring of the
/// set on dark (≈3.2:1) and accepted as such; the lever, if the
/// pair reads too quiet, is the accent one lightness step up with
/// hue held, never the grey.
@Suite("Border ring separation")
struct BorderRingSeparationTests {
    private var style: BorderStyle { BorderStyle() }

    private static let wallpapers = ["#FFFFFF", "#000000"]

    /// Where each palette is at home — the backdrop its
    /// dominance is judged on. One light palette; the derived
    /// default and the other seven are dark.
    private static let lightHome: Set<String> = ["Clean Light"]

    /// Ultraviolet trades dominance for PARITY by ruling: its
    /// indigo `#5E5CE6` composites to ~4.2:1 on dark, and a grey
    /// that sat clearly below it would be the vanish again, so
    /// the grey lands level with it and the indigo's chroma
    /// carries the ordering. The device pick `#BFBFBFE6` was
    /// refused for inverting it (7.8:1 against 3.4:1). The band
    /// pins "level", never "above".
    private static let parityByRuling: Set<String> = ["Ultraviolet"]
    private static let parityBand = 1.25

    /// A ring's WCAG contrast against the wallpaper it is
    /// composited over — nil for an unparseable hex.
    private static func compositedContrast(
        _ ring: String,
        on wallpaper: String
    ) -> Double? {
        guard let plate = ColorVision.composite(ring, over: wallpaper)
        else { return nil }
        return ColorVision.contrast(plate, wallpaper)
    }

    private func rings(
        of palette: ColorPalette
    ) -> (focused: String, unfocused: String)? {
        guard let focused = palette.colors["border.focused_color"],
            let unfocused = palette.colors["border.unfocused_color"]
        else { return nil }
        return (focused, unfocused)
    }

    @Test("The derived default carries the struct's ring pair")
    func derivedPaletteMatchesTheStruct() {
        // The default palette is read from `BorderStyle` at load;
        // the sweep below is only meaningful for a user with no
        // palette applied if it is actually measuring that pair.
        let palette = PaletteCatalog.defaultPalette()
        #expect(
            palette.colors["border.focused_color"]
                == style.focusedColor
        )
        #expect(
            palette.colors["border.unfocused_color"]
                == style.unfocusedColor
        )
    }

    /// The focused ring is the reference the unfocused one
    /// recedes from, so it has to be opaque — `parseHex` accepts
    /// `#RRGGBBAA`, and a translucent focused ring would clear
    /// every composited check below on its RGB alone.
    @Test("Every bundled focused ring is opaque")
    func focusedRingsAreOpaque() throws {
        let palettes = PaletteCatalog.bundled()
        #expect(palettes.count == 9)
        for palette in palettes {
            let focused = try #require(
                palette.colors["border.focused_color"],
                Comment(rawValue: "\(palette.name) omits the ring")
            )
            let rgb = try #require(DragVisual.parseHex(focused))
            #expect(
                rgb.alpha == 1,
                Comment(rawValue: "\(palette.name) \(focused)")
            )
        }
    }

    /// The unfocused ring composites to the RING's colour, not
    /// the wallpaper's. Below ~85 % the grey takes the backdrop's
    /// hue, which on a busy wallpaper is the vanish #1384 named;
    /// fully opaque and it stops reading as the receding tier.
    @Test("Every bundled unfocused ring sits in the translucent band")
    func unfocusedRingsSitInTheAlphaBand() throws {
        let palettes = PaletteCatalog.bundled()
        #expect(palettes.count == 9)
        for palette in palettes {
            let hex = try #require(
                palette.colors["border.unfocused_color"],
                Comment(rawValue: "\(palette.name) omits the ring")
            )
            let rgb = try #require(DragVisual.parseHex(hex))
            // The derived default's `CC` (80 %) is the one value
            // below the authored band, kept by ruling; the floor
            // is set under it so the band holds one number.
            #expect(
                rgb.alpha >= 0.79 && rgb.alpha < 1,
                Comment(rawValue: "\(palette.name) \(hex)")
            )
        }
    }

    @Test("Every bundled ring pair survives red-green vision loss")
    func everyBundledPairSeparatesUnderProtanopia() throws {
        let palettes = PaletteCatalog.bundled()
        // `authored()` soft-fails to `[]`, so without this the
        // sweep would shrink to the derived default and pass.
        #expect(palettes.count == 9)
        var measured = 0
        for palette in palettes {
            let name = palette.name
            guard let pair = rings(of: palette) else {
                Issue.record("\(name) omits a ring key")
                continue
            }
            for wallpaper in Self.wallpapers {
                let focused = try #require(
                    ColorVision.composite(pair.focused, over: wallpaper)
                )
                let unfocused = try #require(
                    ColorVision.composite(
                        pair.unfocused,
                        over: wallpaper
                    )
                )
                let gap = try #require(
                    ColorVision.separation(focused, unfocused)
                )
                let detail =
                    "\(name) on \(wallpaper): focused "
                    + "\(pair.focused) vs unfocused "
                    + "\(pair.unfocused) separate by only "
                    + "\(gap)/441 under simulated protanopia "
                    + "(#1384)"
                #expect(
                    gap >= ColorVision.separationFloor,
                    Comment(rawValue: detail)
                )
                measured += 1
            }
        }
        #expect(measured == palettes.count * Self.wallpapers.count)
    }

    /// The invariant the retune was made against: on the
    /// palette's home backdrop the unfocused ring recedes, which
    /// means LESS composited contrast than the focused ring — not
    /// lower lightness, since on a light backdrop a ring recedes
    /// by approaching it. A grey lifted past the accent is the
    /// device pick this rules out.
    @Test("The unfocused ring recedes on the palette's home backdrop")
    func unfocusedRecedesOnItsHomeBackdrop() throws {
        let palettes = PaletteCatalog.bundled()
        #expect(palettes.count == 9)
        var measured = 0
        for palette in palettes {
            let name = palette.name
            guard let pair = rings(of: palette) else {
                Issue.record("\(name) omits a ring key")
                continue
            }
            let home =
                Self.lightHome.contains(name) ? "#FFFFFF" : "#000000"
            let focused = try #require(
                Self.compositedContrast(pair.focused, on: home)
            )
            let unfocused = try #require(
                Self.compositedContrast(pair.unfocused, on: home)
            )
            let detail =
                "\(name) on \(home): unfocused \(pair.unfocused) "
                + "at \(unfocused):1 against focused "
                + "\(pair.focused) at \(focused):1 (#1384)"
            if Self.parityByRuling.contains(name) {
                #expect(
                    unfocused <= focused * Self.parityBand,
                    Comment(rawValue: detail)
                )
            } else {
                #expect(unfocused < focused, Comment(rawValue: detail))
            }
            measured += 1
        }
        #expect(measured == palettes.count)
    }
}
