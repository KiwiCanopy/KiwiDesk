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
/// none (`GuiConfig.currentFormat`'s note). The textual edit keeps
/// a user's file byte for byte where it can; a global App Bar
/// value, or an `enabled` beside a stored `visibility`, stands down
/// to the walk.
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
            editing: surgicallyBarVisibility
        )
    }

    /// Each `space_bar` / `app_bar` object's own `enabled` pair:
    /// `true` dropped, `false` rewritten as `"visibility":"hidden"`,
    /// back to front so earlier offsets stay valid. Nil where a bar
    /// object also carries `visibility`, which the walk resolves.
    static func surgicallyBarVisibility(_ text: String) -> Data? {
        let opener = "\"(\(shelfSpaceBarKey)|\(shelfAppBarKey))\"\\s*:\\s*\\{"
        guard let regex = try? NSRegularExpression(pattern: opener)
        else { return nil }
        let utf16 = Array(text.utf16)
        var spans: [NSRange] = []
        for match in regex.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) {
            let brace = match.range.location + match.range.length - 1
            guard let close = closingBrace(from: brace, in: utf16)
            else { return nil }
            spans.append(
                NSRange(location: brace, length: close - brace + 1)
            )
        }
        let ns = text as NSString
        var out = text
        for span in spans.reversed() {
            let object = ns.substring(with: span)
            guard
                !object.contains("\"\(barVisibilityKey)\""),
                let pair = try? NSRegularExpression(
                    pattern: "\"\(retiredBarEnabledKey)\"\\s*:\\s*(true|false)"
                ),
                case let found = pair.matches(
                    in: object,
                    range: NSRange(
                        location: 0,
                        length: (object as NSString).length
                    )
                ),
                found.count <= 1
            else { return nil }
            guard let match = found.first else { continue }
            let on = (object as NSString).substring(with: match.range(at: 1))
            let edited =
                on == "true"
                ? removingPair(match.range, fromObject: object)
                : (object as NSString).replacingCharacters(
                    in: match.range,
                    with: "\"\(barVisibilityKey)\":\"\(barHiddenValue)\""
                )
            out = (out as NSString).replacingCharacters(in: span, with: edited)
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    /// `object` without the pair at `range` and the comma joining
    /// it to a neighbour.
    private static func removingPair(
        _ range: NSRange,
        fromObject object: String
    ) -> String {
        let ns = object as NSString
        let tail = NSRange(
            location: range.location + range.length,
            length: ns.length - range.location - range.length
        )
        if let comma = try? NSRegularExpression(pattern: "^\\s*,\\s*"),
            let after = comma.firstMatch(in: object, range: tail),
            after.range.location == tail.location
        {
            return ns.replacingCharacters(
                in: NSRange(
                    location: range.location,
                    length: range.length + after.range.length
                ),
                with: ""
            )
        }
        let head = ns.substring(to: range.location)
        if let comma = head.range(of: ",\\s*$", options: .regularExpression) {
            let start = head.distance(
                from: head.startIndex,
                to: comma.lowerBound
            )
            return ns.replacingCharacters(
                in: NSRange(
                    location: start,
                    length: range.location + range.length - start
                ),
                with: ""
            )
        }
        return ns.replacingCharacters(in: range, with: "")
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
        // A sparse file missing a layout's App Bar still keeps the
        // global value there, since the global key is gone.
        if let global {
            var layouts = out[shelfLayoutKey] as? [String: Any] ?? [:]
            for name in shelfLayoutHosts {
                var layout = layouts[name] as? [String: Any] ?? [:]
                var bar = layout[shelfAppBarKey] as? [String: Any] ?? [:]
                guard bar[barVisibilityKey] == nil else { continue }
                bar[barVisibilityKey] = global
                layout[shelfAppBarKey] = bar
                layouts[name] = layout
            }
            out[shelfLayoutKey] = layouts
        }
        return (out, changed)
    }
}
