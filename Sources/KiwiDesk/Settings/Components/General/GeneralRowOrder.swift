/// Display order for the General area's rows (#678 turn 14b).
///
/// The area's three containers each answer a different question,
/// which is why turn 14b calls the grouping the design rather
/// than a detail:
///
/// - `.appliesImmediately` — rows that are NOT part of a profile
///   and are untouched by the footer's Save. Grouped by that
///   rule, not by topic, because splitting them apart is what
///   let Revert look as though it would undo them (the 6b
///   audit's fourth finding).
/// - `.about` — read-only identity and the support link.
/// - `.advanced` — the config file, the Lua handover, and the two
///   destructive actions. Drawn closed on every visit.
///
/// `GeneralCensusRenderTests` pins each list against the census,
/// so a row moves by editing the census rather than by editing a
/// view.
enum GeneralRowOrder {
    /// Language, appearance, the login toggle — in the order the
    /// digest's 14b frame lists them.
    static let appliesImmediately: [SettingKey] = [
        .general(.language),
        .general(.appearance),
        .general(.startAtLogin),
    ]

    static let about: [SettingKey] = [
        // The inventory card leads: it answers "what is in this
        // install", which the identity block below then signs.
        .general(.installInventory),
        .general(.about),
    ]

    /// Advanced's rows, restart first — the digest's five plus
    /// #606's two. Drawn in ascending severity, which is the
    /// drawer's stated invariant (`GeneralSection+Reset`): the
    /// read-only export sits with the tools, and the restore is
    /// the last rung because it replaces the palettes even Reset
    /// All leaves standing.
    static let advanced: [SettingKey] = [
        .general(.advancedRestartOnCrash),
        .general(.advancedConfigFile),
        .general(.advancedEditLua),
        .general(.advancedExportBackup),
        .general(.advancedDiscardArrangement),
        .general(.advancedResetAll),
        .general(.advancedRestoreBackup),
    ]

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .appliesImmediately: appliesImmediately,
        .about: about,
        .advanced: advanced,
    ]

    /// Containers drawn as BESPOKE views rather than as a
    /// `ForEach` over the list above.
    ///
    /// All three are, today, and saying so is the point: the
    /// lists exist so the census still records these rows for the
    /// placement table and for search, and the guard holds their
    /// MEMBERSHIP — but editing one moves nothing on screen. The
    /// Shortcuts area shipped that same edge and `gui.md` warns
    /// that reading the census promise as unqualified will waste
    /// an afternoon. A container that becomes a real `ForEach`
    /// leaves this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .appliesImmediately,
        .about,
        .advanced,
    ]
}
