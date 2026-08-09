import Foundation
import Testing

@testable import KiwiDeskCore

/// `highlight_color` IS the primary accent (#756).
///
/// With `active_indicator == .outline` the highlight paints a 2 pt
/// ring around the whole active item, and on a `plain` bar that
/// ring plus one tinted glyph is the ENTIRE active state — the
/// item's own fill is clear. So the highlight is not a flourish
/// that may borrow the palette's second hue: it is the largest
/// mark either bar makes, and where it disagrees with
/// `active_item_color` the secondary hue outshouts the item it is
/// subordinate to. Ultraviolet and Sunset were the two that
/// split; both closed.
///
/// A palette whose primary cannot carry the ring **lightens its
/// primary** rather than borrowing its secondary, which is why
/// Sunset's `#FF375F` became `#FF8099`: simulated for
/// protanopia the old hex did not clear the floor against its own
/// plate over a white wallpaper, so a protanope had no active
/// marker there at all and the amber ring was covering a defect
/// rather than expressing a theme. `theRetiredSunsetAccentFails`
/// measures that rather than restating it — three prose copies of
/// the figure disagreed with each other and with the instrument
/// before it was pinned here.
@Suite("Palette highlight role")
struct PaletteHighlightRoleTests {
    private static let accentPairs = [
        ("app_bar.active_item_color", "app_bar.highlight_color"),
        (
            "space_bar.active_item_color",
            "space_bar.highlight_color"
        ),
    ]

    /// No exemptions, in either bar. An absolute rule, so this
    /// carries no allow-list to add a palette to.
    @Test("Every bundled highlight is its bar's active accent")
    func highlightEqualsActiveAccent() throws {
        // The catalog has to be there at all: an unreadable
        // resource leaves one derived palette behind and every
        // scan below passes having measured almost nothing.
        #expect(!PaletteCatalog.authored().isEmpty)
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            for (active, highlight) in Self.accentPairs {
                // Required, not skipped when absent. Omitting
                // `highlight_color` while keeping a coloured
                // `active_item_color` is #756 exactly — the item
                // falls back to the shipped green ring — and a
                // `continue` here is the allow-list this rule
                // says it does not have.
                let a = try #require(
                    palette.colors[active],
                    Comment(rawValue: "\(palette.name) \(active)")
                )
                let h = try #require(
                    palette.colors[highlight],
                    Comment(
                        rawValue: "\(palette.name) \(highlight)"
                    )
                )
                #expect(
                    ColorPalette.sameColor(a, h),
                    Comment(
                        rawValue:
                            "\(palette.name): \(highlight) "
                            + "= \(h), \(active) = \(a)"
                    )
                )
                measured += 1
            }
        }
        #expect(measured == PaletteCatalog.bundled().count * 2)
    }

    /// The shipped defaults obey it too — they are the palette
    /// every sparse one falls back to.
    @Test("The shipped defaults carry one accent per bar")
    func shippedDefaultsAgree() {
        let settings = TilingSettings()
        #expect(
            settings.appBarStyle.highlightColor
                == settings.appBarStyle.activeItemColor
        )
        #expect(
            settings.spaceBarStyle.highlightColor
                == settings.spaceBarStyle.activeItemColor
        )
    }

    /// The instrument, before the measurement that uses it.
    ///
    /// Every number in the test below flows through
    /// `ColorVision.composite`, and a compositor that returned
    /// its `top` argument — or ignored the alpha — left that
    /// test green with room to spare, because both breakages
    /// make the plate MORE distinct from the accent, not less.
    /// The wallpaper loop degenerates too: with alpha ignored,
    /// black and white produce the same plate and the "a hue can
    /// clear one end and fail the other" claim stops being
    /// tested while the iteration count still adds up.
    @Test("The compositor mixes toward the wallpaper")
    func compositorMixes() throws {
        // `80` is 128/255, so the white side contributes
        // 127/255 — a mid grey one step below `#808080`, which
        // is the arithmetic and not a rounding slip.
        #expect(
            ColorVision.composite("#00000080", over: "#FFFFFF")
                == "#7F7F7F"
        )
        #expect(
            ColorVision.composite("#FFFFFF00", over: "#123456")
                == "#123456"
        )
        // Opaque means opaque, whichever wallpaper is under it.
        #expect(
            ColorVision.composite("#8DB354", over: "#000000")
                == "#8DB354"
        )
        // And the two extremes must not collapse into one
        // measurement.
        let onWhite = try #require(
            ColorVision.composite("#2C2C2EB3", over: "#FFFFFF")
        )
        let onBlack = try #require(
            ColorVision.composite("#2C2C2EB3", over: "#000000")
        )
        #expect(onWhite != onBlack)
    }

    /// The hex #756 retired, kept as a measurement rather than as
    /// prose. It is the whole argument for lightening Sunset's
    /// primary instead of leaving the ring a foreign hue, and it
    /// is the one number a doc comment cannot be trusted with:
    /// two prose copies and this suite's own docstring each
    /// carried a different figure, none of them the instrument's.
    ///
    /// It also proves the floor is reachable at all — a guard
    /// asserting `>=` over a set that has never been near the
    /// bound is a guard nobody has seen fail.
    @Test("The accent Sunset retired does not clear the floor")
    func theRetiredSunsetAccentFails() throws {
        let plate = try #require(
            ColorVision.composite("#2C2C2EB3", over: "#FFFFFF")
        )
        let gap = try #require(
            ColorVision.separation("#FF375F", plate)
        )
        #expect(gap < ColorVision.separationFloor)
        // And far under it, which is why this was not a close
        // call the eye could have settled either way. A literal
        // rather than a fraction of the floor: this measures a
        // RETIRED hex and cannot move, so tying it to a live
        // tunable would red this test the day the floor is
        // retuned for reasons that have nothing to do with it.
        #expect(gap < 12)
    }

    /// The measurement the rule above rests on: the active accent
    /// has to separate from the bar it is drawn ON, and the bar
    /// is translucent, so what it is drawn on is the fill
    /// composited over the user's wallpaper. Both extremes,
    /// because a mid-grey plate sweeps between them as the
    /// wallpaper changes and a hue can pass one end while failing
    /// the other.
    @Test("Every active accent clears its own composited plate")
    func accentSeparatesFromItsPlate() throws {
        #expect(!PaletteCatalog.authored().isEmpty)
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            for (activePath, _) in Self.accentPairs {
                let bar = activePath.split(separator: ".")[0]
                guard let accent = palette.colors[activePath],
                    let fill = palette.colors["\(bar).fill_color"]
                else { continue }
                for wallpaper in ["#FFFFFF", "#000000"] {
                    let plate = try #require(
                        ColorVision.composite(
                            fill,
                            over: wallpaper
                        )
                    )
                    let gap = try #require(
                        ColorVision.separation(accent, plate)
                    )
                    #expect(
                        gap >= ColorVision.separationFloor,
                        Comment(
                            rawValue:
                                "\(palette.name) \(activePath) "
                                + "on \(wallpaper): \(gap)"
                        )
                    )
                    measured += 1
                }
            }
        }
        // Nine palettes, two bars, two wallpaper extremes — a
        // scan that measured nothing would pass for having found
        // no violations.
        #expect(measured == PaletteCatalog.bundled().count * 4)
    }
}
