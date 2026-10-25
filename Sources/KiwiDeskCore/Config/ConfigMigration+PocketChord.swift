import Foundation

/// ⌃⌥P moves from pin to Pocket (#2446, `PocketChordMigrationTests`):
/// a stored row still running the seeded "Toggle sticky on this
/// screen" on its seeded chord — `⌃⌥P`, or `✦P` on the Hyper base —
/// runs `KiwiDesk.pocket()` instead, in every `bindings` list a file
/// carries. A chord the user moved or bound to pin themselves stays.
/// A meaning change, so the step reads the format and stands down
/// at the floor it introduced (#1354): a pin the user puts back on
/// `⌃⌥P` afterwards is theirs.
extension ConfigMigration {
    /// The formats this step introduced, per shape.
    static let pocketChordGuiFormat = 17
    static let pocketChordProfileFormat = 31
    static let pocketChordBundleFormat = 40

    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let pinLua = "KiwiDesk.toggle_display_sticky()"
    static let pinSeedLabel = "Toggle display sticky"
    static let pocketLua = "KiwiDesk.pocket()"
    static let pocketSeedLabel = "Pocket this window"
    static let pinSeedChord = "control+option+p"

    @Sendable
    static func migratingPinChordOntoPocket(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data(pinLua.utf8)) != nil
                    && belowPocketChordFloor($0)
            },
            rewriting: withPocketChord,
            editing: surgicallyPocketing
        )
    }

    private static func belowPocketChordFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < pocketChordBundleFormat
        case .profile: return format < pocketChordProfileFormat
        case .gui: return format < pocketChordGuiFormat
        case .palettes, .looks: return false
        }
    }

    /// The tree with every seeded pin row in a `bindings` list
    /// moved onto Pocket.
    static func withPocketChord(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                if key == shortcutBaseBindingsKey, let rows = value as? [Any] {
                    var did = false
                    out[key] = rows.map { row -> Any in
                        guard let binding = row as? [String: Any],
                            let moved = pocketed(binding)
                        else { return row }
                        did = true
                        return moved
                    }
                    changed = changed || did
                    continue
                }
                let (child, did) = withPocketChord(value)
                out[key] = child
                changed = changed || did
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var changed = false
            let out = array.map { value -> Any in
                let (child, did) = withPocketChord(value)
                changed = changed || did
                return child
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// `row` running Pocket, or nil where it is no seeded pin row.
    static func pocketed(_ row: [String: Any]) -> [String: Any]? {
        guard row["lua"] as? String == pinLua,
            let text = row["combo"] as? String,
            let combo = KeyCombo.parse(text),
            let seeded = KeyCombo.parse(pinSeedChord),
            combo == seeded
                || combo == ShortcutBase.moved(seeded, to: .hyper)
        else { return nil }
        var out = row
        out["lua"] = pocketLua
        if row["label"] as? String == pinSeedLabel {
            out["label"] = pocketSeedLabel
        }
        return out
    }

    /// The textual edit: each seeded pin row's `lua` and seeded
    /// label rewritten inside its own object.
    static func surgicallyPocketing(_ text: String) -> Data? {
        guard
            let regex = try? NSRegularExpression(pattern: "\\{[^{}]*\\}")
        else { return nil }
        var out = text
        let whole = NSRange(out.startIndex..., in: out)
        for match in regex.matches(in: out, range: whole).reversed() {
            guard let range = Range(match.range, in: out),
                let object = try? JSONSerialization.jsonObject(
                    with: Data(out[range].utf8)
                ) as? [String: Any],
                pocketed(object) != nil
            else { continue }
            var edited = out[range].replacingOccurrences(
                of: "(\"lua\"\\s*:\\s*)\"[^\"]*\"",
                with: "$1\"\(pocketLua)\"",
                options: .regularExpression
            )
            edited = edited.replacingOccurrences(
                of: "(\"label\"\\s*:\\s*)\"\(pinSeedLabel)\"",
                with: "$1\"\(pocketSeedLabel)\"",
                options: .regularExpression
            )
            out.replaceSubrange(range, with: edited)
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
