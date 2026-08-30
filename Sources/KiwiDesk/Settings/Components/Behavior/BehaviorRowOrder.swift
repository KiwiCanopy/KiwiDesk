/// Display order for the Behaviour settings area (#678,
/// `BehaviorCensusRenderTests`).
enum BehaviorRowOrder {
    /// The mouse card, top to bottom.
    static let mouse: [SettingKey] = [
        .behaviour(.mouseResize),
        .behaviour(.mouseFollowsFocus),
    ]

    /// The on-quit card.
    static let onQuit: [SettingKey] = [
        .behaviour(.quitGridTargetDepth)
    ]

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .mouse: mouse,
        .onQuit: onQuit,
    ]

    /// Containers rendered via bespoke views rather than static lists.
    static let bespokeContainers: Set<SettingsContainer> = [
        .mouse,
        .onQuit,
    ]
}
