import Foundation

/// One-shot rewrites of config files written by an older build
/// (AGENTS.md §5).
/// Format floors in `Profile`, `GuiConfig`, and `SetupBundle` (#902).
public enum ConfigMigration {
    /// Retired `app_bar.content` spellings mapped to current names
    /// (owner ruling 2026-08-19, `ConfigMigrationRoutingTests`).
    static let retiredBarContent = [
        "name": "title",
        "icon_and_name": "icon_and_title",
    ]

    /// Ordered migrations (`ScrollDurationMigrationTests`, #1020).
    private static let steps: [@Sendable (Data) -> Data?] = [
        migratingLegacyPalettesArray,
        migratingRetiredBarContent,
        migratingRetiredScrollSpeed,
    ]

    /// Target format integer for `root`'s shape (#902, #938, #939).
    static func targetFormat(for root: [String: Any]) -> Int {
        if root[SetupBundle.shapeMarker] != nil {
            return SetupBundle.currentFormat
        }
        if root[Profile.CodingKeys.monitorSets.rawValue] != nil
            || root["monitorSets"] != nil
        {
            return Profile.currentFormat
        }
        let palettes =
            PaletteDocument.CodingKeys.palettes.rawValue
        if root[palettes] != nil {
            return PaletteDocument.currentFormat
        }
        return GuiConfig.currentFormat
    }

    /// Whether `data` is below current format version (#902).
    static func needsMigration(_ data: Data) -> Bool {
        guard
            let json = try? JSONSerialization.jsonObject(
                with: data
            )
        else { return false }
        if json is [Any] {
            return true
        }
        guard let root = json as? [String: Any] else { return false }
        let format = root["format"] as? Int ?? 0
        return format < targetFormat(for: root)
    }

    /// Applies applicable migrations, returning modified data or nil (#938).
    public static func migrated(_ data: Data) -> Data? {
        guard needsMigration(data) else { return nil }
        var current = data
        for step in steps {
            if let next = step(current) {
                current = next
            }
        }
        let result = stamped(current)
        return result == data ? nil : result
    }

    /// Rewrites retired bar-content values in data.
    @Sendable
    static func migratingRetiredBarContent(
        _ data: Data
    ) -> Data? {
        surgicallyApplying(
            data,
            gate: { $0.range(of: Data("\"content\"".utf8)) != nil },
            rewriting: rewritten,
            editing: surgicallyEdited
        )
    }

    /// Replaces retired content values in text.
    private static func surgicallyEdited(_ text: String) -> Data? {
        var out = text
        for (retired, mapped) in retiredBarContent {
            out = out.replacingOccurrences(
                of: "(\"content\"\\s*:\\s*)\"\(retired)\"",
                with: "$1\"\(mapped)\"",
                options: .regularExpression
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    /// Recursively replaces retired `content` values in JSON tree.
    private static func rewritten(_ node: Any) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (key, value) in dict {
                if key == "content", let raw = value as? String,
                    let mapped = retiredBarContent[raw]
                {
                    out[key] = mapped
                    changed = true
                    continue
                }
                let (child, childChanged) = rewritten(value)
                out[key] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = rewritten(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
