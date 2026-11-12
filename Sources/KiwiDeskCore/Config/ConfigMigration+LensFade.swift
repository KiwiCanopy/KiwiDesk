import Foundation

/// Clears every lens's fade length and curve override (#3246):
/// Settings no longer draws either row, so a stored one would act
/// unseen; each lens follows the global fade again. Only
/// `kiwivision.lenses` entries lose the keys — the global group's
/// own `fade_duration` and `fade_curve` stay — in `gui.json` and a
/// bundle's `config`. `init.lua`'s lens tables are not reached
/// (`LensFadeMigrationTests`).
extension ConfigMigration {
    /// Spelled as history: the keys the step was written to clear.
    static let retiredLensFadeKeys = ["fade_duration", "fade_curve"]
    static let lensGroupKey = "kiwivision"
    static let lensListKey = "lenses"

    /// The formats this step introduced, per shape, spelled as history.
    static let lensFadeGuiFormat = 24
    static let lensFadeBundleFormat = 48

    @Sendable
    static func migratingLensFadeOut(_ data: Data) -> Data? {
        let needle = Data("\"\(lensListKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { data in
                data.range(of: needle) != nil && belowLensFadeFloor(data)
            },
            rewriting: withoutLensFade,
            editing: lensFadeTextDropped
        )
    }

    private static func belowLensFadeFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < lensFadeBundleFormat
        case .gui: return format < lensFadeGuiFormat
        case .profile, .palettes, .looks: return false
        }
    }

    /// Tree walker: each `kiwivision.lenses` entry without the two
    /// keys, at any depth (a bundle nests the group in `config`).
    static func withoutLensFade(_ node: Any) -> (Any, Bool) {
        if var dict = node as? [String: Any] {
            var changed = false
            for (key, value) in dict {
                if key == lensGroupKey, var group = value as? [String: Any],
                    let lenses = group[lensListKey] as? [Any]
                {
                    let (cleared, did) = clearedLenses(lenses)
                    guard did else { continue }
                    group[lensListKey] = cleared
                    dict[key] = group
                    changed = true
                    continue
                }
                let (child, did) = withoutLensFade(value)
                guard did else { continue }
                dict[key] = child
                changed = true
            }
            return (dict, changed)
        }
        if let array = node as? [Any] {
            var changed = false
            let out = array.map { value -> Any in
                let (child, did) = withoutLensFade(value)
                changed = changed || did
                return child
            }
            return (out, changed)
        }
        return (node, false)
    }

    private static func clearedLenses(_ lenses: [Any]) -> ([Any], Bool) {
        var changed = false
        let out = lenses.map { entry -> Any in
            guard var lens = entry as? [String: Any] else { return entry }
            for key in retiredLensFadeKeys
            where lens.removeValue(forKey: key) != nil {
                changed = true
            }
            return lens
        }
        return (out, changed)
    }

    /// Cuts each key's member out of an object inside a `lenses`
    /// array, as the profile strip does (`memberCut`).
    static func lensFadeTextDropped(_ text: String) -> Data? {
        let bytes = Array(text.utf8)
        let arrays = lensArrays(in: bytes)
        guard !arrays.isEmpty else { return nil }
        let cuts = JSONKeyLexer.entries(in: text)
            .filter { entry in
                retiredLensFadeKeys.contains(entry.key)
                    && arrays.contains { $0.contains(entry.object) }
            }
            .map { memberCut($0, in: bytes) }
        guard !cuts.isEmpty else { return nil }
        var out = bytes
        for cut in merged(cuts, in: bytes).reversed() {
            out.removeSubrange(cut)
        }
        return Data(out)
    }

    /// The byte span inside each `"lenses": [ … ]`, strings skipped
    /// while matching brackets.
    private static func lensArrays(in bytes: [UInt8]) -> [Range<Int>] {
        let key = Array("\"\(lensListKey)\"".utf8)
        let space: Set<UInt8> = Set(" \n\t\r".utf8)
        var out: [Range<Int>] = []
        var index = 0
        while index + key.count <= bytes.count {
            guard Array(bytes[index..<index + key.count]) == key else {
                index += 1
                continue
            }
            var open = index + key.count
            while open < bytes.count, space.contains(bytes[open]) {
                open += 1
            }
            guard open < bytes.count, bytes[open] == UInt8(ascii: ":")
            else {
                index += key.count
                continue
            }
            open += 1
            while open < bytes.count, space.contains(bytes[open]) {
                open += 1
            }
            guard open < bytes.count, bytes[open] == UInt8(ascii: "["),
                let close = matchingClose(bytes, from: open)
            else {
                index += key.count
                continue
            }
            out.append(open..<close)
            index = close
        }
        return out
    }

    private static func matchingClose(
        _ bytes: [UInt8],
        from open: Int
    ) -> Int? {
        var depth = 0
        var index = open
        var inString = false
        while index < bytes.count {
            let byte = bytes[index]
            if inString {
                if byte == UInt8(ascii: "\\") {
                    index += 1
                } else if byte == UInt8(ascii: "\"") {
                    inString = false
                }
            } else if byte == UInt8(ascii: "\"") {
                inString = true
            } else if byte == UInt8(ascii: "[") || byte == UInt8(ascii: "{") {
                depth += 1
            } else if byte == UInt8(ascii: "]") || byte == UInt8(ascii: "}") {
                depth -= 1
                if depth == 0 { return index }
            }
            index += 1
        }
        return nil
    }
}
