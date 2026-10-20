import Foundation

/// The Desktop base becomes the shortcut base (#2460,
/// `ShortcutBaseMigrationTests`). `desktop_shortcut_base` covered
/// the Desktop tier alone and `shortcut_base` covers every tier, so
/// the value is not carried: it reads `hyper` where more of the
/// seeded `⌃⌥` letters sit on Hyper than on `⌃⌥` — the old move
/// offer's mark, judged once here — and `control+option` otherwise.
/// A Go to Desktop row on `✦` + digit moves to `✦⌥` + digit, which
/// the Space digits no longer hold under `✦`, in every `bindings`
/// list a file carries. A meaning change, so the step reads the
/// format and stands down at the floor it introduced (#1354).
extension ConfigMigration {
    /// The formats this step introduced, per shape.
    static let shortcutBaseGuiFormat = 12
    static let shortcutBaseProfileFormat = 27
    static let shortcutBaseBundleFormat = 34

    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let retiredDesktopBaseKey = "desktop_shortcut_base"
    static let shortcutBaseKey = "shortcut_base"
    static let shortcutBaseLayersKey = "layers"
    static let shortcutBaseBindingsKey = "bindings"
    static let shortcutBaseDefaultLayer = "default"
    static let desktopRowPrefix = "KiwiDesk.focus_desktop("
    /// The seed's `⌃⌥` letter rows the 3.1.0 move offer carried, by
    /// Lua.
    static let movedLetterLua: Set<String> = [
        "KiwiDesk.toggle_floating()",
        "KiwiDesk.toggle_sticky()",
        "KiwiDesk.toggle_display_sticky()",
        "KiwiDesk.cycle_mode()",
        "KiwiDesk.cycle_mode(\"prev\")",
        "KiwiDesk.reset_layout_sizing()",
        "KiwiDesk.open_settings()",
        "kiwivision.toggle()",
        "space_bar.toggle_reveal()",
        "app_bar.toggle_reveal()",
        "kiwihub.show(\"windows\")",
        "kiwihub.show(\"shortcuts\")",
        "kiwihub.show(\"view\")",
    ]

    @Sendable
    static func migratingShortcutBase(_ data: Data) -> Data? {
        guard belowShortcutBaseFloor(data) else { return nil }
        var bases: [String] = []
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(retiredDesktopBaseKey)\"".utf8))
                    != nil
                    || $0.range(of: Data(desktopRowPrefix.utf8)) != nil
            },
            rewriting: { node in
                bases = []
                return withShortcutBase(node, bases: &bases)
            },
            editing: { surgicallyRebasing($0, bases: bases) }
        )
    }

    private static func belowShortcutBaseFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < shortcutBaseBundleFormat
        case .profile: return format < shortcutBaseProfileFormat
        case .gui: return format < shortcutBaseGuiFormat
        case .palettes, .looks: return false
        }
    }

    /// The tree with the retired key replaced and every Desktop row
    /// on `✦` + digit moved; `bases` collects each new base value in
    /// the order the walk met them.
    static func withShortcutBase(
        _ node: Any,
        bases: inout [String]
    ) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                if key == retiredDesktopBaseKey {
                    changed = true
                    if dict[shortcutBaseKey] == nil {
                        let base = guessedBase(dict[shortcutBaseLayersKey])
                        bases.append(base)
                        out[shortcutBaseKey] = base
                    }
                    continue
                }
                if key == shortcutBaseBindingsKey, let rows = value as? [Any] {
                    let (moved, did) = movingDesktopRows(rows)
                    out[key] = moved
                    changed = changed || did
                    continue
                }
                let (child, did) = withShortcutBase(value, bases: &bases)
                out[key] = child
                changed = changed || did
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var changed = false
            let out = array.map { value -> Any in
                let (child, did) = withShortcutBase(value, bases: &bases)
                changed = changed || did
                return child
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// `hyper` where the default layer holds more of the moved
    /// letters on Hyper than on `⌃⌥`, else the seed's base.
    static func guessedBase(_ layers: Any?) -> String {
        let rows =
            (layers as? [[String: Any]])?.first {
                $0["name"] as? String == shortcutBaseDefaultLayer
            }?[shortcutBaseBindingsKey] as? [[String: Any]] ?? []
        var hyper = 0
        var standard = 0
        for row in rows {
            guard let lua = row["lua"] as? String,
                movedLetterLua.contains(lua),
                let text = row["combo"] as? String,
                let combo = KeyCombo.parse(text)
            else { continue }
            if combo.modifiers.contains(.hyper) {
                hyper += 1
            } else if combo.modifiers.isSuperset(of: [.control, .option]) {
                standard += 1
            }
        }
        return hyper > standard
            ? ShortcutBase.hyper.rawValue : ShortcutBase.standard.rawValue
    }

    private static func movingDesktopRows(_ rows: [Any]) -> ([Any], Bool) {
        var changed = false
        let out = rows.map { row -> Any in
            guard var binding = row as? [String: Any],
                let target = rebasedDesktopCombo(binding)
            else { return row }
            binding["combo"] = target
            changed = true
            return binding
        }
        return (out, changed)
    }

    /// `✦⌥` + digit for a Go to Desktop row on exactly `✦` + digit.
    static func rebasedDesktopCombo(_ row: [String: Any]) -> String? {
        guard let lua = row["lua"] as? String,
            lua.hasPrefix(desktopRowPrefix),
            let text = row["combo"] as? String,
            let combo = KeyCombo.parse(text),
            combo.modifiers == .hyper,
            KeyCombo.keyName(for: combo.keyCode).flatMap({ Int($0) }) != nil
        else { return nil }
        return KeyCombo(
            keyCode: combo.keyCode,
            modifiers: [.hyper, .option]
        ).comboString()
    }

    /// The textual edit: the retired key renamed with its new value
    /// where every occurrence takes the same one, and each Desktop
    /// row's combo rewritten inside its own object.
    static func surgicallyRebasing(
        _ text: String,
        bases: [String]
    ) -> Data? {
        var out = text
        if let base = bases.first {
            guard bases.allSatisfy({ $0 == base }) else { return nil }
            out = out.replacingOccurrences(
                of: "\"\(retiredDesktopBaseKey)\"(\\s*:\\s*)\"[^\"]*\"",
                with: "\"\(shortcutBaseKey)\"$1\"\(base)\"",
                options: .regularExpression
            )
        }
        guard
            let regex = try? NSRegularExpression(pattern: "\\{[^{}]*\\}")
        else { return nil }
        let whole = NSRange(out.startIndex..., in: out)
        for match in regex.matches(in: out, range: whole).reversed() {
            guard let range = Range(match.range, in: out),
                let object = try? JSONSerialization.jsonObject(
                    with: Data(out[range].utf8)
                ) as? [String: Any],
                let target = rebasedDesktopCombo(object)
            else { continue }
            let edited = out[range].replacingOccurrences(
                of: "(\"combo\"\\s*:\\s*)\"[^\"]*\"",
                with: "$1\"\(target)\"",
                options: .regularExpression
            )
            out.replaceSubrange(range, with: edited)
        }
        return out.data(using: .utf8)
    }
}
