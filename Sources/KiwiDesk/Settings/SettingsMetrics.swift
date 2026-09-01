import SwiftUI

/// Shared layout metrics and column width budgets for the Settings window.
enum SettingsMetrics {
    /// Shared leading label column for sliders, pickers, and dropdowns
    /// (#94, #95, #864). Shorten labels rather than widening this number.
    static let labelColumn: CGFloat = 210

    /// Gutter around destination pane scrolling content.
    static let paneInset: CGFloat = 16

    /// Inset between the pane's content and its arrival focus
    /// ring (#996). The ring is the platform's and is drawn at
    /// the pane's bounds, so the pane holds it off its own edges
    /// rather than the ring being restyled.
    static let focusRingInset: CGFloat = 6

    /// `OverrideChrome` leading padding and checkbox spacing.
    static let overrideRowInset: CGFloat = 8

    /// Native checkbox width estimate.
    static let checkboxWidth: CGFloat = 18

    /// Label column inside `OverrideChrome` aligned to the shared axis (#95).
    static let overrideLabelColumn: CGFloat =
        labelColumn - (2 * overrideRowInset + checkboxWidth)

    /// Destination icon square tile (#678).
    static let sidebarTile: CGFloat = 22

    /// Label column for half-width drag columns (#231, #754).
    static let dragColumnLabelColumn: CGFloat = 80

    /// Trailing readout of a slider row (#406). Sized for proportional
    /// digits with `monospacedDigit()`.
    static let readoutColumn: CGFloat = 72

    /// Label column for two-column color fields grid.
    static let colorLabelColumn: CGFloat = 140

    /// Label column for color swatch inside `OverrideChrome` (#2, #135).
    static let overrideColorLabelColumn: CGFloat = 80

    /// Fixed inline hex `TextField` column beside each color swatch.
    static let colorHexColumn: CGFloat = 84

    /// Trailing override column in per-space override editor (#678).
    static let overrideStateColumn: CGFloat = 88
}

private struct SettingsLabelColumnKey: EnvironmentKey {
    static let defaultValue: CGFloat =
        SettingsMetrics.labelColumn
}

private struct OverrideLayoutNameKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    /// Label-column width read by shared settings rows.
    var settingsLabelColumn: CGFloat {
        get { self[SettingsLabelColumnKey.self] }
        set { self[SettingsLabelColumnKey.self] = newValue }
    }

    /// Active layout display name set by `SpaceOverrideRows` (#678).
    var overrideLayoutName: String {
        get { self[OverrideLayoutNameKey.self] }
        set { self[OverrideLayoutNameKey.self] = newValue }
    }
}
