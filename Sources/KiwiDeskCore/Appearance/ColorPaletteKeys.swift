import Foundation

/// The color surface a palette can set (#375): every color across
/// the App Bar, Space Bar, focus borders, drag visuals and the
/// sticky/floating marks, as fully-qualified dotted paths matching
/// the profile-JSON vocabulary (`app_bar.fill_color`,
/// `space_bar.fill_color`, `border.focused_color`,
/// `drag.ghost.fill_color`, `sticky.color`, …). The dotted
/// namespace is load-bearing: bare wire keys like `fill_color`
/// collide between the two bars.
///
/// Reflection-derived: each struct's color CodingKeys, namespaced
/// by where the struct sits in the settings tree, so a new color
/// key auto-joins the surface (and the drag structs contribute
/// their keys under both `ghost` and `drop_zone`).
///
/// The mark structs joined in the #678 Colours phase: Advanced
/// Colours renders every color KiwiDesk has on one page under a
/// "save these as a palette" promise, and the two mark tints were
/// the only rows on it that a palette could not carry — a bridge
/// that silently drops two of its rows. Their CodingKey is bare
/// `color` (the struct IS the mark), which is why the filter below
/// admits an exact `color` alongside the `_color` suffix rather
/// than renaming a shipped wire key.
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
            + colorPaths(
                StickyStyle.CodingKeys.allCases,
                prefix: "sticky"
            )
            + colorPaths(
                FloatingStyle.CodingKeys.allCases,
                prefix: "floating"
            )
    }

    /// Whether `path` may carry the empty "Automatic" value as
    /// well as a hex. Only the two mark tints have an adaptive
    /// face (`StickyStyle.color`'s empty default is the system
    /// label color), and their bare `color` key is exactly what
    /// distinguishes them — every other path ends in `_color`.
    /// Derived from the path so a third mark struct cannot join
    /// the surface without joining this too.
    ///
    /// Without it the surface would be one-directional: a palette
    /// could paint a mark but never hand it back to Automatic,
    /// and the derived default palette — which extracts the
    /// shipped defaults, both of them empty — would carry two
    /// values `apply` silently dropped.
    public static func allowsAutomatic(_ path: String) -> Bool {
        path.hasSuffix(".color")
    }

    private static func colorPaths(
        _ cases: [some CodingKey],
        prefix: String
    ) -> [String] {
        cases.map(\.stringValue)
            .filter { $0.hasSuffix("_color") || $0 == "color" }
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
