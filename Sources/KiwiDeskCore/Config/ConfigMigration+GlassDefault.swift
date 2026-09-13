import Foundation

/// Fills the Liquid Glass leaves a file below the floor left
/// ABSENT (#1369, `GlassDefaultMigrationTests`): each absent bar
/// leaf as `false`, the panel from the two bars' agreement, by
/// PATH — a profile root's `settings` and a bundle root's
/// `profiles[].settings`. The argument is design-decisions'
/// (#1369) and the obligation profiles.md's.
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
        let agree = bars.dropFirst().allSatisfy { $0 == bars.first! }
        write(glassPanelGroup, agree ? (bars.first! ?? false) : false)
        return (out, changed)
    }

    /// The textual edit, for the shapes a file the app or a hand
    /// wrote actually has. Every `liquid_glass` in the text must
    /// carry ONE value, or the walk decides; a bar group present
    /// once as a flat object gets a missing leaf after its opener,
    /// a group absent everywhere is inserted whole after each
    /// `settings` opener, and the panel takes that one value —
    /// so a glass-on profile keeps its formatting too. A group
    /// named twice, or holding a nested object, stands down.
    /// `surgicallyApplying` re-parses whatever this returns against
    /// the walk, so a stray edit is never used.
    static func surgicallyFilledGlassLeaves(_ text: String) -> Data? {
        guard text.range(of: "\"\(glassPanelGroup)\"") == nil
        else { return nil }
        let values = Set(
            captures(
                "\"\(glassLeafKey)\"\\s*:\\s*(true|false)",
                in: text
            )
        )
        guard values.count <= 1 else { return nil }
        let value = values.first ?? "false"
        var out = text
        var absent: [String] = []
        for group in glassBarGroups {
            let needle = "\"\(group)\""
            let count = out.components(separatedBy: needle).count - 1
            if count == 0 {
                absent.append(group)
                continue
            }
            guard count == 1,
                let body = captures(
                    "\"\(group)\"\\s*:\\s*\\{([^{}]*)\\}",
                    in: out
                ).first
            else { return nil }
            if !body.contains("\"\(glassLeafKey)\"") {
                out = out.replacingOccurrences(
                    of: "(\"\(group)\"\\s*:\\s*\\{)",
                    with: "$1\"\(glassLeafKey)\":\(value),",
                    options: .regularExpression
                )
            }
        }
        absent.append(glassPanelGroup)
        let entries = absent.map {
            "\"\($0)\":{\"\(glassLeafKey)\":\(value)}"
        }.joined(separator: ",")
        // An empty object takes the entries alone; a populated
        // one takes them ahead of what it holds.
        out = out.replacingOccurrences(
            of: "(\"\(glassSettingsKey)\"\\s*:\\s*\\{)\\s*\\}",
            with: "$1" + entries + "}",
            options: .regularExpression
        )
        out = out.replacingOccurrences(
            of: "(\"\(glassSettingsKey)\"\\s*:\\s*\\{)(?=[^}])",
            with: "$1" + entries + ",",
            options: .regularExpression
        )
        return out == text ? nil : out.data(using: .utf8)
    }

    /// Every first capture of `pattern` in `text`.
    private static func captures(
        _ pattern: String,
        in text: String
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern)
        else { return [] }
        let whole = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: whole).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}
