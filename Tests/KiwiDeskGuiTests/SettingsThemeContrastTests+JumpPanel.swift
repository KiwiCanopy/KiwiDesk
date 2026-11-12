import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// Jump to window's selected row (#1875 ▸ Ruling — the selected
/// row is the kiwi accent): an opaque accent fill whose inks are
/// one value, measured on each mode's fill. The panel's ground is
/// glass, which has no hex, so `hubGround` stands in for it — the
/// nearest opaque match for the `.regularMaterial` fallback. A
/// proxy: the glass branch is a device check.
extension SettingsThemeContrastTests {
    /// Fixed here, never a Settings surface: the Settings page's
    /// black does not move the glass, and measuring on it would
    /// flatter every ink above.
    private static let hubGround = Color(
        nsColor: NSColor(name: nil) { appearance in
            let isDark =
                appearance.bestMatch(from: [.aqua, .darkAqua])
                == .darkAqua
            return isDark
                ? NSColor(
                    srgbRed: 0x17 / 255,
                    green: 0x1C / 255,
                    blue: 0x19 / 255,
                    alpha: 1
                )
                : NSColor(
                    srgbRed: 0xFB / 255,
                    green: 0xFC / 255,
                    blue: 0xFA / 255,
                    alpha: 1
                )
        }
    )

    static let jumpPanel: [Pairing] = [
        Pairing(
            "accentInk on the selected Jump to window row",
            SettingsTheme.accentInk,
            on: SettingsTheme.accent
        ),
        Pairing(
            "accentInkSecondary on the selected Jump to window row",
            SettingsTheme.accentInkSecondary,
            on: SettingsTheme.accent
        ),
        // A row, tile or chip the pointer lifts (#2365): its
        // vibrant `.secondary` and `.tertiary` stand as `ink2` and
        // `ink3`; `.primary` on both lifts is the jump chips' `ink`.
        Pairing(
            "ink2 on a lifted KiwiHub row",
            SettingsTheme.ink2,
            on: hubGround,
            layers: [SettingsTheme.chipRest]
        ),
        Pairing(
            "ink2 on a lifted KiwiHub chip",
            SettingsTheme.ink2,
            on: hubGround,
            layers: [SettingsTheme.chipHover]
        ),
        // `.tertiary` names an item that cannot be applied: the
        // disabled floor.
        Pairing(
            "ink3 on a lifted KiwiHub chip",
            SettingsTheme.ink3,
            on: hubGround,
            layers: [SettingsTheme.chipHover],
            floor: 3.0
        ),
        // The scope switch's chord hints (#2245): the selected
        // segment's takes its title's ink on the accent (#3172),
        // and a hovered one's is `ink`, both of which the segment
        // pairings measure.
        Pairing(
            "ink2 chord on the Jump scope switch's track",
            SettingsTheme.ink2,
            on: hubGround,
            layers: [SettingsTheme.trackFill]
        ),
    ]

    /// The fill must read as a selection against the panel's ground
    /// — more than the container hairline separates from it, by
    /// luminance, which no colour-vision deficiency removes.
    @Test("the selected Jump row outreads the container hairline")
    func jumpSelectionOutreadsHairline() throws {
        for dark in [false, true] {
            let fill = try ThemeContrast.contrast(
                SettingsTheme.accent,
                over: Self.hubGround,
                inkAlpha: 1,
                dark: dark
            )
            let hairline = try ThemeContrast.contrast(
                SettingsTheme.hairline,
                over: Self.hubGround,
                inkAlpha: 1,
                dark: dark
            )
            #expect(
                fill > hairline,
                Comment(
                    rawValue: (dark ? "dark" : "light")
                        + String(
                            format: ": fill %.2f, hairline %.2f",
                            fill,
                            hairline
                        )
                )
            )
        }
    }

    /// The clauses above measure the token; this holds the row to
    /// drawing it, or a swapped fill passes both.
    @Test("the Jump row draws the measured selection fill")
    func jumpRowDrawsTheMeasuredFill() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpRowView.swift"
                    ),
                encoding: .utf8
            )
        )
        // The selection's fill, and the hover lift (#2365), both
        // through KiwiHub's paint (#2569), whose defaults are the
        // measured tokens.
        #expect(source.occurrences(of: ".fill(paint.fill(") == 2)
        // Each faded fill spells `.fill(` twice; no third fill hides.
        #expect(
            source.occurrences(of: ".fill(")
                == 2 * source.occurrences(of: ".fill(paint.fill(")
        )
        #expect(source.occurrences(of: ".fill(paint.selection)") == 1)
        #expect(source.occurrences(of: ".fill(paint.rowHover)") == 1)
        let paint = try Self.hubPaint()
        #expect(paint.contains("var selection = SettingsTheme.accent\n"))
        #expect(paint.contains("var rowHover = SettingsTheme.chipRest\n"))
    }

    /// `KiwiHubPaint`'s source, comments stripped.
    private static func hubPaint() throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/KiwiHubPaint.swift"
                    ),
                encoding: .utf8
            )
        )
    }

    /// The row draws its measured inks on the fill, never the
    /// vibrant styles, which move with the appearance.
    @Test("the selected Jump row draws its measured inks")
    func jumpRowDrawsTheMeasuredInks() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpRowView.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(source.contains("paint.selectionInk)"))
        #expect(source.contains("paint.selectionInkSecondary)"))
        let paint = try Self.hubPaint()
        #expect(paint.contains("var selectionInk = SettingsTheme.accentInk\n"))
        #expect(
            paint.contains(
                "var selectionInkSecondary = SettingsTheme.accentInkSecondary"
            )
        )
    }
}

/// An untinted KiwiHub's filled row (#3264): a tile's hover lifts in
/// `accentInk` at the paint's `filledLift` over the `accent` fill, the
/// lift its polarity picks, and separates by `ColorVision`'s floor in
/// both appearances. The tinted palettes are
/// `HighlightFadeContrastTests`'.
extension SettingsThemeContrastTests {
    @Test("a hover on a filled KiwiHub row separates from the fill")
    func filledRowLiftSeparates() throws {
        let paint = KiwiHubPaint()
        for dark in [false, true] {
            let row = try Self.opaqueHex(paint.selection, dark: dark)
            let ink = try Self.opaqueHex(paint.selectionInk, dark: dark)
            #expect(paint.filledLift == KiwiShelf.filledRowLift(ink: ink))
            let alpha = String(
                format: "%02X",
                Int((paint.filledLift * 255).rounded())
            )
            let lifted = try #require(
                ColorVision.composite(ink + alpha, over: row)
            )
            let separation = try #require(
                ColorVision.separation(lifted, row)
            )
            #expect(
                separation >= ColorVision.separationFloor,
                Comment(
                    rawValue: (dark ? "dark" : "light")
                        + String(format: ": %.1f", separation)
                )
            )
        }
    }

    /// A tinted paint takes the lift its palette's ink picks, and some
    /// bundled palette's ink is light, so the dark default cannot pass
    /// for it (#3264).
    @Test("a tinted paint's lift follows its ink")
    func tintedLiftFollowsTheInk() {
        var light = 0
        for palette in PaletteCatalog.bundled() {
            var settings = TilingSettings()
            palette.apply(to: &settings)
            let shelf = settings.kiwishelf
            let paint = KiwiHubPaint(
                shelf,
                divider: "#FFFFFF33",
                axis: nil,
                increaseContrast: false
            )
            let ink = shelf.panelHighlight.selectionInk
            #expect(
                paint.filledLift == KiwiShelf.filledRowLift(ink: ink),
                "\(palette.name)"
            )
            if KiwiShelf.filledRowLift(ink: ink) == KiwiShelf.lightInkLift {
                light += 1
            }
        }
        #expect(light > 0)
    }

    /// A token resolved in one appearance, as `#RRGGBB`.
    private static func opaqueHex(
        _ color: Color,
        dark: Bool
    ) throws -> String {
        let rgb = try ThemeContrast.resolved(color, dark: dark)
        return "#"
            + [rgb.r, rgb.g, rgb.b]
            .map { String(format: "%02X", Int(($0 * 255).rounded())) }
            .joined()
    }
}
