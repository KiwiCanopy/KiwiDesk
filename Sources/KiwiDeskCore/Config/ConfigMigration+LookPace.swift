import Foundation

/// Drops the four animation lengths from every look's style map
/// (#3237): pace is app-wide now, so `LookKeys.motion` no longer
/// lists them and a look carrying one would apply nothing, without
/// a word. Matched by KEY at any depth — a profile's own look,
/// `gui.json`'s shared look, `looks.json` and a bundle's inline
/// copies — since only a look path spells these keys
/// (`InstantDurationMigrationTests` ▸ `checkLook`).
extension ConfigMigration {
    /// Spelled as history: `LookKeys` no longer derives them.
    static let retiredLookPacePaths = [
        "animations.duration", "animations.scroll_duration",
        "animations.expand_duration", "animations.reveal_duration",
    ]

    @Sendable
    static func migratingLookPaceOut(_ data: Data) -> Data? {
        let needles = retiredLookPacePaths.map { Data("\"\($0)\"".utf8) }
        return surgicallyApplying(
            data,
            gate: { data in needles.contains { data.range(of: $0) != nil } },
            rewriting: withoutLookPace,
            editing: lookPaceTextDropped
        )
    }

    static func withoutLookPace(_ node: Any) -> (Any, Bool) {
        if var dict = node as? [String: Any] {
            var changed = false
            for path in retiredLookPacePaths where dict[path] != nil {
                dict[path] = nil
                changed = true
            }
            for (key, value) in dict {
                let (child, did) = withoutLookPace(value)
                guard did else { continue }
                dict[key] = child
                changed = true
            }
            return (dict, changed)
        }
        if let array = node as? [Any] {
            var changed = false
            let out = array.map { value -> Any in
                let (child, did) = withoutLookPace(value)
                changed = changed || did
                return child
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// Cuts each path's member out of its object, as the profile
    /// strip does (`memberCut`).
    static func lookPaceTextDropped(_ text: String) -> Data? {
        let bytes = Array(text.utf8)
        let cuts = JSONKeyLexer.entries(in: text)
            .filter { retiredLookPacePaths.contains($0.key) }
            .map { memberCut($0, in: bytes) }
        guard !cuts.isEmpty else { return nil }
        var out = bytes
        for cut in merged(cuts, in: bytes).reversed() {
            out.removeSubrange(cut)
        }
        return Data(out)
    }
}
