import Foundation

/// Moves the bars' shared fields onto the shelf (#1517,
/// `KiwiShelfMigrationTests`): the Space Bar's values become
/// `kiwishelf`'s — the App Bar's, where the Space Bar is switched
/// off and so was not what the user looked at — every bar's
/// copies drop, `item_size` drops everywhere, and the Space Bar's
/// `title_cap` becomes `front_app_title_cap`. Reaches a profile
/// root's `settings` and a bundle root's `profiles[].settings`,
/// the per-layout `app_bar` overrides under `layout` included.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let shelfKey = "kiwishelf"
    static let shelfSettingsKey = "settings"
    static let shelfProfilesKey = "profiles"
    static let shelfSpaceBarKey = "space_bar"
    static let shelfAppBarKey = "app_bar"
    static let shelfLayoutKey = "layout"
    static let shelfLayoutHosts = ["monocle", "scroll"]
    static let shelfMovedKeys = [
        "edge", "alignment", "thickness", "outer_margin",
        "inner_margin", "background_style", "liquid_glass",
        "background_fit", "corner_roundness", "item_gap",
        "font_size",
    ]
    static let shelfDroppedKeys = ["item_size"]
    static let shelfRetiredTitleKey = "title_cap"
    static let shelfFrontTitleKey = "front_app_title_cap"

    @Sendable
    static func migratingBarsOntoShelf(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(shelfSpaceBarKey)\"".utf8))
                    != nil
                    || $0.range(of: Data("\"\(shelfAppBarKey)\"".utf8))
                        != nil
            },
            rewriting: withBarsOnShelf,
            editing: surgicallyShelvedBars
        )
    }

    /// The two paths: the root's own `settings`, and each inline
    /// profile's under `profiles`.
    static func withBarsOnShelf(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[shelfSettingsKey] as? [String: Any] {
            let (moved, did) = shelvedSettings(settings)
            if did {
                root[shelfSettingsKey] = moved
                changed = true
            }
        }
        if let profiles = root[shelfProfilesKey] as? [[String: Any]] {
            var out = profiles
            var did = false
            for (index, profile) in profiles.enumerated() {
                guard
                    let settings = profile[shelfSettingsKey]
                        as? [String: Any]
                else { continue }
                let (moved, changedOne) = shelvedSettings(settings)
                guard changedOne else { continue }
                out[index][shelfSettingsKey] = moved
                did = true
            }
            if did {
                root[shelfProfilesKey] = out
                changed = true
            }
        }
        return (root, changed)
    }

    /// Which bar's shared values the shelf takes: the Space
    /// Bar's, unless it is switched off.
    static func shelfSourceKey(spaceBar: [String: Any]?) -> String {
        spaceBar?["enabled"] as? Bool == false
            ? shelfAppBarKey : shelfSpaceBarKey
    }

    /// One `TilingSettings` object.
    static func shelvedSettings(
        _ settings: [String: Any]
    ) -> ([String: Any], Bool) {
        var out = settings
        var changed = false
        let spaceBar = settings[shelfSpaceBarKey] as? [String: Any]
        let source =
            settings[shelfSourceKey(spaceBar: spaceBar)]
            as? [String: Any] ?? [:]
        var shelf = settings[shelfKey] as? [String: Any] ?? [:]
        for key in shelfMovedKeys {
            guard let value = source[key], shelf[key] == nil
            else { continue }
            shelf[key] = value
            changed = true
        }
        if !shelf.isEmpty { out[shelfKey] = shelf }
        let stripped = shelfMovedKeys + shelfDroppedKeys
        for group in [shelfSpaceBarKey, shelfAppBarKey] {
            guard var bar = out[group] as? [String: Any] else {
                continue
            }
            for key in stripped where bar[key] != nil {
                bar[key] = nil
                changed = true
            }
            if group == shelfSpaceBarKey,
                let title = bar[shelfRetiredTitleKey]
            {
                bar[shelfRetiredTitleKey] = nil
                if bar[shelfFrontTitleKey] == nil {
                    bar[shelfFrontTitleKey] = title
                }
                changed = true
            }
            out[group] = bar
        }
        if var layout = out[shelfLayoutKey] as? [String: Any] {
            for host in shelfLayoutHosts {
                guard var params = layout[host] as? [String: Any],
                    var bar = params[shelfAppBarKey] as? [String: Any]
                else { continue }
                for key in stripped where bar[key] != nil {
                    bar[key] = nil
                    changed = true
                }
                params[shelfAppBarKey] = bar
                layout[host] = params
            }
            out[shelfLayoutKey] = layout
        }
        return (out, changed)
    }
}
