import Foundation

/// Turns a stored `long_swipes: false` on (#1873 ▸ owner ruling
/// 2026-11-15): the base encodes whole, so a stored false is almost
/// always the old default rather than a choice, and no stored signal
/// tells the two apart; a user who chose off gets on once and can
/// turn it off again. Reaches the base in `gui.json` and a bundle's
/// `config`; a profile's override is sparse, so a false there is a
/// choice, and stays (`LongSwipesMigrationTests`).
extension ConfigMigration {
    /// The formats this step introduced, per shape, spelled as history.
    static let longSwipesGuiFormat = 27
    static let longSwipesBundleFormat = 51
    static let longSwipesGroupKey = "scroll_gesture"
    static let longSwipesKey = "long_swipes"

    @Sendable
    static func migratingLongSwipesOn(_ data: Data) -> Data? {
        let needle = Data("\"\(longSwipesKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { data in
                data.range(of: needle) != nil && belowLongSwipesFloor(data)
            },
            rewriting: withLongSwipesOn,
            editing: longSwipesTextOn
        )
    }

    private static func belowLongSwipesFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < longSwipesBundleFormat
        case .gui: return format < longSwipesGuiFormat
        case .profile, .palettes, .looks: return false
        }
    }

    /// The base's group: the root's in `gui.json`, `config`'s in a
    /// bundle, never a profile's override.
    static func withLongSwipesOn(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else { return (node, false) }
        if var config = root["config"] as? [String: Any] {
            let (group, changed) = flipped(config)
            guard changed else { return (node, false) }
            config = group
            root["config"] = config
            return (root, true)
        }
        return flipped(root)
    }

    private static func flipped(
        _ owner: [String: Any]
    ) -> ([String: Any], Bool) {
        guard var group = owner[longSwipesGroupKey] as? [String: Any],
            let value = group[longSwipesKey] as? Bool, !value
        else { return (owner, false) }
        group[longSwipesKey] = true
        var out = owner
        out[longSwipesGroupKey] = group
        return (out, true)
    }

    /// Rewrites the one `false` literal of the group's key, found
    /// through `JSONKeyLexer` as a member of an object written under
    /// `scroll_gesture`; nil where there is not exactly one, which a
    /// bundle whose profiles carry the key may have, and the walk's
    /// output stands in.
    static func longSwipesTextOn(_ text: String) -> Data? {
        let bytes = Array(text.utf8)
        let hits = JSONKeyLexer.entries(in: text).filter { entry in
            entry.key == longSwipesKey && entry.value == "false"
                && isGroupObject(entry.object, in: bytes)
        }
        guard hits.count == 1, let hit = hits.first else { return nil }
        var out = bytes
        out.replaceSubrange(hit.valueRange, with: Array("true".utf8))
        return Data(out)
    }

    /// Whether the object opening at `open` is the value of a
    /// `"scroll_gesture"` member.
    private static func isGroupObject(_ open: Int, in bytes: [UInt8]) -> Bool {
        let key = Array("\"\(longSwipesGroupKey)\"".utf8)
        let space: Set<UInt8> = Set(" \n\t\r".utf8)
        var index = open - 1
        while index >= 0, space.contains(bytes[index]) { index -= 1 }
        guard index >= 0, bytes[index] == UInt8(ascii: ":") else {
            return false
        }
        index -= 1
        while index >= 0, space.contains(bytes[index]) { index -= 1 }
        let start = index - key.count + 1
        guard start >= 0 else { return false }
        return Array(bytes[start...index]) == key
    }
}
