import Foundation

/// Dotted color key definitions for theme palettes (#375,
/// #678). The dotted namespace is load-bearing — bare wire keys
/// like `fill_color` collide between groups — and the
/// surface is reflection-derived from each struct's color
/// CodingKeys, so a new color key auto-joins.
public enum ColorPaletteKeys {
    /// Every settable color path, in a stable order.
    public static var all: [String] {
        colorPaths(
            KiwiShelf.CodingKeys.allCases,
            prefix: "kiwishelf"
        )
            + colorPaths(
                SpaceBarStyle.CodingKeys.allCases,
                prefix: "space_bar"
            )
            + colorPaths(
                BorderStyle.CodingKeys.allCases,
                prefix: "border"
            )
            + colorPaths(
                DragVisual.CodingKeys.allCases,
                prefix: "drag.ghost"
            )
            + colorPaths(
                DragVisual.CodingKeys.allCases,
                prefix: "drag.drop_zone"
            )
            + colorPaths(
                StickyStyle.CodingKeys.allCases,
                prefix: "sticky"
            )
            + colorPaths(
                FloatingStyle.CodingKeys.allCases,
                prefix: "floating"
            )
    }

    /// Whether path permits the empty "Automatic" value: a mark's
    /// adaptive tint (`StickyStyle.color`), derived from the path
    /// so a third mark struct cannot join the surface without
    /// joining this too, or a `followers` colour. Without it the
    /// surface is one-directional: a palette could paint the
    /// colour but never hand it back to Automatic.
    public static func allowsAutomatic(_ path: String) -> Bool {
        path.hasSuffix(".color") || followers[path] != nil
    }

    /// Colours whose Automatic is ANOTHER colour of the palette
    /// rather than an adaptive tint, keyed to the path they follow
    /// (#1856): the front chip's ring follows the front app's own
    /// text, as every bundled palette pairs a text with its ring.
    public static let followers: [String: String] = [
        "space_bar.focused_highlight_color":
            "space_bar.focused_item_color"
    ]

    /// `path`'s colour in `colors` as it is DRAWN: a follower left
    /// Automatic reads the colour it follows — the one reading a
    /// picture of a palette takes, held to the renderer's own by
    /// `ColorPaletteFollowerTests`.
    public static func resolved(
        _ path: String,
        in colors: [String: String]
    ) -> String {
        let hex = colors[path] ?? ""
        if hex.isEmpty, let leader = followers[path] {
            return resolved(leader, in: colors)
        }
        return hex
    }

    private static func colorPaths(
        _ cases: [some CodingKey],
        prefix: String
    ) -> [String] {
        cases.map(\.stringValue)
            .filter { $0.hasSuffix("_color") || $0 == "color" }
            .map { "\(prefix).\($0)" }
    }

    /// Extracts color dictionary from settings (`ColorPalette.apply`, #375).
    public static func extract(
        from settings: TilingSettings
    ) -> [String: String] {
        guard let data = try? JSONEncoder().encode(settings),
            let root = try? JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]
        else { return [:] }
        var out: [String: String] = [:]
        for path in all {
            if let hex = value(at: path, in: root) {
                out[path] = hex
            }
        }
        return out
    }

    private static func value(
        at path: String,
        in root: [String: Any]
    ) -> String? {
        var node: Any? = root
        for part in path.split(separator: ".") {
            node = (node as? [String: Any])?[String(part)]
        }
        return node as? String
    }
}
