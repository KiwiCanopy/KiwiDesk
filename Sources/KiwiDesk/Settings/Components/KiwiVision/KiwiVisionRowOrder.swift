/// KiwiVision page row order (`KiwiVisionCensusRenderTests`,
/// #2103). Every card walks its list.
enum KiwiVisionRowOrder {
    static let levels: [SettingKey] = [
        .kiwiVision(.dim), .kiwiVision(.blur),
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

    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .kiwiVisionLevels: levels,
        .kiwiVisionClear: clear,
        .kiwiVisionNeverDimmed: neverDimmed,
        .kiwiVisionAppearance: appearance,
    ]
}
