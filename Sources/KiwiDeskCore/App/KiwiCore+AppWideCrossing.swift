import Foundation

/// The reads both app-wide crossings share (#1741, #3237); every
/// write of the ledger stays in `KiwiCore+AppWide.swift`.
extension AppWideLedger {
    /// What a crossing ends on for the profile `name`: its captured
    /// values over the settled ones, for each crossing owed. An
    /// install still on 4.2's six lengths moves to Medium (#3254 ▸
    /// Ruling amendment). A length a file left out reads what its
    /// absence meant, 4.2's default: the four the profile capture
    /// lacks, or every four with no capture (a composed Standard, a
    /// fresh install), and the slide and fade while #1741's crossing
    /// is owed, since such a `gui.json` stores neither. Only an owed
    /// pace runs it: a file that stores the group carries the #1741
    /// groups too, so it owes neither.
    func crossingValue(for name: String?) -> AppWideSettings {
        var value =
            owed.flatMap { owed in name.flatMap { owed[$0] } }
            ?? settled
        guard let pace = owedPace else { return value }
        let legacy = AnimationPacePreset.legacyDefaults
        if owed != nil { value.adoptLegacySlideAndFade() }
        value.adoptPace(AppWideSettings.Animations.legacyDefaults)
        if let captured = name.flatMap({ pace[$0] }) {
            value.adoptPace(captured)
        }
        if value.paceTable == legacy { value.applyPace(.medium) }
        return value
    }

    /// `data` without #1741's groups and #3237's lengths, nil when
    /// it carries neither.
    static func withoutRetiredAppWide(_ data: Data) -> Data? {
        let groups = ConfigMigration.withoutLegacyAppWide(data)
        let pace = ConfigMigration.withoutLegacyPace(groups ?? data)
        return pace ?? groups
    }
}
