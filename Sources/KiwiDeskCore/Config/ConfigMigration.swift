import Foundation

/// One-shot rewrites of config files written by an older build
/// (AGENTS.md §5); format floors in `Profile`, `GuiConfig` and
/// `SetupBundle` (#902).
///
/// `init.lua` is deliberately out of scope — the user's own
/// script fails LOUDLY with a refusal naming the fix. That
/// carve-out also covers the Lua riding INSIDE files this app
/// rewrites (`layers[].bindings[].lua` in gui.json and every
/// profile): a renamed VERB breaks such a binding and is still
/// not migrated — the crossing reaches the config VOCABULARY
/// around the script, never the script (#1020).
public enum ConfigMigration {
    /// Retired `app_bar.content` spellings mapped to current names
    /// (owner ruling 2026-08-19). The walk rewrites by KEY at any
    /// depth, so its breadth is bounded by THIS map: a second
    /// `content` CodingKey anywhere in the config owes the walk a
    /// path or this map a narrower home —
    /// `ConfigMigrationRoutingTests` says so on arrival.
    static let retiredBarContent = [
        "name": "title",
        "icon_and_name": "icon_and_title",
    ]

    /// Ordered migrations, oldest first; each step takes the bytes
    /// as they stand after the previous one. **A step added here is
    /// not yet a step that RUNS**: `needsMigration` short-circuits
    /// on the format stamp, so a step owes a `currentFormat` bump
    /// on EVERY shape it must reach — without one it is dead on
    /// arrival, silently, on exactly the files it exists to rescue
    /// (#1020, `ScrollDurationMigrationTests`). Nothing pins that
    /// coupling, which is why it is stated here.
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

    /// Applies applicable migrations, returning modified data or
    /// nil. Nil rather than the unchanged bytes, deliberately: a
    /// caller writes back exactly when this returns non-nil, so an
    /// untouched config is never rewritten and its mtime never
    /// moves. A stale format whose bytes no step rewrites is still
    /// stamped — a crossing must END (#938).
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
