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
    /// The formats this step introduced — a profile's and a
    /// bundle's — spelled as history. A file at or above them was
    /// written after the default flip, where an absent leaf MEANS
    /// the new default, so filling one would invert it; that
    /// includes #1517's shape, whose bars hold no leaf at all and
    /// whose shelf may be encoded empty.
    static let glassFillProfileFormat = 4
    static let glassFillBundleFormat = 6

    @Sendable
    static func migratingAbsentGlassLeaves(_ data: Data) -> Data? {
        guard glassFillApplies(to: data) else { return nil }
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(glassSettingsKey)\"".utf8))
                    != nil
            },
            rewriting: withGlassLeaves,
            editing: surgicallyFilledGlassLeaves
        )
    }

    /// Whether `data`'s stamp is below the format this step
    /// introduced for its shape. An unreadable root stands down.
    static func glassFillApplies(to data: Data) -> Bool {
        stampBelow(
            data,
            file: glassFillProfileFormat,
            bundle: glassFillBundleFormat
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
        // A settings object carrying the shelf was written after
        // the flip whatever its stamp says; the format floor
        // above is what covers one whose shelf encoded empty.
        if settings[shelfKey] != nil { return (settings, false) }
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
        let first = bars.first ?? nil
        let agree = bars.allSatisfy { $0 == first }
        write(glassPanelGroup, agree ? (first ?? false) : false)
        return (out, changed)
    }

    /// The textual edit, for the shapes a file the app or a hand
    /// wrote actually has. Every `liquid_glass` in the text must
    /// carry ONE value, or the walk decides; a bar group present
    /// once as a flat object that PARSES gets a missing leaf
    /// written `false` — the meaning absence had — which is only
    /// taken where that one value is `false`; a group absent
    /// everywhere is inserted whole, and the panel takes the one
    /// value, after each `settings` opener in ONE pass, so an
    /// opener is edited exactly once. Anything else stands down.
    /// The value and the absent groups are read over the WHOLE
    /// text and written at every opener, so in a bundle one
    /// profile can answer for another; `surgicallyApplying`
    /// re-parses whatever this returns against the walk, and that
    /// compare is the net for a stray edit and for that
    /// cross-profile case alike.
    static func surgicallyFilledGlassLeaves(_ text: String) -> Data? {
        guard text.range(of: "\"\(glassPanelGroup)\"") == nil,
            text.range(of: "\"\(shelfKey)\"") == nil
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
                ).first,
                let object = try? JSONSerialization.jsonObject(
                    with: Data("{\(body)}".utf8)
                ) as? [String: Any]
            else { return nil }
            if object[glassLeafKey] == nil {
                guard value == "false" else { return nil }
                // An empty body takes no comma: Foundation's parser
                // tolerates a trailing one, so the envelope would
                // let it through.
                let comma = object.isEmpty ? "" : ","
                out = out.replacingOccurrences(
                    of: "(\"\(group)\"\\s*:\\s*\\{)",
                    with: "$1\"\(glassLeafKey)\":false" + comma,
                    options: .regularExpression
                )
            }
        }
        guard value == "false" || absent.isEmpty else { return nil }
        absent.append(glassPanelGroup)
        let entries = absent.map { group in
            let leaf = group == glassPanelGroup ? value : "false"
            return "\"\(group)\":{\"\(glassLeafKey)\":\(leaf)}"
        }.joined(separator: ",")
        out = insertingAfterSettingsOpeners(entries, in: out)
        return out == text ? nil : out.data(using: .utf8)
    }

    /// One pass over every `settings` opener, back to front so the
    /// ranges stay valid: an empty object takes `entries` alone, a
    /// populated one takes them ahead of what it holds.
    private static func insertingAfterSettingsOpeners(
        _ entries: String,
        in text: String
    ) -> String {
        let pattern = "(\"\(glassSettingsKey)\"\\s*:\\s*\\{)(\\s*\\})?"
        guard let regex = try? NSRegularExpression(pattern: pattern)
        else { return text }
        var out = text
        let whole = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: whole).reversed() {
            guard let opener = Range(match.range(at: 1), in: out),
                let full = Range(match.range, in: out)
            else { continue }
            let empty = match.range(at: 2).location != NSNotFound
            let replacement =
                out[opener] + entries + (empty ? "}" : ",")
            out.replaceSubrange(full, with: replacement)
        }
        return out
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
