/// KiwiVision page row order (`KiwiVisionCensusRenderTests`,
/// #2103). Every card walks its list, save the bespoke ones.
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

    /// One setting, a page per live lens (Profiles' shape).
    static let lenses: [SettingKey] = [.kiwiVision(.lenses)]

    /// Containers that draw a page per live instance rather than
    /// walking their list — the lens strip, Profiles' shape.
    static let bespokeContainers: Set<SettingsContainer> = [
        .kiwiVisionLenses
    ]

    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .kiwiVisionLevels: levels,
        .kiwiVisionClear: clear,
        .kiwiVisionNeverDimmed: neverDimmed,
        .kiwiVisionAppearance: appearance,
        .kiwiVisionLenses: lenses,
    ]
}
