import Foundation

/// ⌃⌥P moves from pin to Pocket (#2446, `PocketChordMigrationTests`):
/// a stored row still running the seeded "Toggle sticky on this
/// screen" on its seeded chord — `⌃⌥P`, or `✦P` on the Hyper base —
/// runs `KiwiDesk.pocket()` instead, in every `bindings` list a file
/// carries. A chord the user moved or bound to pin themselves stays:
/// where a root states its `shortcut_base` (gui.json, a backup's
/// config) only that base's chord moves; a profile states none, so
/// either moves there.
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
        var moved: Set<String> = []
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data(pinLua.utf8)) != nil
                    && belowPocketChordFloor($0)
            },
            rewriting: {
                moved = []
                return withPocketChord($0, base: nil, moved: &moved)
            },
            editing: { surgicallyPocketing($0, combos: moved) }
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
    /// moved onto Pocket, under the nearest `shortcut_base` above
    /// it; `moved` collects the chords the walk moved.
    static func withPocketChord(
        _ node: Any,
        base: String?,
        moved: inout Set<String>
    ) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            let base = dict[shortcutBaseKey] as? String ?? base
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                if key == shortcutBaseBindingsKey, let rows = value as? [Any] {
                    var did = false
                    out[key] = rows.map { row -> Any in
                        guard let binding = row as? [String: Any],
                            let pocket = pocketed(binding, base: base)
                        else { return row }
                        did = true
                        moved.insert(binding["combo"] as? String ?? "")
                        return pocket
                    }
                    changed = changed || did
                    continue
                }
                let (child, did) = withPocketChord(
                    value,
                    base: base,
                    moved: &moved
                )
                out[key] = child
                changed = changed || did
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var changed = false
            let out = array.map { value -> Any in
                let (child, did) = withPocketChord(
                    value,
                    base: base,
                    moved: &moved
                )
                changed = changed || did
                return child
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// `row` running Pocket, or nil where it is no seeded pin row on
    /// `base` — either base where nil.
    static func pocketed(
        _ row: [String: Any],
        base: String?
    ) -> [String: Any]? {
        guard row["lua"] as? String == pinLua,
            let text = row["combo"] as? String,
            let combo = KeyCombo.parse(text),
            let seeded = KeyCombo.parse(pinSeedChord)
        else { return nil }
        let hyper = ShortcutBase.moved(seeded, to: .hyper)
        let seededOnBase: Bool
        switch base.flatMap(ShortcutBase.init(rawValue:)) {
        case .standard?: seededOnBase = combo == seeded
        case .hyper?: seededOnBase = combo == hyper
        case nil: seededOnBase = combo == seeded || combo == hyper
        }
        guard seededOnBase else { return nil }
        var out = row
        out["lua"] = pocketLua
        if row["label"] as? String == pinSeedLabel {
            out["label"] = pocketSeedLabel
        }
        return out
    }

    /// The textual edit: each seeded pin row the walk moved — its
    /// chord among `combos` — has its `lua` and seeded label
    /// rewritten inside its own object.
    static func surgicallyPocketing(
        _ text: String,
        combos: Set<String>
    ) -> Data? {
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
                pocketed(object, base: nil) != nil,
                combos.contains(object["combo"] as? String ?? "")
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
