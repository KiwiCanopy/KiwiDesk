import AppKit
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
/// Every figure quoted below is `ColorVision`'s own reading, not
/// the designer's tool that ruled the values — the two disagree
/// by a few units, and the ruled Sunset `#6C6860E6` read 59.9
/// here against the 60 floor, which is why Sunset ships one hex
/// step darker. That margin is structural, not slack: `#FF8099`
/// simulates to a neutral grey (≈150, 150, 154) under
/// protanopia, so only lightness separates it from any grey ring,
/// and over a white wallpaper the composited grey rises toward
/// it — `aLiftedSunsetGreyCollapses` pins that a lift, which is
/// what a reader retuning the vanish reaches for, walks straight
/// into the collapse. Sunset is the weakest ring of the set on
/// dark (≈3.2:1) and accepted as such; the lever, if the pair
/// reads too quiet, is the accent one lightness step up with hue
/// held, never the grey.
@Suite("Border ring separation")
struct BorderRingSeparationTests {
    private static let wallpapers = ["#FFFFFF", "#000000"]

    /// The authored band is D9–E6 by ruling; below ~85 % the grey
    /// takes the backdrop's hue, which on a busy wallpaper is the
    /// vanish #1384 named, and fully opaque it stops reading as
    /// the receding tier. The derived default's `CC` (80 %) is
    /// kept by the same ruling — the one exemption, named rather
    /// than folded into the floor, and exempt from the BAND only:
    /// the default still owes its own home contrast below.
    private static let alphaFloor = 0.85
    private static let bandExempt: Set<String> = [
        PaletteCatalog.defaultName
    ]

    /// Ultraviolet trades dominance for PARITY by ruling: a grey
    /// clearly under the indigo's composited contrast is the
    /// vanish again, so the grey lands level with it and the
    /// indigo's chroma carries the ordering. "Level" is within
    /// this factor; the shipped grey sits at 1.08× and the
    /// refused device pick `#BFBFBFE6` at 2.23×
    /// (`theRefusedUltravioletPickInvertsDominance`).
    private static let parityByRuling: Set<String> = ["Ultraviolet"]
    private static let parityBand = 1.25

    /// The LIGHTNESS half of the vanish, which none of the pair
    /// clauses can see: a near-black grey at in-band alpha
    /// separates from every accent and recedes below every
    /// focused ring, and is still no ring (guard-prover, `#202020E6`
    /// on black at 1.25:1). So the unfocused ring owes a contrast
    /// of its own against its home. A floor, not a target, placed
    /// by the REFUSED side: just above the retired dark grey
    /// lifted in alpha alone — `#48484AE6` on black at 2.06:1, the
    /// exact retune the ruling says is the wrong lever
    /// (`aGreyLiftedInAlphaAloneIsNoRing`) — so the weakest shipped
    /// ring, Clean Light at 2.64:1 on white, keeps a step of
    /// headroom to move without billing a prover run.
    private static let ownContrastFloor = 2.2

    /// The palette's home backdrop, DERIVED from its own fill the
    /// way design-decisions says the base is set (`fill_color`
    /// sets the light/dark base) and Core reads it
    /// (`wantsLightInk`, the one threshold `GlassTint` shares) —
    /// never a hand list of names, which a future light palette
    /// would silently miss and then be judged on black.
    private static func home(of palette: ColorPalette) -> String? {
        guard let fill = palette.colors["kiwishelf.fill_color"]
        else { return nil }
        return NSColor(kiwiHex: fill).wantsLightInk
            ? "#000000" : "#FFFFFF"
    }

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

    @Test("Every authored unfocused ring sits in the translucent band")
    func unfocusedRingsSitInTheAlphaBand() throws {
        let palettes = PaletteCatalog.bundled()
        #expect(palettes.count == 9)
        var measured = 0
        for palette in palettes
        where !Self.bandExempt.contains(palette.name) {
            let hex = try #require(
                palette.colors["border.unfocused_color"],
                Comment(rawValue: "\(palette.name) omits the ring")
            )
            let rgb = try #require(DragVisual.parseHex(hex))
            #expect(
                rgb.alpha >= Self.alphaFloor && rgb.alpha < 1,
                Comment(rawValue: "\(palette.name) \(hex)")
            )
            measured += 1
        }
        #expect(measured == palettes.count - Self.bandExempt.count)
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
    /// by approaching it. Direction only, deliberately: the
    /// ruling's "margin" is a drawn value the eyeball owns, and
    /// the shipped pairs sit at ≤ 0.76× (Kiwi Neon the closest).
    @Test("The unfocused ring recedes on the palette's home backdrop")
    func unfocusedRecedesOnItsHomeBackdrop() throws {
        let palettes = PaletteCatalog.bundled()
        #expect(palettes.count == 9)
        var measured = 0
        for palette in palettes {
            let name = palette.name
            guard let pair = rings(of: palette),
                let home = Self.home(of: palette)
            else {
                Issue.record("\(name) omits a ring or fill key")
                continue
            }
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

    @Test("Every unfocused ring is seen on the palette's home backdrop")
    func unfocusedRingsAreSeenOnTheirHome() throws {
        let palettes = PaletteCatalog.bundled()
        #expect(palettes.count == 9)
        var measured = 0
        for palette in palettes {
            let name = palette.name
            guard let pair = rings(of: palette),
                let home = Self.home(of: palette)
            else {
                Issue.record("\(name) omits a ring or fill key")
                continue
            }
            let own = try #require(
                Self.compositedContrast(pair.unfocused, on: home)
            )
            #expect(
                own >= Self.ownContrastFloor,
                Comment(
                    rawValue:
                        "\(name) on \(home): unfocused "
                        + "\(pair.unfocused) composites to only "
                        + "\(own):1 — the lightness vanish (#1384)"
                )
            )
            measured += 1
        }
        #expect(measured == palettes.count)
    }

    /// The negative control for Sunset's "not lifted" ruling: the
    /// shared system grey the other dark palettes take, over a
    /// white wallpaper, lands on the pink's protan grey. A
    /// literal well under the floor rather than a fraction of it —
    /// this measures a hex Sunset must never ship and cannot move
    /// with a floor retune.
    @Test("A lifted Sunset grey collapses against the pink")
    func aLiftedSunsetGreyCollapses() throws {
        let focused = try #require(
            ColorVision.composite("#FF8099", over: "#FFFFFF")
        )
        let lifted = try #require(
            ColorVision.composite("#8E8E93E6", over: "#FFFFFF")
        )
        let gap = try #require(ColorVision.separation(focused, lifted))
        #expect(gap < ColorVision.separationFloor)
        #expect(gap < 12)
    }

    /// The negative control for the own-contrast floor: Slate's
    /// retired grey at the NEW alpha. Proves the floor tells
    /// lightness from alpha — this hex clears the band and both
    /// pair clauses.
    @Test("A grey lifted in alpha alone is no ring")
    func aGreyLiftedInAlphaAloneIsNoRing() throws {
        let own = try #require(
            Self.compositedContrast("#48484AE6", on: "#000000")
        )
        #expect(own < Self.ownContrastFloor)
    }

    /// The negative control for the parity band: the device pick
    /// #1384 refused. Proves the band reachable — a grey more
    /// than twice the indigo's contrast is dominance inverted,
    /// not parity.
    @Test("The refused Ultraviolet pick inverts dominance")
    func theRefusedUltravioletPickInvertsDominance() throws {
        let indigo = try #require(
            Self.compositedContrast("#5E5CE6", on: "#000000")
        )
        let pick = try #require(
            Self.compositedContrast("#BFBFBFE6", on: "#000000")
        )
        #expect(pick > indigo * Self.parityBand)
        #expect(pick > indigo * 2)
    }
}
