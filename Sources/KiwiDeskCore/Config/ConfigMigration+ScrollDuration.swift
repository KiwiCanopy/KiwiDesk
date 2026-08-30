import Foundation

/// Migrates `animations.scroll_speed` to `scroll_duration` (#1020,
/// `ConfigMigrationRoutingTests`, `ScrollDurationMigrationTests`).
extension ConfigMigration {
    /// Retired key name and replacement target (#1020).
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

    /// Surgically renames key in raw JSON text (stands down if target present,
    /// code-reviewer 2026-08-27).
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
