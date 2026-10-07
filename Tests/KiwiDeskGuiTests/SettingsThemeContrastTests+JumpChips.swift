import SwiftUI
import Testing

@testable import KiwiDesk

/// The Shortcuts & Gestures jump chips' pairings (#1520), measured
/// by the one contrast suite and kept here for their length: the
/// label over the chip's rest fill, its hover lift and its press
/// on the bar's page ground, each with and without the marked
/// chip's accent wash above it. The fills are per-appearance
/// tokens, so they are layered at the alpha each resolves to.
extension SettingsThemeContrastTests {
    private static let markedWash = (
        color: SettingsTheme.accent,
        alpha: Double(SettingsTheme.jumpChipMarkedOpacity)
    )

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
            layers: [SettingsTheme.chipRest],
            washedWith: markedWash
        ),
        Pairing(
            "ink on the hovered marked jump chip",
            SettingsTheme.ink,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipHover],
            washedWith: markedWash
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
            layers: [SettingsTheme.chipPressed],
            washedWith: markedWash
        ),
    ]

    /// The chip's edge is what tells a button chip from a passive
    /// hairline capsule (#1520 amendment 5), so it must separate
    /// from the rest fill it rims by more than the container
    /// hairline separates from the page — in both appearances.
    @Test("the jump chip's edge outreads the container hairline")
    func chipEdgeOutreadsHairline() throws {
        for dark in [false, true] {
            let edge = try ThemeContrast.contrast(
                SettingsTheme.chipEdge,
                over: SettingsTheme.page,
                layers: [SettingsTheme.chipRest],
                inkAlpha: try ThemeContrast.resolvedAlpha(
                    SettingsTheme.chipEdge,
                    dark: dark
                ),
                dark: dark
            )
            let hairline = try ThemeContrast.contrast(
                SettingsTheme.hairline,
                over: SettingsTheme.page,
                inkAlpha: 1,
                dark: dark
            )
            #expect(
                edge > hairline,
                Comment(
                    rawValue: (dark ? "dark" : "light")
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
