import Foundation

/// Fills the Liquid Glass leaves a file below the floor left
/// ABSENT (#1369, `GlassDefaultMigrationTests`).
///
/// The default flipped from off to on, so absence changed
/// meaning: under every earlier build an absent
/// `app_bar.liquid_glass`, `space_bar.liquid_glass` or
/// `shortcut_panel.liquid_glass` read as off — the panel's group
/// did not exist before v1.2.0 at all. Each is written as the
/// `false` it meant, so an existing setup keeps the look it had
/// and the one Settings row (#1307) finds its three leaves in
/// agreement; only a fresh seed takes the new default.
extension ConfigMigration {
    static let glassLeafKey = "liquid_glass"
    /// The three groups, spelled here rather than derived: a
    /// historical step keeps naming what it was written to name.
    static let glassGroups = ["app_bar", "space_bar", "shortcut_panel"]

    @Sendable
    static func migratingAbsentGlassLeaves(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            gate: { $0.range(of: Data("\"space_bar\"".utf8)) != nil },
            rewriting: withGlassLeaves,
            editing: surgicallyFilledGlassLeaves
        )
    }

    /// Tree walker: a `TilingSettings`-shaped object — one holding
    /// a `space_bar` group — gets each absent leaf written `false`,
    /// the panel group created where it is missing. A per-layout
    /// `app_bar` (`monocle`, `scroll`) holds no `space_bar` and is
    /// left alone: its absent leaf means "inherit", never off.
    static func withGlassLeaves(_ node: Any) -> (Any, Bool) {
        if var dict = node as? [String: Any] {
            var changed = false
            if dict["space_bar"] is [String: Any] {
                for group in glassGroups {
                    guard dict[group] == nil || dict[group] is [String: Any]
                    else { continue }
                    var object = dict[group] as? [String: Any] ?? [:]
                    guard object[glassLeafKey] == nil else { continue }
                    object[glassLeafKey] = false
                    dict[group] = object
                    changed = true
                }
            }
            for (key, value) in dict {
                let (child, childChanged) = withGlassLeaves(value)
                if childChanged {
                    dict[key] = child
                    changed = true
                }
            }
            return (dict, changed)
        }
        if let array = node as? [Any] {
            var changed = false
            let out = array.map { element -> Any in
                let (child, childChanged) = withGlassLeaves(element)
                if childChanged { changed = true }
                return child
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// The textual edit for the common shape — a profile the app
    /// wrote, whose bar groups carry their leaf and whose panel
    /// group is missing: the group is inserted after each
    /// `settings` opener. Every other shape stands down to the
    /// walk, which `surgicallyApplying` re-parses against anyway.
    static func surgicallyFilledGlassLeaves(_ text: String) -> Data? {
        guard text.range(of: "\"shortcut_panel\"") == nil else {
            return nil
        }
        let out = text.replacingOccurrences(
            of: "(\"settings\"\\s*:\\s*\\{)",
            with: "$1\"shortcut_panel\":{\"liquid_glass\":false},",
            options: .regularExpression
        )
        return out == text ? nil : out.data(using: .utf8)
    }
}
