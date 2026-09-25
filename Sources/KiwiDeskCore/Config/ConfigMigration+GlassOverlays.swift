import Foundation

/// Fills the two Liquid Glass leaves #1620/#1621 added — the drag
/// markers' and the sticky mark's — in a file below the floor,
/// from the one switch's agreement over the leaves the file
/// already carries (`GlassOverlayMigrationTests`). Absent, they
/// would decode ON beside a shelf or panel the user set off, so
/// the switch would open reading "differ" on a plain upgrade
/// (profiles.md ▸ a stored value's ABSENCE is a value too).
extension ConfigMigration {
    /// Spelled here rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let overlayGlassGroups = ["drag", "sticky"]
    /// The switch's older leaves, named by the steps' own
    /// historical constants rather than a second spelling.
    static let overlayGlassSources = [shelfKey, glassPanelGroup]
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
        let openers = captures(opener, in: text).count
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
                captures(pattern, in: out).count == openers
            else { return nil }
            out = insertingAfterEach(
                "\"\(glassLeafKey)\":\(value)",
                pattern: pattern,
                in: out
            )
        }
        if !absent.isEmpty {
            let entries = absent.map {
                "\"\($0)\":{\"\(glassLeafKey)\":\(value)}"
            }.joined(separator: ",")
            out = insertingAfterEach(entries, pattern: opener, in: out)
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

}
