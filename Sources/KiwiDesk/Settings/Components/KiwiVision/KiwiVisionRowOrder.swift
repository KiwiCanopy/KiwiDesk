/// KiwiVision page row order (`KiwiVisionCensusRenderTests`,
/// #2103). Both cards walk their lists.
enum KiwiVisionRowOrder {
    static let levels: [SettingKey] = [
        .kiwiVision(.dim), .kiwiVision(.blur),
    ]

    static let appearance: [SettingKey] = [
        .kiwiVision(.appearance)
    ]

    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .kiwiVisionLevels: levels,
        .kiwiVisionAppearance: appearance,
    ]
}
