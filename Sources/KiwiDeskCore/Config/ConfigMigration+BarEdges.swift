import Foundation

/// Hands the shelf's edge back to the bars (#1731,
/// `BarEdgeMigrationTests`): a stored `kiwishelf.edge` becomes
/// both `space_bar.edge` and `app_bar.edge`, so every setup lands
/// with its bars fused on the edge it had, and the key drops. An
/// absent one needs nothing — both bars default to the shelf's
/// old default, top. Reaches a profile root's `settings` and a
/// bundle root's `profiles[].settings`; `gui.json` carries no
/// `settings` (`GuiConfig`'s format note).
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let barEdgeKey = "edge"
    static let barEdgeShelfKey = "kiwishelf"
    static let barEdgeGroups = ["space_bar", "app_bar"]
    static let barEdgeSettingsKey = "settings"
    static let barEdgeProfilesKey = "profiles"
    static let barEdgeLayoutKey = "layout"
    /// The formats this step introduced, spelled as history.
    static let barEdgeProfileFormat = 11
    static let barEdgeBundleFormat = 16

    @Sendable
    static func migratingShelfEdgeOntoBars(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: barEdgeProfileFormat,
                bundle: barEdgeBundleFormat
            )
        else { return nil }
        let needle = Data("\"\(barEdgeShelfKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: withBarEdges,
            editing: surgicallyBarEdges
        )
    }

    /// The two paths: the root's own `settings`, and each inline
    /// profile's under `profiles`.
    static func withBarEdges(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[barEdgeSettingsKey] as? [String: Any] {
            let (moved, did) = barEdgedSettings(settings)
            if did {
                root[barEdgeSettingsKey] = moved
                changed = true
            }
        }
        if var profiles = root[barEdgeProfilesKey] as? [[String: Any]] {
            var did = false
            for index in profiles.indices {
                guard
                    let settings = profiles[index][barEdgeSettingsKey]
                        as? [String: Any]
                else { continue }
                let (moved, changedOne) = barEdgedSettings(settings)
                guard changedOne else { continue }
                profiles[index][barEdgeSettingsKey] = moved
                did = true
            }
            if did {
                root[barEdgeProfilesKey] = profiles
                changed = true
            }
        }
        return (root, changed)
    }

    /// One `TilingSettings` object: the shelf's edge into each
    /// bar that states none, then dropped from the shelf.
    static func barEdgedSettings(
        _ settings: [String: Any]
    ) -> ([String: Any], Bool) {
        guard var shelf = settings[barEdgeShelfKey] as? [String: Any],
            let edge = shelf.removeValue(forKey: barEdgeKey)
        else { return (settings, false) }
        var out = settings
        out[barEdgeShelfKey] = shelf
        for group in barEdgeGroups {
            var bar = out[group] as? [String: Any] ?? [:]
            if bar[barEdgeKey] == nil { bar[barEdgeKey] = edge }
            out[group] = bar
        }
        return (out, true)
    }

    /// The textual edit, for a file with one `settings`, one
    /// shelf, one Space Bar and one global App Bar: the shelf's
    /// pair moves to the head of each bar that states no edge, its
    /// value text copied. Anything else stands down to
    /// the walk.
    static func surgicallyBarEdges(_ text: String) -> Data? {
        guard count(of: "\"\(barEdgeSettingsKey)\"", in: text) == 1,
            case .some(.some(let shelfSpan)) = objectSpan(
                ofKey: barEdgeShelfKey,
                in: text
            ),
            let shelfRange = Range(shelfSpan, in: text)
        else { return nil }
        let shelfText = String(text[shelfRange])
        let pairPattern = "\"\(barEdgeKey)\"\\s*:\\s*(\"[a-z]+\")"
        guard
            let pairRegex = try? NSRegularExpression(pattern: pairPattern),
            case let pairs = pairRegex.matches(
                in: shelfText,
                range: NSRange(shelfText.startIndex..., in: shelfText)
            ),
            pairs.count == 1,
            let valueRange = Range(pairs[0].range(at: 1), in: shelfText)
        else { return nil }
        let value = String(shelfText[valueRange])
        let editedShelf = removingPair(pairs[0].range, from: shelfText)
        var out = text.replacingCharacters(in: shelfRange, with: editedShelf)
        for group in barEdgeGroups.reversed() {
            // Re-measured per pass: the previous one moved offsets.
            guard let layout = objectSpan(ofKey: barEdgeLayoutKey, in: out)
            else { return nil }
            let opener = "(\"\(group)\"\\s*:\\s*\\{)(\\s*\\})?"
            guard let regex = try? NSRegularExpression(pattern: opener)
            else { return nil }
            let global = regex.matches(
                in: out,
                range: NSRange(out.startIndex..., in: out)
            ).filter { match in
                !(layout.map { NSLocationInRange(match.range.location, $0) }
                    ?? false)
            }
            guard global.count == 1 else { return nil }
            let utf16 = Array(out.utf16)
            let brace =
                global[0].range(at: 1).location
                + global[0].range(at: 1).length - 1
            guard let close = closingBrace(from: brace, in: utf16),
                let span = Range(
                    NSRange(location: brace, length: close - brace + 1),
                    in: out
                )
            else { return nil }
            // A bar stating its own edge keeps it, as the walk does.
            if out[span].contains("\"\(barEdgeKey)\"") { continue }
            let empty = global[0].range(at: 2).location != NSNotFound
            guard let whole = Range(global[0].range, in: out),
                let head = Range(global[0].range(at: 1), in: out)
            else { return nil }
            out.replaceSubrange(
                whole,
                with: out[head] + "\"\(barEdgeKey)\":\(value)"
                    + (empty ? "}" : ",")
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    /// `text` without the pair at `range`, and the comma that
    /// joined it to a neighbour.
    private static func removingPair(
        _ range: NSRange,
        from text: String
    ) -> String {
        let ns = text as NSString
        let after = ns.substring(from: range.location + range.length)
        if let comma = after.range(
            of: "^\\s*,\\s*",
            options: .regularExpression
        ) {
            let length = after.distance(
                from: after.startIndex,
                to: comma.upperBound
            )
            return ns.replacingCharacters(
                in: NSRange(
                    location: range.location,
                    length: range.length + length
                ),
                with: ""
            )
        }
        let before = ns.substring(to: range.location)
        if let comma = before.range(
            of: ",\\s*$",
            options: .regularExpression
        ) {
            let start = before.distance(
                from: before.startIndex,
                to: comma.lowerBound
            )
            return ns.replacingCharacters(
                in: NSRange(
                    location: start,
                    length: range.location + range.length - start
                ),
                with: ""
            )
        }
        return ns.replacingCharacters(in: range, with: "")
    }
}
