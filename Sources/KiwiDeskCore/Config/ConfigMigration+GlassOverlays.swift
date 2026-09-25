import Foundation

/// Fills the two Liquid Glass leaves #1620/#1621 added — the drag
/// markers' and the sticky mark's — in a file below the floor,
/// from the one switch's agreement over the leaves the file
/// already carries (`GlassOverlayMigrationTests`). Absent, they
/// would decode ON beside a shelf or panel the user set off, so
/// the switch would open reading "differ" on a plain upgrade
/// (profiles.md ▸ absence was a stored value).
extension ConfigMigration {
    /// Spelled here rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let overlayGlassGroups = ["drag", "sticky"]
    static let overlayGlassSources = ["kiwishelf", "shortcut_panel"]
    /// The formats this step introduced, a profile's and a bundle's.
    static let overlayGlassProfileFormat = 9
    static let overlayGlassBundleFormat = 13

    @Sendable
    static func migratingAbsentOverlayGlass(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: overlayGlassProfileFormat,
                bundle: overlayGlassBundleFormat
            )
        else { return nil }
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(glassSettingsKey)\"".utf8))
                    != nil
            },
            rewriting: withOverlayGlass,
            editing: surgicallyFilledOverlayGlass
        )
    }

    /// The two paths #1369's step walks: the root's `settings` and
    /// each inline profile's.
    static func withOverlayGlass(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[glassSettingsKey] as? [String: Any] {
            let (filled, did) = filledOverlayGlass(settings)
            if did {
                root[glassSettingsKey] = filled
                changed = true
            }
        }
        if var profiles = root[glassProfilesKey] as? [[String: Any]] {
            var did = false
            for index in profiles.indices {
                guard
                    let settings = profiles[index][glassSettingsKey]
                        as? [String: Any]
                else { continue }
                let (filled, one) = filledOverlayGlass(settings)
                guard one else { continue }
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

    /// The switch's reading of one settings object: the leaves'
    /// value where they agree, off where they do not. An absent
    /// source leaf reads as its default, on.
    static func overlayGlassAgreement(_ settings: [String: Any]) -> Bool {
        let values = overlayGlassSources.map {
            (settings[$0] as? [String: Any])?[glassLeafKey] as? Bool
                ?? true
        }
        return Set(values).count == 1 ? values[0] : false
    }

    /// One `TilingSettings` object: each overlay group takes the
    /// agreement where it carries no leaf.
    static func filledOverlayGlass(
        _ settings: [String: Any]
    ) -> ([String: Any], Bool) {
        let value = overlayGlassAgreement(settings)
        var out = settings
        var changed = false
        for group in overlayGlassGroups {
            guard out[group] == nil || out[group] is [String: Any]
            else { continue }
            var object = out[group] as? [String: Any] ?? [:]
            guard object[glassLeafKey] == nil else { continue }
            object[glassLeafKey] = value
            out[group] = object
            changed = true
        }
        return (out, changed)
    }

    /// The textual edit: ONE agreement across every settings
    /// object, and each overlay group either opened once per
    /// `settings` opener with no leaf yet — the leaf goes in after
    /// its opener — or absent everywhere, when the whole group goes
    /// in after each `settings` opener. Anything else stands down to
    /// the walk, and `surgicallyApplying`'s compare is the net for a
    /// stray edit.
    static func surgicallyFilledOverlayGlass(_ text: String) -> Data? {
        guard
            let root = try? JSONSerialization.jsonObject(
                with: Data(text.utf8)
            ) as? [String: Any]
        else { return nil }
        let objects = overlaySettingsObjects(in: root)
        let values = Set(objects.map(overlayGlassAgreement))
        guard values.count == 1, let on = values.first else {
            return nil
        }
        let value = on ? "true" : "false"
        let opener = "(\"\(glassSettingsKey)\"\\s*:\\s*\\{)(\\s*\\})?"
        let openers = matches(opener, in: text).count
        guard openers == objects.count, openers > 0 else { return nil }
        var out = text
        var absent: [String] = []
        for group in overlayGlassGroups {
            let present = objects.filter { $0[group] != nil }
            if present.isEmpty {
                absent.append(group)
                continue
            }
            let pattern = "(\"\(group)\"\\s*:\\s*\\{)(\\s*\\})?"
            guard present.count == objects.count,
                !present.contains(where: {
                    ($0[group] as? [String: Any])?[glassLeafKey] != nil
                }),
                matches(pattern, in: out).count == openers
            else { return nil }
            out = inserting(
                "\"\(glassLeafKey)\":\(value)",
                afterEach: pattern,
                in: out
            )
        }
        if !absent.isEmpty {
            let entries = absent.map {
                "\"\($0)\":{\"\(glassLeafKey)\":\(value)}"
            }.joined(separator: ",")
            out = inserting(entries, afterEach: opener, in: out)
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    /// The settings objects the walk visits, in its order.
    private static func overlaySettingsObjects(
        in root: [String: Any]
    ) -> [[String: Any]] {
        var out: [[String: Any]] = []
        if let settings = root[glassSettingsKey] as? [String: Any] {
            out.append(settings)
        }
        for profile in root[glassProfilesKey] as? [[String: Any]] ?? [] {
            if let settings = profile[glassSettingsKey] as? [String: Any] {
                out.append(settings)
            }
        }
        return out
    }

    /// `entries` after every match of `pattern`'s opener, back to
    /// front: an empty object takes them alone, a populated one
    /// takes them ahead of what it holds.
    private static func inserting(
        _ entries: String,
        afterEach pattern: String,
        in text: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern)
        else { return text }
        var out = text
        let whole = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: whole).reversed() {
            guard let opener = Range(match.range(at: 1), in: out),
                let full = Range(match.range, in: out)
            else { continue }
            let empty = match.range(at: 2).location != NSNotFound
            out.replaceSubrange(
                full,
                with: out[opener] + entries + (empty ? "}" : ",")
            )
        }
        return out
    }

    /// Every first capture of `pattern` in `text`.
    private static func matches(
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
