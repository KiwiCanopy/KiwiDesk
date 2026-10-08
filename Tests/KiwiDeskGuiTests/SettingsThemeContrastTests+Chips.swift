import SwiftUI
import Testing

@testable import KiwiDesk

/// The chip tiers' pairings (#2047), measured by the one contrast
/// suite and kept here for their length: each tier's ink over the
/// fills it layers on the grounds it is drawn on. The fills are
/// per-appearance tokens, so they are layered at the alpha each
/// resolves to.
extension SettingsThemeContrastTests {
    /// A segmented control's unselected label over its track, and
    /// over the hover lift above it, on every ground a picker
    /// stands on — the update window's tab strip on the page.
    private static let segments: [Pairing] =
        [
            ("card", SettingsTheme.card),
            ("sunken", SettingsTheme.sunken),
            ("page", SettingsTheme.page),
        ].flatMap { name, ground in
            [
                Pairing(
                    "ink on a segmented track on \(name)",
                    SettingsTheme.ink,
                    on: ground,
                    layers: [SettingsTheme.trackFill]
                ),
                Pairing(
                    "ink on a hovered segment on \(name)",
                    SettingsTheme.ink,
                    on: ground,
                    layers: [
                        SettingsTheme.trackFill,
                        SettingsTheme.chipRest,
                    ]
                ),
            ]
        }

    static let chips: [Pairing] = segments
}
