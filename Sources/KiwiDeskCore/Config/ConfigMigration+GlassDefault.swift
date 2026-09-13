import Foundation

/// Fills the Liquid Glass leaves a file below the floor left
/// ABSENT (#1369, `GlassDefaultMigrationTests`).
///
/// The default flipped from off to on, so absence changed
/// meaning: absence is a stored value (profiles.md). Each absent
/// BAR leaf takes the `false` its absence meant. The PANEL had no
/// surface before v1.2.0 — no leaf a user could have set — so it
/// takes the two bars' agreement where they agree and `false`
/// otherwise: the bars are the user's stated opinion about
/// glass, and a flat `false` would mint for a glass-on setup the
/// very divergence the one Settings row (#1307) exists to make
/// unreachable. Reached by PATH — a profile root's `settings`, a
/// bundle root's `profiles[].settings`, the two shapes that carry
/// `TilingSettings` — never by the look of an object, so a
/// per-layout `app_bar` override (`settings.layout.*.app_bar`,
/// whose absent leaf means inherit) is out of reach by
/// construction.
extension ConfigMigration {
    static let glassLeafKey = "liquid_glass"
    /// Spelled here rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let glassSettingsKey = "settings"
    static let glassProfilesKey = "profiles"
    static let glassBarGroups = ["app_bar", "space_bar"]
    static let glassPanelGroup = "shortcut_panel"

    @Sendable
    static func migratingAbsentGlassLeaves(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(glassSettingsKey)\"".utf8))
                    != nil
            },
            rewriting: withGlassLeaves,
            editing: surgicallyFilledGlassLeaves
        )
    }

    /// The two paths: the root's own `settings`, and each inline
    /// profile's under `profiles`.
    static func withGlassLeaves(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[glassSettingsKey] as? [String: Any] {
            let (filled, did) = filledGlassLeaves(settings)
            if did {
                root[glassSettingsKey] = filled
                changed = true
            }
        }
        if let profiles = root[glassProfilesKey] as? [[String: Any]] {
            var out = profiles
            var did = false
            for (index, profile) in profiles.enumerated() {
                guard
                    let settings = profile[glassSettingsKey]
                        as? [String: Any]
                else { continue }
                let (filled, changedOne) = filledGlassLeaves(settings)
                guard changedOne else { continue }
                out[index][glassSettingsKey] = filled
                did = true
            }
            if did {
                root[glassProfilesKey] = out
                changed = true
            }
        }
        return (root, changed)
    }

    /// One `TilingSettings` object: the bars first, then the
    /// panel from their agreement.
    static func filledGlassLeaves(
        _ settings: [String: Any]
    ) -> ([String: Any], Bool) {
        var out = settings
        var changed = false
        func leaf(_ group: String) -> Bool? {
            (out[group] as? [String: Any])?[glassLeafKey] as? Bool
        }
        func write(_ group: String, _ value: Bool) {
            guard out[group] == nil || out[group] is [String: Any]
            else { return }
            var object = out[group] as? [String: Any] ?? [:]
            guard object[glassLeafKey] == nil else { return }
            object[glassLeafKey] = value
            out[group] = object
            changed = true
        }
        for group in glassBarGroups { write(group, false) }
        let bars = glassBarGroups.map(leaf)
        let agreed = bars[0] == bars[1] ? (bars[0] ?? false) : false
        write(glassPanelGroup, agreed)
        return (out, changed)
    }

    /// The textual edit, for the shapes a file the app or a hand
    /// wrote actually has: a group present ONCE without its leaf
    /// gets the leaf after its opener, a group absent everywhere
    /// is inserted whole after each `settings` opener, and the
    /// panel is inserted `false` — so a glass-on setup, whose
    /// panel the walk fills `true`, stands down to the walk, as
    /// does any group named twice (a per-layout override beside
    /// the global). `surgicallyApplying` re-parses whatever this
    /// returns against the walk, so a stray edit is never used.
    static func surgicallyFilledGlassLeaves(_ text: String) -> Data? {
        guard text.range(of: "\"\(glassPanelGroup)\"") == nil,
            text.range(
                of: "\"\(glassLeafKey)\"\\s*:\\s*true",
                options: .regularExpression
            ) == nil
        else { return nil }
        var out = text
        var absent: [String] = [glassPanelGroup]
        for group in glassBarGroups {
            let needle = "\"\(group)\""
            let count = out.components(separatedBy: needle).count - 1
            if count == 0 {
                absent.append(group)
            } else if count == 1,
                out.range(
                    of: "\"\(group)\"\\s*:\\s*\\{[^}]*\"\(glassLeafKey)\"",
                    options: .regularExpression
                ) == nil
            {
                out = out.replacingOccurrences(
                    of: "(\"\(group)\"\\s*:\\s*\\{)",
                    with: "$1\"\(glassLeafKey)\":false,",
                    options: .regularExpression
                )
            } else if count > 1 {
                return nil
            }
        }
        let inserted = absent.map {
            "\"\($0)\":{\"\(glassLeafKey)\":false},"
        }.joined()
        out = out.replacingOccurrences(
            of: "(\"\(glassSettingsKey)\"\\s*:\\s*\\{)",
            with: "$1" + inserted,
            options: .regularExpression
        )
        // A group inserted as the last entry of an empty object
        // leaves a trailing comma; close it.
        out = out.replacingOccurrences(
            of: ",\\s*\\}",
            with: "}",
            options: .regularExpression
        )
        return out == text ? nil : out.data(using: .utf8)
    }
}
