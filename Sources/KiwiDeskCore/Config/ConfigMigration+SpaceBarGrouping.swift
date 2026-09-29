import Foundation

/// Writes `group_adjacent_windows: true` into every Space Bar a
/// file below the floor carries (#1725, `SpaceBarGroupingMigrationTests`,
/// `ConfigMigrationRoutingTests`): the default flipped to off, and
/// an absent key used to mean grouped, so a profile saved before
/// keeps the grouping it had (owner ruling 2026-09-29). By PATH —
/// a profile root's `settings` and a bundle root's
/// `profiles[].settings`; `gui.json` carries no settings.
extension ConfigMigration {
    /// Spelled here rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let groupingKey = "group_adjacent_windows"
    static let groupingBar = "space_bar"
    /// The formats this step introduced — a profile's and a
    /// bundle's — spelled as history. A file at or above them was
    /// written after the flip, where an absent key MEANS off.
    static let groupingProfileFormat = 14
    static let groupingBundleFormat = 19

    @Sendable
    static func migratingSpaceBarGrouping(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: groupingProfileFormat,
                bundle: groupingBundleFormat
            )
        else { return nil }
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(glassSettingsKey)\"".utf8))
                    != nil
            },
            rewriting: withSpaceBarGrouping,
            editing: surgicallyFilledGrouping
        )
    }

    /// The two paths: the root's own `settings`, and each inline
    /// profile's under `profiles`.
    static func withSpaceBarGrouping(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[glassSettingsKey] as? [String: Any],
            let filled = filledGrouping(settings)
        {
            root[glassSettingsKey] = filled
            changed = true
        }
        if var profiles = root[glassProfilesKey] as? [[String: Any]] {
            var did = false
            for index in profiles.indices {
                guard
                    let settings = profiles[index][glassSettingsKey]
                        as? [String: Any],
                    let filled = filledGrouping(settings)
                else { continue }
                profiles[index][glassSettingsKey] = filled
                did = true
            }
            if did {
                root[glassProfilesKey] = profiles
                changed = true
            }
        }
        return (root, changed)
    }

    /// One `TilingSettings` object with its Space Bar's key
    /// filled, or nil where it already states one.
    static func filledGrouping(
        _ settings: [String: Any]
    ) -> [String: Any]? {
        guard
            settings[groupingBar] == nil
                || settings[groupingBar] is [String: Any]
        else { return nil }
        var bar = settings[groupingBar] as? [String: Any] ?? [:]
        guard bar[groupingKey] == nil else { return nil }
        bar[groupingKey] = true
        var out = settings
        out[groupingBar] = bar
        return out
    }

    /// The textual edit, for the two shapes a file has: every
    /// `settings` holding a flat `space_bar` missing the key, which
    /// takes it first; or no `space_bar` anywhere, where each
    /// `settings` takes the whole object. A mix, a Space Bar
    /// already stating it or one holding a nested object stands
    /// down to the walk, and the envelope compares whatever this
    /// returns against the walk.
    static func surgicallyFilledGrouping(_ text: String) -> Data? {
        let opener = "\"\(groupingBar)\"\\s*:\\s*\\{"
        let settingsOpener = "(\"\(glassSettingsKey)\"\\s*:\\s*\\{)"
        let bodies = captures("\(opener)([^{}]*)\\}", in: text)
        let openers = captures("(\(opener))", in: text)
        let settings = captures(settingsOpener, in: text)
        guard !settings.isEmpty else { return nil }
        let out: String
        if openers.isEmpty {
            out = insertingAfterEach(
                "\"\(groupingBar)\":{\"\(groupingKey)\":true}",
                pattern: settingsOpener + "(\\s*\\})?",
                in: text
            )
        } else {
            guard bodies.count == openers.count,
                bodies.count == settings.count,
                !bodies.contains(where: { $0.contains(groupingKey) })
            else { return nil }
            out = insertingAfterEach(
                "\"\(groupingKey)\":true",
                pattern: "(\(opener))(\\s*\\})?",
                in: text
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
