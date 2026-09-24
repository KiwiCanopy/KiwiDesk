import Foundation

/// Verbs #1517 retired when the two bars moved onto one shelf.
/// No aliases (AGENTS.md §5): a retired name fails, and the
/// failure names what replaces it — in Lua through the typo
/// guard's did-you-mean, over IPC through `layoutCommand`.
extension APIReference {
    /// Retired verb → its replacement, or nil where nothing
    /// replaces it (`item_size`: items size themselves).
    public static let retired: [String: String?] = {
        let moved = [
            "edge", "alignment", "thickness", "outer_margin",
            "inner_margin", "background_style", "liquid_glass",
            "background_fit", "corner_roundness", "item_gap",
            "font_size",
        ]
        var map: [String: String?] = [:]
        for field in moved {
            let target: String? = "kiwishelf.set_\(field)"
            map["space_bar.set_\(field)"] = target
            map["app_bar.set_\(field)"] = target
            map["monocle.set_app_bar_\(field)"] = target
            map["scroll.set_app_bar_\(field)"] = target
        }
        for bar in [
            "space_bar.set_", "app_bar.set_",
            "monocle.set_app_bar_", "scroll.set_app_bar_",
        ] {
            map[bar + "item_size"] = .some(nil)
        }
        map["space_bar.set_title_cap"] =
            "space_bar.set_front_app_title_cap"
        return map
    }()

    /// The failure a retired verb returns, or nil if `command` is
    /// not retired. English, like every CLI/IPC error (#96).
    public static func retirement(of command: String) -> String? {
        guard let replacement = retired[command] else { return nil }
        guard let replacement else {
            return "\(command) was retired in 2.0: bar items size"
                + " themselves"
        }
        return "\(command) was retired in 2.0 — use \(replacement)"
    }
}
