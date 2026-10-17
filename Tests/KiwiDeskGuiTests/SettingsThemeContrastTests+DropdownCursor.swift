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
        // The Power User tag's edge on the cursor row: a
        // non-text boundary, so the 3:1 floor.
        Pairing(
            "accentInkSecondary tag edge on a dropdown's cursor row",
            SettingsTheme.accentInkSecondary,
            on: SettingsTheme.accent,
            floor: 3.0
        ),
        // A result tile's edge there — Profiles' tile IS the
        // accent, so the edge is all that outlines it.
        Pairing(
            "accentInk tile edge on a dropdown's cursor row",
            SettingsTheme.accentInk,
            on: SettingsTheme.accent,
            floor: 3.0
        ),
    ]
}
