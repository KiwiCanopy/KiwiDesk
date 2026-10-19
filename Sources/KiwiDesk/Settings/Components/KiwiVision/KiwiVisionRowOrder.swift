/// KiwiVision page row order (`KiwiVisionCensusRenderTests`,
/// #2103). Every card walks its list, save the lens strip's one
/// key, which draws a page per live lens (`KiwiVisionLensWiringTests`).
enum KiwiVisionRowOrder {
    static let levels: [SettingKey] = [
        .kiwiVision(.dim), .kiwiVision(.blur),
        .kiwiVision(.fadeDuration), .kiwiVision(.fadeCurve),
    ]

    static let clear: [SettingKey] = [
        .kiwiVision(.clearApp), .kiwiVision(.clearWallpaper),
    ]

    static let neverDimmed: [SettingKey] = [
        .kiwiVision(.neverDimmed)
    ]

    static let appearance: [SettingKey] = [
        .kiwiVision(.appearance)
    ]

    /// One setting, a page per live lens (Profiles' shape).
    static let lenses: [SettingKey] = [.kiwiVision(.lenses)]

    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .kiwiVisionLevels: levels,
        .kiwiVisionClear: clear,
        .kiwiVisionNeverDimmed: neverDimmed,
        .kiwiVisionAppearance: appearance,
        .kiwiVisionLenses: lenses,
    ]
}
