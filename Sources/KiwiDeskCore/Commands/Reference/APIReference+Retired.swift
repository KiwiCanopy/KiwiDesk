import Foundation

/// Verbs #1517 retired when the two bars moved onto one shelf.
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
        for field in ConfigMigration.shelfMovedKeys {
            let target: String? = "kiwishelf.set_\(field)"
            map["space_bar.set_\(field)"] = target
            map["app_bar.set_\(field)"] = target
            map["monocle.set_app_bar_\(field)"] = target
            map["scroll.set_app_bar_\(field)"] = target
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
        return map
    }()

    /// The failure a retired verb returns, or nil if `command` is
    /// not retired. English, like every CLI/IPC error (#96).
    public static func retirement(of command: String) -> String? {
        guard let replacement = retired[command] else { return nil }
        guard let replacement else {
            return "\(command) was retired in 2.0: a Space item's"
                + " length follows its content"
        }
        return "\(command) was retired in 2.0 — use \(replacement)"
    }
}
