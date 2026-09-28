import Foundation

/// Retired verbs: #1517's, when the two bars moved onto one
/// shelf, #1674's `set_float_nudge`, #1713's item padding and
/// #1731's shelf edge, which each bar took back.
/// No aliases (AGENTS.md §5): a retired name fails, and the
/// failure names what replaces it — in Lua as a
/// `ConfigIssue.Kind.retiredCall`, over IPC through
/// `layoutCommand`.
extension APIReference {
    /// Retired verb → its replacement, or nil where nothing
    /// replaces it (the Space Bar's `item_size`).
    public static let retired: [String: String?] = {
        // The fields the migration moved onto the shelf — one
        // list, so a verb and its stored key retire together.
        var map: [String: String?] = [:]
        for field in ConfigMigration.shelfMovedKeys
        where field != ConfigMigration.shelfEdgeKey {
            let target: String? = "kiwishelf.set_\(field)"
            map["space_bar.set_\(field)"] = target
            map["app_bar.set_\(field)"] = target
            map["monocle.set_app_bar_\(field)"] = target
            map["scroll.set_app_bar_\(field)"] = target
        }
        // The edge is each bar's again (#1731), and no layout
        // overrides a layout-fixed App Bar field.
        map["kiwishelf.set_edge"] = "space_bar.set_edge"
        for key in AppBarStyle.layoutFixedKeys {
            let field = key.stringValue
            for layout in ["monocle", "scroll"] {
                map["\(layout).set_app_bar_\(field)"] =
                    "app_bar.set_\(field)"
            }
        }
        // An App Bar item is as wide as its title allows, so the
        // title length is the one width control left; a Space
        // item fits its content, with nothing to point at.
        for bar in [
            "app_bar.set_", "monocle.set_app_bar_",
            "scroll.set_app_bar_",
        ] {
            map[bar + "item_size"] = bar + "title_cap"
        }
        map["space_bar.set_item_size"] = .some(nil)
        map["space_bar.set_title_cap"] =
            "space_bar.set_front_app_title_cap"
        map["set_float_nudge"] = "set_float_placement"
        map["kiwishelf.set_item_padding"] = "kiwishelf.set_glyph_size"
        return map
    }()

    /// The failure a retired verb returns, or nil if `command` is
    /// not retired. English, like every CLI/IPC error (#96).
    public static func retirement(of command: String) -> String? {
        guard let replacement = retired[command] else { return nil }
        guard let replacement else {
            return "\(command) was retired: a Space item's"
                + " length follows its content"
        }
        return "\(command) was retired — use \(replacement)"
    }
}
