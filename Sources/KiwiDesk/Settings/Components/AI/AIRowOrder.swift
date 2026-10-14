/// AI page row order (`AICensusRenderTests`, #1685). A ready-made
/// prompt is listed only once the tools it needs exist, never
/// greyed before (issue #1685 ▸ Ruling 6a).
enum AIRowOrder {
    static let setup: [SettingKey] = [.ai(.copySetupPrompt)]

    static let readyMadePrompts: [SettingKey] = [
        .ai(.promptSpaces)
    ]

    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .aiSetup: setup,
        .readyMadePrompts: readyMadePrompts,
    ]

    /// The setup card draws its one row by hand.
    static let bespokeContainers: Set<SettingsContainer> = [.aiSetup]
}
