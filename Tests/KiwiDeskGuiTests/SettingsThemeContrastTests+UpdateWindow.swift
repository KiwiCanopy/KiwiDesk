import SwiftUI

@testable import KiwiDesk

/// The update window's pairings (#1542), measured by the one
/// contrast suite and kept here for its length: the inks over
/// the Highlights panel's gold-washed card; a tab's list and Next
/// sit on a plain card, measured by the main list's `on card`
/// rows; the tab strip's track is a segmented track, measured with
/// the chips (`chips`). The header and the footer sit on the
/// glass and draw `.primary` / `.secondary` (#3650): on the glass
/// those are the system's adaptive styles, which no fixed pairing
/// can measure, and on the page fallback `glassFallbackInks`
/// resolves them to `ink` / `ink2`, which the main list's
/// `ink on page` and `ink2 on page` rows measure (#3111). The
/// gold itself marks and never inks, so its edge is floored by
/// colour-vision separation instead (`HighlightSeparationTests`,
/// #2038).
extension SettingsThemeContrastTests {
    private static let highlightWash = (
        color: SettingsTheme.highlight,
        alpha: Double(SettingsTheme.highlightWashOpacity)
    )

    static let updateWindow: [Pairing] = [
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
        // An entry's version label when versions merge.
        Pairing(
            "ink3 on the washed Highlights",
            SettingsTheme.ink3,
            on: SettingsTheme.card,
            washedWith: highlightWash
        ),
    ]
}
