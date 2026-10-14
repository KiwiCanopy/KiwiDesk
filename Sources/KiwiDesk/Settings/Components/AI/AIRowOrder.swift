/// AI page row order (`AICensusRenderTests`, #1685). A ready-made
/// prompt joins `readyMadePrompts` in the PR that ships the tools
/// it needs, never earlier and never greyed (issue #1685 ▸
/// Ruling 6a): look, migration, app rules, Spaces.
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
