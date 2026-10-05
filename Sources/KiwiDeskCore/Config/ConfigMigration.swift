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
/// around the script, never the script (#1020). A RE-SCALED
/// argument (#1354's `track.set_limit`) is the case that
/// carve-out does not catch: the old spelling still runs and
/// means one less, silently.
public enum ConfigMigration {
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
        migratingRetiredScrollSpeed,
        migratingProfileBindingStrings,
        migratingRetiredResizeFeedback,
        migratingAbsentGlassLeaves,
        migratingTrackLimitCount,
        migratingProfileBindingLists,
        migratingBarsOntoShelf,
        migratingPalettesOntoShelf,
        migratingAbsentOverlayGlass,
        migratingRetiredFloatNudge,
        migratingShelfEdgeOntoBars,
        migratingRetiredGlyphCap,
        migratingProfileLookOwn,
        migratingRetiredAppBarContent,
        migratingDuplicateSpaceChords,
        migratingAbsentSpaceSwitchGlass,
    ]

    /// The file shapes a config root can take.
    enum FileShape { case bundle, profile, palettes, looks, gui }

    /// Which shape `root` is — the one classification every
    /// per-shape floor asks.
    static func shape(of root: [String: Any]) -> FileShape {
        if root[SetupBundle.shapeMarker] != nil { return .bundle }
        if root[Profile.CodingKeys.monitorSets.rawValue] != nil
            || root["monitorSets"] != nil
        {
            return .profile
        }
        let palettes =
            PaletteDocument.CodingKeys.palettes.rawValue
        if root[palettes] != nil { return .palettes }
        if root[LookDocument.CodingKeys.looks.rawValue] != nil {
            return .looks
        }
        return .gui
    }

    /// Target format integer for `root`'s shape (#902, #938, #939,
    /// #1684).
    static func targetFormat(for root: [String: Any]) -> Int {
        switch shape(of: root) {
        case .bundle: SetupBundle.currentFormat
        case .profile: Profile.currentFormat
        case .palettes: PaletteDocument.currentFormat
        case .looks: LookDocument.currentFormat
        case .gui: GuiConfig.currentFormat
        }
    }

    /// Whether `data`'s stamp is below the floor a step introduced
    /// for its shape — a bundle's `bundle`, any other root's
    /// `file` (a profile's, or `palettes.json`'s). A `gui.json`
    /// root reads the same `file` floor, so a step asking this
    /// must also gate on a key `gui.json` never carries
    /// (`settings`, `palettes`). An unreadable root stands down.
    static func stampBelow(
        _ data: Data,
        file: Int,
        bundle: Int
    ) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        let floor =
            root[SetupBundle.shapeMarker] != nil ? bundle : file
        return format < floor
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

    /// The one keyed tree walk the steps share: every value
    /// under `key`, at any depth, replaced by what `rewrite`
    /// returns for it — nil leaves it and descends. A dict or an
    /// array is walked; anything else is a leaf.
    static func rewritingValues(
        of node: Any,
        at key: String,
        _ rewrite: (Any) -> Any?
    ) -> (Any, Bool) {
        if let dict = node as? [String: Any] {
            var out: [String: Any] = [:]
            var changed = false
            for (name, value) in dict {
                if name == key, let replaced = rewrite(value) {
                    out[name] = replaced
                    changed = true
                    continue
                }
                let (child, childChanged) = rewritingValues(
                    of: value,
                    at: key,
                    rewrite
                )
                out[name] = child
                changed = changed || childChanged
            }
            return (out, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = rewritingValues(
                    of: value,
                    at: key,
                    rewrite
                )
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }
}
