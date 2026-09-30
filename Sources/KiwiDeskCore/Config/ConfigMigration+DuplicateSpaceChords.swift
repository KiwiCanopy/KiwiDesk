import Foundation

/// Drops a navigation action's extra chords from each stored
/// `bindings` list (#1797, #1807, `DuplicateSpaceChordMigrationTests`):
/// per action, a Space verb keeps the row on its own digit, anything
/// else its first row. A Space verb naming a Space its file does not
/// list is an orphan (#92), drawn one row per binding, and is left
/// alone, as is every `custom` row. It reaches every list at any
/// depth — `gui.json`'s layers, a profile's layer override, a
/// bundle's inline copies — but each list alone, never a base
/// against its override.
extension ConfigMigration {
    /// The formats from which a stored layer holds one chord per
    /// Space verb, per shape.
    static let spaceChordGuiFormat = 5
    static let spaceChordProfileFormat = 15
    static let spaceChordBundleFormat = 20

    /// Spelled rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let spaceChordBindingsKey = "bindings"
    static let spaceChordNavigationKind = "navigation"
    static let spaceChordSpacesKey = "spaces"

    /// What "the same action" is to this step: a Space verb by its
    /// verb and Space, anything else by its Lua.
    enum ChordAction: Hashable {
        case space(SpaceLuaArg.Target)
        case lua(String)
    }

    @Sendable
    static func migratingDuplicateSpaceChords(
        _ data: Data
    ) -> Data? {
        guard belowSpaceChordFloor(data) else { return nil }
        let needle = Data("\"\(spaceChordBindingsKey)\"".utf8)
        var dropped: [[String: Any]] = []
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: { node in
                let (out, drops) = withoutDuplicateSpaceChords(node)
                dropped = drops
                return (out, !drops.isEmpty)
            },
            editing: { surgicallyDropping(dropped, from: $0) }
        )
    }

    /// Whether `data`'s stamp is below this step's floor for its
    /// shape — `stampBelow` cannot say, since `gui.json` and a
    /// profile crossed at different numbers.
    private static func belowSpaceChordFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < spaceChordBundleFormat
        case .profile: return format < spaceChordProfileFormat
        case .gui: return format < spaceChordGuiFormat
        case .palettes, .looks: return false
        }
    }

    /// The tree with every `bindings` list deduplicated, and the
    /// rows it dropped, in document order. `spaces` is the Space list
    /// of the nearest enclosing object that carries one — the file
    /// root, a bundle's `config`, a profile.
    static func withoutDuplicateSpaceChords(
        _ node: Any,
        spaces: Set<SpaceID>? = nil
    ) -> (Any, [[String: Any]]) {
        if let dict = node as? [String: Any] {
            let spaces = listedSpaces(in: dict) ?? spaces
            var out: [String: Any] = [:]
            var drops: [[String: Any]] = []
            for (key, value) in dict {
                if key == spaceChordBindingsKey,
                    let rows = value as? [Any]
                {
                    let (kept, gone) = dedupedSpaceChords(
                        rows,
                        spaces: spaces
                    )
                    out[key] = kept
                    drops += gone
                    continue
                }
                let (child, childDrops) = withoutDuplicateSpaceChords(
                    value,
                    spaces: spaces
                )
                out[key] = child
                drops += childDrops
            }
            return (out, drops)
        }
        if let array = node as? [Any] {
            var drops: [[String: Any]] = []
            let out = array.map { value -> Any in
                let (child, childDrops) = withoutDuplicateSpaceChords(
                    value,
                    spaces: spaces
                )
                drops += childDrops
                return child
            }
            return (out, drops)
        }
        return (node, [])
    }

    private static func listedSpaces(
        in dict: [String: Any]
    ) -> Set<SpaceID>? {
        guard let list = dict[spaceChordSpacesKey] as? [Any] else {
            return nil
        }
        return Set(
            list.compactMap { value -> SpaceID? in
                if let raw = value as? String { return SpaceID(raw) }
                if let number = value as? Int {
                    return SpaceID(String(number))
                }
                return nil
            }
        )
    }

    /// One layer's rows with each navigation action's extra chords
    /// removed, and the removed rows. A `custom` row is drawn as a
    /// row of its own, and an orphan Space verb one row per binding,
    /// so neither is ever removed; with no Space list in reach, no
    /// Space verb is.
    static func dedupedSpaceChords(
        _ rows: [Any],
        spaces: Set<SpaceID>?
    ) -> ([Any], [[String: Any]]) {
        var groups: [ChordAction: [Int]] = [:]
        var order: [ChordAction] = []
        for (index, row) in rows.enumerated() {
            guard let action = chordAction(row, spaces: spaces)
            else { continue }
            if groups[action] == nil { order.append(action) }
            groups[action, default: []].append(index)
        }
        var drop: Set<Int> = []
        for action in order {
            guard let indices = groups[action], indices.count > 1
            else { continue }
            let keep =
                indices.first { isOwnDigit(rows[$0], of: action) }
                ?? indices[0]
            drop.formUnion(indices.filter { $0 != keep })
        }
        guard !drop.isEmpty else { return (rows, []) }
        let kept = rows.enumerated()
            .filter { !drop.contains($0.offset) }.map(\.element)
        let gone = drop.sorted().compactMap {
            rows[$0] as? [String: Any]
        }
        return (kept, gone)
    }

    private static func chordAction(
        _ row: Any,
        spaces: Set<SpaceID>?
    ) -> ChordAction? {
        guard let binding = row as? [String: Any],
            binding["kind"] as? String == spaceChordNavigationKind,
            binding["combo"] is String,
            let lua = binding["lua"] as? String
        else { return nil }
        guard let target = SpaceLuaArg.target(of: lua) else {
            return .lua(lua)
        }
        guard let spaces, spaces.contains(target.space) else {
            return nil
        }
        return .space(target)
    }

    /// Whether the row's key is the digit the seed gives a Space
    /// of this number — `1`…`9`, and `0` for the tenth.
    private static func isOwnDigit(
        _ row: Any,
        of action: ChordAction
    ) -> Bool {
        guard case .space(let target) = action,
            let combo = (row as? [String: Any])?["combo"] as? String,
            let number = Int(target.space.raw),
            let key = combo.split(separator: "+").last
        else { return false }
        let digit = number == 10 ? 0 : number
        return (0...9).contains(digit) && key == "\(digit)"
    }

    /// The text with each dropped row's object removed where it
    /// stands, with the comma that separated it. Every flat object
    /// is parsed and compared to a drop, so a row is found by what
    /// it holds rather than by how the file spelled it; an edit
    /// that disagrees with the walk is discarded by the envelope.
    static func surgicallyDropping(
        _ dropped: [[String: Any]],
        from text: String
    ) -> Data? {
        var pending = dropped.compactMap(canonical)
        guard !pending.isEmpty,
            let regex = try? NSRegularExpression(
                pattern: "\\{[^{}]*\\}"
            )
        else { return nil }
        let whole = NSRange(text.startIndex..., in: text)
        var removals: [Range<String.Index>] = []
        for match in regex.matches(in: text, range: whole) {
            guard let range = Range(match.range, in: text),
                let object = try? JSONSerialization.jsonObject(
                    with: Data(text[range].utf8)
                ),
                let key = canonical(object),
                let hit = pending.firstIndex(of: key)
            else { continue }
            pending.remove(at: hit)
            removals.append(range)
        }
        guard pending.isEmpty else { return nil }
        var out = text
        for range in removals.reversed() {
            out.removeSubrange(separated(range, in: out))
        }
        return out.data(using: .utf8)
    }

    /// `range` widened over the comma before it, or else the one
    /// after it, and the whitespace between.
    private static func separated(
        _ range: Range<String.Index>,
        in text: String
    ) -> Range<String.Index> {
        var start = range.lowerBound
        while start > text.startIndex,
            text[text.index(before: start)].isWhitespace
        {
            start = text.index(before: start)
        }
        if start > text.startIndex,
            text[text.index(before: start)] == ","
        {
            return text.index(before: start)..<range.upperBound
        }
        var end = range.upperBound
        while end < text.endIndex, text[end].isWhitespace {
            end = text.index(after: end)
        }
        if end < text.endIndex, text[end] == "," {
            end = text.index(after: end)
            while end < text.endIndex, text[end].isWhitespace {
                end = text.index(after: end)
            }
            return range.lowerBound..<end
        }
        return range
    }
}
