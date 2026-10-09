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

    /// Screens picture card stroke weights at rest and selected
    /// (`ScreensChromeWiringTests`, #758).
    static let screenCardStroke: CGFloat = 1.5
    static let screenCardStrokeSelected: CGFloat = 3

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

    /// The marked jump chip's accent wash over `page`
    /// (`SettingsThemeContrastTests`, #1520).
    static let jumpChipMarkedOpacity: CGFloat = 0.18

    /// The update window's Highlights wash over `card`
    /// (`SettingsThemeContrastTests`, #1542).
    static let highlightWashOpacity: CGFloat = 0.06

    /// Screen card stand scale and clamp metrics
    /// (`ScreensChromeWiringTests`, #758).
    static let screenStandScale: CGFloat = 0.52
    static let screenStandMin: CGFloat = 44
    static let screenStandMax: CGFloat = 320
    static let screenNeckScale: CGFloat = 0.26
    static let screenNeckMin: CGFloat = 14
    static let screenNeckMax: CGFloat = 44
}
