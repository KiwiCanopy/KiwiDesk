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
            rewriting: renamed,
            editing: surgicallyRenamed
        )
    }

    /// Surgically renames the key in raw JSON text — standing
    /// down when the target key is already present, which is the
    /// one case it cannot do correctly (code-reviewer 2026-08-27):
    /// a textual rename cannot see a sibling, and a node carrying
    /// both spellings would become one key twice. The envelope's
    /// re-parse net cannot catch that — `JSONSerialization` keeps
    /// the FIRST occurrence and `.sortedKeys` puts the new key
    /// first, so the duplicate decodes right and compares equal
    /// while Foundation and `jq` read different values out of one
    /// file (measured, both ways). The tree walk handles it.
    static func surgicallyRenamed(
        _ text: String
    ) -> Data? {
        guard
            text.range(
                of: "\"\(scrollDurationKey)\"\\s*:",
                options: .regularExpression
            ) == nil
        else { return nil }
        let out = text.replacingOccurrences(
            of: "\"\(retiredScrollSpeedKey)\"(\\s*:)",
            with: "\"\(scrollDurationKey)\"$1",
            options: .regularExpression
        )
        return out == text ? nil : out.data(using: .utf8)
    }

    /// Tree walker renaming retired key; prefers new spelling when both exist.
    static func renamed(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                let (child, childChanged) = renamed(value)
                if key == retiredScrollSpeedKey {
                    if dict[scrollDurationKey] == nil {
                        out[scrollDurationKey] = child
                    }
                    changed = true
                    continue
                }
                out[key] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = renamed(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
