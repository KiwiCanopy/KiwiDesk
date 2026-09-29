import Foundation

/// Migrates `animations.scroll_speed` to `scroll_duration`
/// (#1020, `ConfigMigrationRoutingTests`,
/// `ScrollDurationMigrationTests`). The failure this prevents is
/// SILENT: `AnimationSettings` decodes with
/// `decodeIfPresent ?? 150`, so a file still carrying the old key
/// decodes "successfully" with the user's tuned value replaced by
/// the default, then saves back without the old key.
extension ConfigMigration {
    /// Retired key name and replacement target (#1020). The
    /// TARGET is spelled here rather than derived from
    /// `AnimationSettings.CodingKeys`, deliberately: a historical
    /// step must keep emitting the name it was written to emit so
    /// a LATER rename composes on top — derived, it would skip
    /// every intermediate crossing. The routing guard's set
    /// equality reds if the live key stops being declared.
    static let retiredScrollSpeedKey = "scroll_speed"
    static let scrollDurationKey = "scroll_duration"

    /// Migrates data containing retired `scroll_speed` key to
    /// `scroll_duration`.
    @Sendable
    static func migratingRetiredScrollSpeed(
        _ data: Data
    ) -> Data? {
        let needle = Data("\"\(retiredScrollSpeedKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: {
                renamingKey(
                    retiredScrollSpeedKey,
                    to: scrollDurationKey,
                    in: $0
                )
            },
            editing: {
                surgicallyRenamingKey(
                    retiredScrollSpeedKey,
                    to: scrollDurationKey,
                    in: $0
                )
            }
        )
    }
}
