import CoreGraphics

/// Shape and dimension metrics for `SettingsTheme`
/// (`SettingsThemeMetricTests`, `SettingsThemeTokenTests`,
/// `SettingsThemeWiringTests`).
extension SettingsTheme {

    /// Home card corner radius.
    static let cardRadius: CGFloat = 14

    /// Home card heights for profile cards with plate vs compact
    /// (`HomeCardChromeTests`, #786).
    static let cardHeight: CGFloat = 152
    static let cardHeightCompact: CGFloat = 105

    /// Desktop plate height in profile card.
    static let plateHeight: CGFloat = 92

    /// Detail panel fixed column width.
    static let panelWidth: CGFloat = 392

    /// Content column maximum width ceiling.
    static let contentMaxWidth: CGFloat = 980

    /// Section container corner radius.
    static let sectionRadius: CGFloat = 16

    /// Disclosure interior corner radius.
    static let disclosureRadius: CGFloat = 12

    /// Chip corner radius.
    static let chipRadius: CGFloat = 9

    /// Monitors picture card stroke weights at rest and selected
    /// (`MonitorsChromeWiringTests`, #758).
    static let monitorCardStroke: CGFloat = 1.5
    static let monitorCardStrokeSelected: CGFloat = 3

    /// Palette tile stroke weights at rest and applied
    /// (`PaletteShelfChromeTests`, #757).
    static let paletteCardStroke: CGFloat = 1
    static let paletteCardStrokeApplied: CGFloat = 2

    /// Container border weights at rest and when presence is mode-gated
    /// (`ModeGatedChromeTests`, `ModeGatedFrameSeparationTests`, #760).
    static let containerStroke: CGFloat = 1
    static let containerStrokeModeGated: CGFloat = 1.5

    /// Mode-gated frame accent stroke opacity
    /// (`ModeGatedFrameSeparationTests`).
    static let modeGatedStrokeOpacity: CGFloat = 0.6

    /// Search mode-switch notice accent fill opacity
    /// (`SettingsSearchNotice`, #678).
    static let searchNoticeFillOpacity: CGFloat = 0.12

    /// Display card stand scale and clamp metrics
    /// (`MonitorsChromeWiringTests`, #758).
    static let monitorStandScale: CGFloat = 0.52
    static let monitorStandMin: CGFloat = 44
    static let monitorStandMax: CGFloat = 320
    static let monitorNeckScale: CGFloat = 0.26
    static let monitorNeckMin: CGFloat = 14
    static let monitorNeckMax: CGFloat = 44
}
