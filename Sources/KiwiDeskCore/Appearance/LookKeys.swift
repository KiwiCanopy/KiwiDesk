import Foundation

/// The styling paths a look may set (#1684). A field is STYLING
/// if it changes how the same items look or where they sit, and
/// functionality if it changes which items exist, what they show
/// or say, or what they do (owner ruling 2026-09-27) — so App Bar
/// content, Other Spaces and each bar's on/off never join.
/// Colours are a palette's, never a look's.
public enum LookKeys {
    /// Every settable styling path, in a stable order.
    public static let all: [String] =
        shelfFields.map { "kiwishelf.\($0)" } + [
            "space_bar.active_indicator",
            "app_bar.active_indicator",
            "border.sheen",
        ]

    /// The shelf's styling fields by wire key.
    /// `LookKeysCensusTests` reds a `KiwiShelf` key that is in
    /// neither this list, the palette's colours, nor `leftOut`.
    static let shelfFields = [
        "edge", "alignment", "order", "thickness", "outer_margin",
        "inner_margin", "background_style", "liquid_glass",
        "background_fit", "corner_roundness", "border",
        "border_width", "highlight_width", "item_gap", "glyph_size",
        "font_size", "font_family", "font_weight", "icon_source",
        "dim_factor",
    ]

    /// Shelf keys a look leaves alone, and why.
    static let leftOut = [
        "minimum": "decides how much of each bar shows once the "
            + "shelf is full — which items are visible, set by "
            + "the divider drag"
    ]

    /// Extracts the styling map from settings, every path in `all`.
    public static func extract(
        from settings: TilingSettings
    ) -> [String: JSONValue] {
        guard let data = try? JSONEncoder().encode(settings),
            let root = try? JSONDecoder().decode(
                JSONValue.self,
                from: data
            )
        else { return [:] }
        var out: [String: JSONValue] = [:]
        for path in all {
            if let value = value(at: path, in: root) {
                out[path] = value
            }
        }
        return out
    }

    private static func value(
        at path: String,
        in root: JSONValue
    ) -> JSONValue? {
        var node: JSONValue? = root
        for part in path.split(separator: ".") {
            guard case .object(let map) = node else { return nil }
            node = map[String(part)]
        }
        return node
    }
}
