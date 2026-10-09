import Foundation

/// Retired verbs: #1517's, when the two bars moved onto one
/// shelf, #1674's `set_float_nudge`, #1713's item padding and
/// #1731's shelf edge, which each bar took back, #1528's App Bar
/// content, #1810's `make_auto` and #1511's `pull_or_spawn`.
/// No aliases (AGENTS.md §5): a retired name fails, and the
/// failure names what replaces it — in Lua as a
/// `ConfigIssue.Kind.retiredCall`, over IPC through
/// `layoutCommand`.
extension APIReference {
    /// Retired verb → its replacement, or nil where nothing
    /// replaces it — `retiredReasons` then says why.
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
        // The edge is each bar's again (#1731). Only the edge
        // shipped as a per-layout verb, so only it retires; a
        // later global-only field (#1524's `reserve`) answers
        // with `applyBarOverride`'s refusal instead.
        map["kiwishelf.set_edge"] = "space_bar.set_edge"
        for key in [AppBarStyle.CodingKeys.edge] {
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
        map["space_bar.set_title_cap"] =
            "space_bar.set_front_app_title_cap"
        map["set_float_nudge"] = "set_float_placement"
        // A window is tiled or floating, and Tile hands it back
        // to detection (#1810).
        map["make_auto"] = "make_tiled"
        map["kiwishelf.set_item_padding"] = "kiwishelf.set_glyph_size"
        // The centred strip draws one more glyph at a row's end,
        // so the count is a span, not a cap (#1528).
        map["space_bar.set_glyph_cap"] = "space_bar.set_glyph_span"
        // Every window stroke takes the border's width and
        // corners (#1742).
        map["drag.set_ghost_border_width"] = "border.set_width"
        map["drag.set_drop_zone_border_width"] = "border.set_width"
        map["drag.set_corner_radius"] = "border.set_corner_style"
        map["pull_or_spawn"] = "focus_or_spawn"
        for verb in retiredReasons.keys { map[verb] = .some(nil) }
        return map
    }()

    /// Why a verb retired with no replacement, keyed by the verb —
    /// the one list `retired` takes its nil entries from.
    static let retiredReasons: [String: String] = {
        var map = ["space_bar.set_item_size": itemFollowsContent]
        // The App Bar always draws icon and title (#1528).
        for verb in [
            "app_bar.set_content", "monocle.set_app_bar_content",
            "scroll.set_app_bar_content",
        ] {
            map[verb] = appBarDrawsBoth
        }
        return map
    }()

    private static let itemFollowsContent =
        "a Space item's length follows its content"
    private static let appBarDrawsBoth =
        "the App Bar always draws each item's icon and title"

    /// The failure a retired verb returns, or nil if `command` is
    /// not retired. English, like every CLI/IPC error (#96).
    public static func retirement(of command: String) -> String? {
        guard let replacement = retired[command] else { return nil }
        guard let replacement else {
            let why = retiredReasons[command] ?? "it has no replacement"
            return "\(command) was retired: \(why)"
        }
        return "\(command) was retired — use \(replacement)"
    }
}
