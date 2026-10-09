import Foundation

/// Turns a stored `animations.on_space_change: false` on once, in a
/// file below the floor (#1931, `SpaceChangeOnMigrationTests`): an
/// encoder that writes `animations` whole stored the old default in
/// nearly every file, so the value cannot be told from a choice —
/// save where the master was switched off, which keeps its `false`.
/// Reaches a profile root's `settings` and a bundle root's
/// `profiles[].settings` by PATH, as the glass fill does.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let spaceChangeGroupKey = "animations"
    static let spaceChangeLeafKey = "on_space_change"
    /// The leaves 2.1.1's animations master wrote off with the
    /// slide (`MotionCard.animationsMasterBinding` at v2.1.1).
    static let spaceChangeMasterLeaves = [
        "on_window_resize", "on_window_swap", "on_relayout",
    ]
    /// The formats this step introduced, a profile's and a
    /// bundle's: a turned-on `true` is the same bytes as a chosen
    /// one, so without this gate a `false` chosen after the
    /// crossing would be turned on again by the next bump.
    static let spaceChangeOnProfileFormat = 19
    static let spaceChangeOnBundleFormat = 24

    @Sendable
    static func migratingSpaceChangeOn(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: spaceChangeOnProfileFormat,
                bundle: spaceChangeOnBundleFormat
            )
        else { return nil }
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(glassSettingsKey)\"".utf8))
                    != nil
            },
            rewriting: withSpaceChangeOn,
            editing: surgicallyTurnedOnSpaceChange
        )
    }

    /// The two paths: the root's own `settings`, and each inline
    /// profile's under `profiles`.
    static func withSpaceChangeOn(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[glassSettingsKey] as? [String: Any],
            let on = settingsWithSpaceChangeOn(settings)
        {
            root[glassSettingsKey] = on
            changed = true
        }
        if var profiles = root[glassProfilesKey] as? [[String: Any]] {
            var did = false
            for (index, profile) in profiles.enumerated() {
                guard
                    let settings = profile[glassSettingsKey]
                        as? [String: Any],
                    let on = settingsWithSpaceChangeOn(settings)
                else { continue }
                profiles[index][glassSettingsKey] = on
                did = true
            }
            if did {
                root[glassProfilesKey] = profiles
                changed = true
            }
        }
        return (root, changed)
    }

    /// One `TilingSettings` object with its group turned on, or nil.
    static func settingsWithSpaceChangeOn(
        _ settings: [String: Any]
    ) -> [String: Any]? {
        guard
            let group = settings[spaceChangeGroupKey] as? [String: Any],
            let on = turnedOnSpaceChange(group)
        else { return nil }
        var out = settings
        out[spaceChangeGroupKey] = on
        return out
    }

    /// `group` with the leaf turned on, or nil where it stays: the
    /// leaf already on or absent, or every master leaf off.
    static func turnedOnSpaceChange(
        _ group: [String: Any]
    ) -> [String: Any]? {
        guard group[spaceChangeLeafKey] as? Bool == false,
            spaceChangeMasterLeaves.contains(where: {
                group[$0] as? Bool ?? true
            })
        else { return nil }
        var out = group
        out[spaceChangeLeafKey] = true
        return out
    }

    /// The textual edit: each `animations` object the walk would
    /// turn on has its leaf's `false` replaced where it stands —
    /// by KEY, safe while `TilingSettings` alone declares the group
    /// (`ConfigMigrationGlassRoutingTests` ▸ the `animations`
    /// declarers). The group holds no nested object, so one brace
    /// pair bounds it.
    private static func surgicallyTurnedOnSpaceChange(
        _ text: String
    ) -> Data? {
        guard
            let regex = try? NSRegularExpression(
                pattern: "\"\(spaceChangeGroupKey)\"\\s*:\\s*(\\{[^{}]*\\})"
            )
        else { return nil }
        var out = text
        let whole = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: whole).reversed() {
            guard let range = Range(match.range(at: 1), in: out),
                let group = try? JSONSerialization.jsonObject(
                    with: Data(out[range].utf8)
                ) as? [String: Any],
                turnedOnSpaceChange(group) != nil
            else { continue }
            out.replaceSubrange(
                range,
                with: out[range].replacingOccurrences(
                    of: "(\"\(spaceChangeLeafKey)\"\\s*:\\s*)false",
                    with: "$1true",
                    options: .regularExpression
                )
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
