import Foundation

/// Retires the bars' on/off switches (#761, `BarVisibilityMigrationTests`,
/// `ConfigMigrationRoutingTests`): a bar is never off, only hidden
/// until its shortcut shows it. A Space Bar or a layout's App Bar
/// stored `enabled: false` becomes `visibility: hidden`; one stored
/// on keeps its visibility, `always` where it had none, so an
/// update changes nothing a user sees. The global
/// `app_bar.visibility` an unreleased build wrote moves onto each
/// layout's App Bar that was on.
///
/// Reaches a profile's `settings` and a bundle's inline profiles,
/// the two shapes that carry `TilingSettings`; `gui.json` carries
/// none (`GuiConfig.currentFormat`'s note). A tree walk alone: the
/// edit spans three keys at two depths, which no textual edit can
/// scope, and the walk is the correct fallback either way.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let retiredBarEnabledKey = "enabled"
    static let barVisibilityKey = "visibility"
    static let barHiddenValue = "hidden"

    @Sendable
    static func migratingBarVisibility(_ data: Data) -> Data? {
        let needle = Data("\"\(retiredBarEnabledKey)\"".utf8)
        let moved = Data("\"\(barVisibilityKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: needle) != nil || $0.range(of: moved) != nil
            },
            rewriting: withBarVisibility,
            editing: { _ in nil }
        )
    }

    /// Rewrites every `TilingSettings` object found at any depth —
    /// one carrying a `space_bar` or a `layout` key.
    static func withBarVisibility(_ node: Any) -> (Any, Bool) {
        if var dict = node as? [String: Any] {
            var changed = false
            for (key, value) in dict {
                let (child, childChanged) = withBarVisibility(value)
                dict[key] = child
                changed = changed || childChanged
            }
            if dict[shelfSpaceBarKey] != nil || dict["layout"] != nil {
                let (settings, rewrote) = barVisibilitySettings(dict)
                return (settings, changed || rewrote)
            }
            return (dict, changed)
        }
        if let array = node as? [Any] {
            var out: [Any] = []
            var changed = false
            for value in array {
                let (child, childChanged) = withBarVisibility(value)
                out.append(child)
                changed = changed || childChanged
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// One `TilingSettings` object's crossing.
    private static func barVisibilitySettings(
        _ settings: [String: Any]
    ) -> ([String: Any], Bool) {
        var out = settings
        var changed = false
        if var space = out[shelfSpaceBarKey] as? [String: Any],
            let on = space[retiredBarEnabledKey] as? Bool
        {
            space[retiredBarEnabledKey] = nil
            if !on { space[barVisibilityKey] = barHiddenValue }
            out[shelfSpaceBarKey] = space
            changed = true
        }
        var global: Any?
        if var app = out[shelfAppBarKey] as? [String: Any],
            let value = app[barVisibilityKey]
        {
            global = value
            app[barVisibilityKey] = nil
            out[shelfAppBarKey] = app
            changed = true
        }
        if var layouts = out["layout"] as? [String: Any] {
            for (name, value) in layouts {
                guard var layout = value as? [String: Any],
                    var bar = layout[shelfAppBarKey] as? [String: Any]
                else { continue }
                let on = bar[retiredBarEnabledKey] as? Bool
                guard on != nil || global != nil else { continue }
                bar[retiredBarEnabledKey] = nil
                if on == false {
                    bar[barVisibilityKey] = barHiddenValue
                } else if let global, bar[barVisibilityKey] == nil {
                    bar[barVisibilityKey] = global
                }
                layout[shelfAppBarKey] = bar
                layouts[name] = layout
                changed = true
            }
            out["layout"] = layouts
        }
        return (out, changed)
    }
}
