import Foundation

/// Turns the one stored minimum window size into one per layout
/// (#2237, `MinWindowSizeMigrationTests`): a number `n` becomes
/// `{width: n, height: n}` for every layout. Reaches every
/// `TilingSettings` a file carries, by PATH: a profile root's
/// `settings` and each of a bundle's `profiles[].settings` —
/// `gui.json` stores no `settings`. Every build's encoder wrote the
/// key, so an absent one is a hand edit the decoder's 300 answers.
/// Idempotent: an object is left alone.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let minSizeKey = "min_window_size"
    static let minSizeLayouts = [
        "bsp", "floating", "grid", "scrolling", "stack", "track",
    ]

    @Sendable
    static func migratingMinWindowSizePerLayout(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(minSizeKey)\"".utf8)) != nil
            },
            rewriting: withPerLayoutMinSizes,
            editing: surgicallySplitMinSizes
        )
    }

    /// The two paths, through the settings key the glass step
    /// declares (`ConfigMigrationGlassRoutingTests`).
    static func withPerLayoutMinSizes(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = split(&root)
        if var profiles = root[glassProfilesKey] as? [[String: Any]] {
            var did = false
            for index in profiles.indices where split(&profiles[index]) {
                did = true
            }
            if did {
                root[glassProfilesKey] = profiles
                changed = true
            }
        }
        return (root, changed)
    }

    /// `owner`'s `settings` rewritten in place; false where it has
    /// none or its value is already per layout.
    private static func split(_ owner: inout [String: Any]) -> Bool {
        guard
            var settings = owner[glassSettingsKey] as? [String: Any],
            let side = settings[minSizeKey] as? NSNumber
        else { return false }
        settings[minSizeKey] = Dictionary(
            uniqueKeysWithValues: minSizeLayouts.map {
                ($0, ["width": side, "height": side])
            }
        )
        owner[glassSettingsKey] = settings
        return true
    }

    /// The textual edit: every `"min_window_size": n` spelled out
    /// per layout, the number kept as written.
    static func surgicallySplitMinSizes(_ text: String) -> Data? {
        guard
            let regex = try? NSRegularExpression(
                pattern: "(\"\(minSizeKey)\"\\s*:\\s*)"
                    + "(-?[0-9]+(?:\\.[0-9]+)?(?:[eE][-+]?[0-9]+)?)"
            )
        else { return nil }
        var out = text
        let whole = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: whole).reversed() {
            guard let range = Range(match.range(at: 2), in: out)
            else { return nil }
            let number = String(out[range])
            let side = "{\"height\": \(number), \"width\": \(number)}"
            let object =
                "{"
                + minSizeLayouts.map { "\"\($0)\": \(side)" }
                .joined(separator: ", ")
                + "}"
            out.replaceSubrange(range, with: object)
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
