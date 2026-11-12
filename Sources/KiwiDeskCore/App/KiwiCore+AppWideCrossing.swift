import Foundation

/// The reads both app-wide crossings share (#1741, #3237); every
/// write of the ledger stays in `KiwiCore+AppWide.swift`.
extension AppWideLedger {
    /// What a crossing ends on for the profile `name`: its captured
    /// values over the settled ones, for each crossing owed.
    func crossingValue(for name: String?) -> AppWideSettings {
        var value =
            owed.flatMap { owed in name.flatMap { owed[$0] } }
            ?? settled
        if let pace = owedPace {
            value.adoptPace(name.flatMap { pace[$0] } ?? value.animations)
        }
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
