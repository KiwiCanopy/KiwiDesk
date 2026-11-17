import SwiftUI
import Testing

@testable import KiwiDesk

/// The Shortcuts jump chips' pairings (#1520) and the
/// icon picker cells that share their mark, measured
/// by the one contrast suite and kept here for their length: the
/// label over the chip's rest fill, its hover lift and its press
/// on the bar's page ground, each with and without the marked
/// chip's accent wash above it. The fills are per-appearance
/// tokens, so they are layered at the alpha each resolves to.
extension SettingsThemeContrastTests {
    static let jumpChips: [Pairing] = [
        Pairing(
            "ink on a resting jump chip",
            SettingsTheme.ink,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipRest]
        ),
        Pairing(
            "ink on a hovered jump chip",
            SettingsTheme.ink,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipHover]
        ),
        Pairing(
            "ink on the marked jump chip",
            SettingsTheme.ink,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipRest, SettingsTheme.chipMarked]
        ),
        Pairing(
            "ink on the hovered marked jump chip",
            SettingsTheme.ink,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipHover, SettingsTheme.chipMarked]
        ),
        Pairing(
            "ink on a pressed jump chip",
            SettingsTheme.ink,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipPressed]
        ),
        Pairing(
            "ink on the pressed marked jump chip",
            SettingsTheme.ink,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipPressed, SettingsTheme.chipMarked]
        ),
        // The icon picker's cells take the same rest, press and
        // mark on its popover, measured on `card` as the nearest
        // token to that popover's material fallback; the glass
        // composite has no token to measure.
        Pairing(
            "ink on the marked icon cell",
            SettingsTheme.ink,
            on: SettingsTheme.card,
            layers: [SettingsTheme.chipRest, SettingsTheme.iconCellMarked]
        ),
        // A cell carries a glyph, not text, so its transient press
        // takes the non-text floor; at rest it keeps 4.5 (5.0.0).
        Pairing(
            "ink on the pressed marked icon cell",
            SettingsTheme.ink,
            on: SettingsTheme.card,
            layers: [
                SettingsTheme.chipPressed, SettingsTheme.iconCellMarked,
            ],
            floor: 3
        ),
    ]

    /// The chip's edge is what tells a button chip from a passive
    /// hairline capsule (#1520 amendment 5), so it must separate
    /// from the rest fill it rims by more than the container
    /// hairline separates from the same ground — in both
    /// appearances, on every ground a button chip stands on
    /// (#2047).
    @Test("a button chip's edge outreads the container hairline")
    func chipEdgeOutreadsHairline() throws {
        let grounds = [
            ("page", SettingsTheme.page),
            ("card", SettingsTheme.card),
            ("sunken", SettingsTheme.sunken),
        ]
        for (name, ground) in grounds {
            for dark in [false, true] {
                let edge = try ThemeContrast.contrast(
                    SettingsTheme.chipEdge,
                    over: ground,
                    layers: [SettingsTheme.chipRest],
                    inkAlpha: try ThemeContrast.resolvedAlpha(
                        SettingsTheme.chipEdge,
                        dark: dark
                    ),
                    dark: dark
                )
                let hairline = try ThemeContrast.contrast(
                    SettingsTheme.hairline,
                    over: ground,
                    inkAlpha: 1,
                    dark: dark
                )
                #expect(
                    edge > hairline,
                    Comment(
                        rawValue: "\(name) "
                            + (dark ? "dark" : "light")
                            + String(
                                format: ": edge %.2f, hairline %.2f",
                                edge,
                                hairline
                            )
                    )
                )
            }
        }
    }
}
