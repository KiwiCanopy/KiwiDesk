import Foundation

/// The color surface a palette can set (#375): every color across
/// the App Bar, Space Bar, focus borders, and drag visuals, as
/// fully-qualified dotted paths matching the profile-JSON
/// vocabulary (`app_bar.fill_color`, `space_bar.fill_color`,
/// `border.focused_color`, `drag.ghost.fill_color`, …). The dotted
/// namespace is load-bearing: bare wire keys like `fill_color`
/// collide between the two bars.
///
/// Reflection-derived: each struct's `_color`-suffixed CodingKeys,
/// namespaced by where the struct sits in the settings tree, so a
/// new color key auto-joins the surface (and the drag structs
/// contribute their keys under both `ghost` and `drop_zone`). Every
/// color key in these structs ends in `_color`; nothing else does,
/// so the suffix filter is exact.
public enum ColorPaletteKeys {
    /// Every settable color path, in a stable order.
    public static var all: [String] {
        colorPaths(
            AppBarStyle.CodingKeys.allCases,
            prefix: "app_bar"
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
    }

    private static func colorPaths(
        _ cases: [some CodingKey],
        prefix: String
    ) -> [String] {
        cases.map(\.stringValue)
            .filter { $0.hasSuffix("_color") }
            .map { "\(prefix).\($0)" }
    }

    /// The current color values of `settings`, keyed by the same
    /// dotted paths — the inverse of `ColorPalette.apply`. Encodes
    /// the settings and reads each path out of the JSON, so it
    /// stays reflection-driven and can't miss a key the encoder
    /// emits. Backs both the derived "Kiwi (Default)" palette and
    /// "Save current colors as…" (#375).
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
