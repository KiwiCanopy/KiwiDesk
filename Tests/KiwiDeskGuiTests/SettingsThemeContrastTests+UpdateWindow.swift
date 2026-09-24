import SwiftUI

@testable import KiwiDesk

/// The update window's pairings (#1542), measured by the one
/// contrast suite and kept here for its length: the Highlights
/// panel's gold edge and inks over its gold-washed card, the
/// tally's heading on the page, the failed glyph on the footer.
extension SettingsThemeContrastTests {
    private static let highlightWash = (
        color: SettingsTheme.highlight,
        alpha: Double(SettingsTheme.highlightWashOpacity)
    )

    static let updateWindow: [Pairing] = [
        Pairing(
            "highlight edge on the washed Highlights",
            SettingsTheme.highlight,
            on: SettingsTheme.card,
            washedWith: highlightWash,
            floor: 3.0
        ),
        Pairing(
            "ink on the washed Highlights",
            SettingsTheme.ink,
            on: SettingsTheme.card,
            washedWith: highlightWash
        ),
        Pairing(
            "ink2 on the washed Highlights",
            SettingsTheme.ink2,
            on: SettingsTheme.card,
            washedWith: highlightWash
        ),
        Pairing(
            "groupHeading on page",
            SettingsTheme.groupHeading,
            on: SettingsTheme.page
        ),
        Pairing(
            "warningInk glyph on panel",
            SettingsTheme.warningInk,
            on: SettingsTheme.panel,
            floor: 3.0
        ),
    ]
}
