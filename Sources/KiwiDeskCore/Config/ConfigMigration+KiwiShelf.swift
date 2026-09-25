import Foundation

/// Moves the bars' shared fields onto the shelf (#1517,
/// `KiwiShelfMigrationTests`): the Space Bar's values become
/// `kiwishelf`'s — the App Bar's, where the Space Bar is switched
/// off and so was not what the user looked at — every bar's
/// copies drop, `item_size` drops everywhere, the Space Bar's
/// `title_cap` becomes `front_app_title_cap`, a `gap` indicator
/// becomes `outline`, and an App Bar that names no indicator gets
/// `outline` ahead of its default's flip. Reaches a profile
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
        "font_size", "icon_source", "dim_factor", "item_color",
        "active_item_color", "highlight_color", "hover_fill_color",
        "hover_item_color", "fill_color", "group_badge_color",
        "group_badge_text_color",
    ]
    static let shelfItemColorKey = "item_color"
    static let shelfIndicatorKey = "active_indicator"
    /// The indicator #1517 removed, and the one it becomes.
    static let shelfRetiredIndicator = "gap"
    static let shelfIndicatorFallback = "outline"
    static let shelfDroppedKeys = ["item_size"]
    static let shelfEdgeKey = "edge"
    /// The App Bar's edge default before #1517, which the shelf's
    /// own (top) replaced: an App Bar source that never stored
    /// its edge sat there, so the shelf writes it rather than
    /// letting absence mean the new default.
    static let shelfAppBarOldEdge = "bottom"
    static let shelfRetiredTitleKey = "title_cap"
    static let shelfFrontTitleKey = "front_app_title_cap"

    /// The formats this step introduced — a profile's and a
    /// bundle's — spelled as history. The step reads ABSENCE as
    /// the old defaults (an App Bar source's edge is its old
    /// bottom), which is true only below them: a shelf-shaped
    /// file whose `kiwishelf.edge` is absent MEANS the new top.
    static let shelfProfileFormat = 8
    static let shelfBundleFormat = 12

    @Sendable
    static func migratingBarsOntoShelf(_ data: Data) -> Data? {
        guard shelfStepApplies(to: data) else { return nil }
        return surgicallyApplying(
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

    /// Whether `data`'s stamp is below the format this step
    /// introduced for its shape. An unreadable root stands down.
    static func shelfStepApplies(to data: Data) -> Bool {
        stampBelow(
            data,
            file: shelfProfileFormat,
            bundle: shelfBundleFormat
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
        let sourceKey = shelfSourceKey(spaceBar: spaceBar)
        let source = settings[sourceKey] as? [String: Any] ?? [:]
        var shelf = settings[shelfKey] as? [String: Any] ?? [:]
        let heldItemColor = shelf[shelfItemColorKey] != nil
        for key in shelfMovedKeys {
            guard let value = source[key], shelf[key] == nil
            else { continue }
            shelf[key] = value
            changed = true
        }
        if !heldItemColor,
            let app = settings[shelfAppBarKey] as? [String: Any],
            let full = app[shelfItemColorKey] as? String,
            let dimmed = source[shelfItemColorKey] as? String,
            isDimmedTwin(dimmed, of: full)
        {
            shelf[shelfItemColorKey] = full
        }
        if sourceKey == shelfAppBarKey, shelf[shelfEdgeKey] == nil {
            shelf[shelfEdgeKey] = shelfAppBarOldEdge
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
            if retiringGap(&bar) { changed = true }
            if group == shelfAppBarKey, bar[shelfIndicatorKey] == nil {
                bar[shelfIndicatorKey] = shelfIndicatorFallback
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
                if retiringGap(&bar) { changed = true }
                params[shelfAppBarKey] = bar
                layout[host] = params
            }
            out[shelfLayoutKey] = layout
        }
        return (out, changed)
    }

    /// Rewrites a `gap` indicator to `outline`; true if it did.
    static func retiringGap(_ bar: inout [String: Any]) -> Bool {
        guard bar[shelfIndicatorKey] as? String == shelfRetiredIndicator
        else { return false }
        bar[shelfIndicatorKey] = shelfIndicatorFallback
        return true
    }

    /// Whether `dimmed` is `full`'s colour at a lower alpha — the
    /// Space Bar's idle ink as every bundled palette wrote it,
    /// which the shelf's idle rule now applies (#1517), so the
    /// shelf takes `full` rather than dimming twice.
    static func isDimmedTwin(_ dimmed: String, of full: String) -> Bool {
        guard let low = hexChannels(dimmed), let high = hexChannels(full)
        else { return false }
        return low.rgb == high.rgb && low.alpha < high.alpha
    }

    /// A `#RRGGBB` / `#RRGGBBAA` string's colour and alpha,
    /// upper-cased; an absent alpha is opaque.
    static func hexChannels(
        _ hex: String
    ) -> (rgb: String, alpha: String)? {
        let body = hex.uppercased().drop { $0 == "#" }
        guard body.count == 6 || body.count == 8,
            body.allSatisfy(\.isHexDigit)
        else { return nil }
        let rgb = String(body.prefix(6))
        return (rgb, body.count == 8 ? String(body.suffix(2)) : "FF")
    }
}
