import Foundation

/// The pocket's edge and position move onto KiwiShelf (#2678,
/// `PocketPlacementMigrationTests`): a stored `pocket.edge` and
/// `pocket.position` become `kiwishelf.pocket_edge` and
/// `kiwishelf.pocket_position`, a value the shelf already states
/// kept. Without the step the failure is silent — both decode with
/// `decodeIfPresent ?? default`. Reaches a profile root's `settings`
/// and a bundle's `profiles[].settings`; `gui.json`'s `pocket` holds
/// only the app-wide capacity.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let pocketPlacementMoves: [(retired: String, target: String)] = [
        ("edge", "pocket_edge"),
        ("position", "pocket_position"),
    ]
    static let pocketPlacementGroup = "pocket"
    static let pocketPlacementShelf = "kiwishelf"
    /// The formats this step introduced, spelled as history.
    static let pocketPlacementProfileFormat = 32
    static let pocketPlacementBundleFormat = 41

    @Sendable
    static func migratingPocketPlacementOntoShelf(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: pocketPlacementProfileFormat,
                bundle: pocketPlacementBundleFormat
            )
        else { return nil }
        let needle = Data("\"\(pocketPlacementGroup)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: withPocketPlacement,
            editing: surgicallyPocketPlacement
        )
    }

    /// The root's own `settings`, and each inline profile's.
    static func withPocketPlacement(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[barEdgeSettingsKey] as? [String: Any] {
            let (moved, did) = pocketPlacedSettings(settings)
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
                let (moved, one) = pocketPlacedSettings(settings)
                guard one else { continue }
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

    /// One `TilingSettings` object: each placement key out of the
    /// pocket and into the shelf, unless the shelf states it.
    static func pocketPlacedSettings(
        _ settings: [String: Any]
    ) -> ([String: Any], Bool) {
        guard var pocket = settings[pocketPlacementGroup] as? [String: Any]
        else { return (settings, false) }
        var shelf = settings[pocketPlacementShelf] as? [String: Any] ?? [:]
        var changed = false
        for move in pocketPlacementMoves {
            guard let value = pocket.removeValue(forKey: move.retired)
            else { continue }
            if shelf[move.target] == nil { shelf[move.target] = value }
            changed = true
        }
        guard changed else { return (settings, false) }
        var out = settings
        out[pocketPlacementGroup] = pocket
        out[pocketPlacementShelf] = shelf
        return (out, true)
    }

    /// The textual edit, for a file with one `settings`, one pocket
    /// and one shelf object: each pair leaves the pocket and opens
    /// the shelf, its value text copied. Anything else stands down
    /// to the walk.
    static func surgicallyPocketPlacement(_ text: String) -> Data? {
        guard count(of: "\"\(barEdgeSettingsKey)\"", in: text) == 1,
            case .some(.some(let pocketSpan)) = objectSpan(
                ofKey: pocketPlacementGroup,
                in: text
            ),
            case .some(.some) = objectSpan(
                ofKey: pocketPlacementShelf,
                in: text
            ),
            let pocketRange = Range(pocketSpan, in: text)
        else { return nil }
        var pocketText = String(text[pocketRange])
        var moved: [String] = []
        for move in pocketPlacementMoves {
            let pattern =
                "\"\(move.retired)\"\\s*:\\s*(\"[a-z]+\"|-?[0-9.eE+-]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern)
            else { return nil }
            let found = regex.matches(
                in: pocketText,
                range: NSRange(pocketText.startIndex..., in: pocketText)
            )
            guard found.count <= 1 else { return nil }
            guard let pair = found.first,
                let value = Range(pair.range(at: 1), in: pocketText)
            else { continue }
            moved.append("\"\(move.target)\":\(pocketText[value])")
            pocketText = removingPair(pair.range, from: pocketText)
        }
        guard !moved.isEmpty else { return nil }
        var out = text.replacingCharacters(in: pocketRange, with: pocketText)
        let opener = "\"\(pocketPlacementShelf)\"\\s*:\\s*\\{(\\s*\\})?"
        guard let regex = try? NSRegularExpression(pattern: opener),
            let shelf = regex.firstMatch(
                in: out,
                range: NSRange(out.startIndex..., in: out)
            ),
            let whole = Range(shelf.range, in: out)
        else { return nil }
        let empty = shelf.range(at: 1).location != NSNotFound
        let pairs = moved.joined(separator: ",")
        out.replaceSubrange(
            whole,
            with: "\"\(pocketPlacementShelf)\":{" + pairs
                + (empty ? "}" : ",")
        )
        return out == text ? nil : out.data(using: .utf8)
    }
}
