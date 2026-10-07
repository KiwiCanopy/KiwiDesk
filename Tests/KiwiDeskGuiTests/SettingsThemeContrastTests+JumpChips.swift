import SwiftUI

@testable import KiwiDesk

/// The Shortcuts & Gestures jump chips' pairings (#1520), measured
/// by the one contrast suite and kept here for their length: the
/// label over the chip's rest fill and its hover lift on the bar's
/// page ground, each with and without the marked chip's accent
/// wash above it. The fills are per-appearance tokens, so they are
/// layered at the alpha each resolves to.
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
    ]
}
