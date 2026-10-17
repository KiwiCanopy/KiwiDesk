import SwiftUI
import Testing

@testable import KiwiDesk

/// A searchable dropdown's cursor row (owner ruling 2026-10-17):
/// solid accent with fixed inks in both modes, the pair KiwiHub's
/// selected row measures, named here for the surfaces that draw
/// them (`DropdownRowStyle`; `DropdownCursorWiringTests` holds the
/// rows to these inks).
extension SettingsThemeContrastTests {
    static let dropdownCursor: [Pairing] = [
        // A header result's title, an app's name, the escape, a
        // font family's name and the stored family's ✓.
        Pairing(
            "accentInk on a dropdown's cursor row",
            SettingsTheme.accentInk,
            on: SettingsTheme.accent
        ),
        // A header result's breadcrumb, value and Power User tag,
        // and a guessed app's window caption.
        Pairing(
            "accentInkSecondary on a dropdown's cursor row",
            SettingsTheme.accentInkSecondary,
            on: SettingsTheme.accent
        ),
    ]
}
