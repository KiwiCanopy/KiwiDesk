import Foundation

/// Retires the drag markers' look (#2797, `DragLookMigrationTests`,
/// `ConfigMigrationRoutingTests`): the ghost's and the drop zone's
/// colour, fill, border and alignment leave `drag.ghost` and
/// `drag.drop_zone`, and their four palette paths leave every colour
/// map — a palette, a look, a look's recorded origin. Changes no
/// value — no decoder reads the keys since — and ends the file in
/// the new shape, as `overflow_style`'s step did (#2235). Unscoped
/// by depth: no other object is keyed `ghost` or `drop_zone`, and
/// the dotted paths are unique spellings.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let dragMarkerKeys = ["ghost", "drop_zone"]
    static let retiredDragKnobs = [
        "border", "border_color", "border_alignment", "fill",
        "fill_color",
    ]
    static let retiredDragColorPaths: Set<String> = Set(
        dragMarkerKeys.flatMap { marker in
            ["border_color", "fill_color"].map { "drag.\(marker).\($0)" }
        }
    )

    @Sendable
    static func migratingRetiredDragLook(_ data: Data) -> Data? {
        let needles = (dragMarkerKeys.map { "\"\($0)\"" } + ["\"drag."])
            .map { Data($0.utf8) }
        return surgicallyApplying(
            data,
            gate: { data in needles.contains { data.range(of: $0) != nil } },
            rewriting: withoutDragLook,
            editing: surgicallyDroppedDragLook
        )
    }

    /// Tree walker: the knobs out of every `ghost` / `drop_zone`
    /// object, the palette paths out of every object, at any depth.
    static func withoutDragLook(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                if retiredDragColorPaths.contains(key) {
                    changed = true
                    continue
                }
                if dragMarkerKeys.contains(key),
                    var marker = value as? [String: Any]
                {
                    for knob in retiredDragKnobs
                    where marker.removeValue(forKey: knob) != nil {
                        changed = true
                    }
                    out[key] = marker
                    continue
                }
                let (child, childChanged) = withoutDragLook(value)
                out[key] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = withoutDragLook(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// The textual edit: the knobs deleted inside each marker's own
    /// object, the palette paths wherever they stand.
    static func surgicallyDroppedDragLook(_ text: String) -> Data? {
        var out = text
        let scalar = "(?:\"(?:[^\"\\\\]|\\\\.)*\"|true|false)"
        for marker in dragMarkerKeys {
            guard
                let regex = try? NSRegularExpression(
                    pattern: "\"\(marker)\"\\s*:\\s*\\{[^{}]*\\}"
                )
            else { return nil }
            let whole = NSRange(out.startIndex..., in: out)
            for match in regex.matches(in: out, range: whole).reversed() {
                guard let range = Range(match.range, in: out) else {
                    continue
                }
                var object = String(out[range])
                for knob in retiredDragKnobs {
                    object = droppingEntry(
                        "\"\(knob)\"\\s*:\\s*\(scalar)",
                        from: object
                    )
                }
                out.replaceSubrange(range, with: object)
            }
        }
        for path in retiredDragColorPaths.sorted() {
            let key = NSRegularExpression.escapedPattern(for: path)
            out = droppingEntry("\"\(key)\"\\s*:\\s*\(scalar)", from: out)
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    /// `text` with every `entry` and the comma that joined it gone.
    private static func droppingEntry(
        _ entry: String,
        from text: String
    ) -> String {
        var out = text
        for pattern in [
            entry + "\\s*,\\s*", "\\s*,\\s*" + entry, entry,
        ] {
            out = out.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }
        return out
    }
}
