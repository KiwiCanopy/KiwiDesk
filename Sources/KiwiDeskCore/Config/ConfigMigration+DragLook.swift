import Foundation

/// Retires the drag markers' look (#2797, `DragLookMigrationTests`):
/// the knobs leave `drag.ghost` and `drag.drop_zone`, the four
/// palette paths every colour map. Stands down at the formats it
/// introduced, so a later key of the same spelling is kept.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let dragMarkerKeys = ["ghost", "drop_zone"]
    static let dragGroupKey = "drag"
    static let retiredDragKnobs = [
        "border", "border_color", "border_alignment", "fill",
        "fill_color",
    ]
    static let retiredDragColorPaths: Set<String> = Set(
        dragMarkerKeys.flatMap { marker in
            ["border_color", "fill_color"].map { "drag.\(marker).\($0)" }
        }
    )

    /// The formats this step introduced, per shape, spelled as history.
    static let dragLookProfileFormat = 33
    static let dragLookGuiFormat = 18
    static let dragLookBundleFormat = 42
    static let dragLookPaletteFormat = 3
    static let dragLookLookFormat = 3

    @Sendable
    static func migratingRetiredDragLook(_ data: Data) -> Data? {
        let needles = (dragMarkerKeys.map { "\"\($0)\"" } + ["\"drag."])
            .map { Data($0.utf8) }
        return surgicallyApplying(
            data,
            gate: { data in
                needles.contains { data.range(of: $0) != nil }
                    && belowDragLookFloor(data)
            },
            rewriting: withoutDragLook,
            editing: surgicallyDroppedDragLook
        )
    }

    private static func belowDragLookFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < dragLookBundleFormat
        case .profile: return format < dragLookProfileFormat
        case .gui: return format < dragLookGuiFormat
        case .palettes: return format < dragLookPaletteFormat
        case .looks: return format < dragLookLookFormat
        }
    }

    /// Tree walker: the knobs out of `drag.ghost` and
    /// `drag.drop_zone`, the palette paths out of every object, at
    /// any depth.
    static func withoutDragLook(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                if retiredDragColorPaths.contains(key) {
                    changed = true
                    continue
                }
                if key == dragGroupKey, let drag = value as? [String: Any] {
                    let (stripped, did) = withoutDragKnobs(drag)
                    out[key] = stripped
                    changed = changed || did
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

    /// `drag` with each marker's knobs removed.
    private static func withoutDragKnobs(
        _ drag: [String: Any]
    ) -> ([String: Any], Bool) {
        var out = drag
        var changed = false
        for marker in dragMarkerKeys {
            guard var visual = drag[marker] as? [String: Any] else {
                continue
            }
            for knob in retiredDragKnobs
            where visual.removeValue(forKey: knob) != nil {
                changed = true
            }
            out[marker] = visual
        }
        return (out, changed)
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
