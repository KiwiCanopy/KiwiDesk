import Foundation

/// The styling paths a look may set (#1684). A field is STYLING
/// if it changes how the same items look or where they sit, and
/// functionality if it changes which items exist, what they show
/// or say, or what they do (owner ruling 2026-09-27) — so App Bar
/// content, Windows in other Spaces and each bar's on/off never
/// join. The
/// focus border's shape and the global gaps join too (#1739), so
/// a look reproduces its whole picture. Colours are a palette's,
/// never a look's. Motion joins too (#2176), so animations travel
/// between profiles with the shared look; a bundled look and the
/// tour's paint carry styling alone.
public enum LookKeys {
    /// Every path a look may set: its styling, then its motion.
    public static let all: [String] = styling + motion

    /// The animation paths (#2176) — every stored field of
    /// `AnimationSettings`, read off its keys. A look the user
    /// saves and the shared look carry them; a bundled look and
    /// the tour's paint never do (`LookKeysCensusTests`).
    public static let motion: [String] =
        AnimationSettings.CodingKeys.allCases.map {
            "animations.\($0.stringValue)"
        }

    /// The styling paths: how the same items look or where they
    /// sit. What a bundled look and the tour's paint reach.
    public static let styling: [String] =
        shelfFields.map { "kiwishelf.\($0)" } + [
            // Each bar's own edge (#1731): a look that places the
            // bars says where each sits, on/off left alone.
            "space_bar.edge",
            "app_bar.edge",
            "space_bar.active_indicator",
            "space_bar.glyph_gap",
            "space_bar.active_dim_factor",
            "app_bar.active_indicator",
            "border.sheen",
            "border.width",
            "border.corner_style",
            "border.glow",
            "border.glow_size",
            "gap.global",
        ]

    /// The shelf's styling fields by wire key.
    static let shelfFields = [
        "alignment", "order", "thickness", "outer_margin",
        "inner_margin", "background_style", "liquid_glass",
        "background_fit", "corner_roundness", "border",
        "border_width", "highlight_width", "item_gap", "glyph_size",
        "font_size", "font_family", "font_weight", "icon_source",
        "dim_factor",
    ]

    /// Paths of the stores a look reaches that it leaves alone,
    /// and why. `LookKeysCensusTests` reds a field of `KiwiShelf`,
    /// `SpaceBarStyle`, `AppBarStyle`, `BorderStyle` or `gap` that
    /// is in neither `all`, the palette's colours nor here.
    static let leftOut: [String: String] = [
        "kiwishelf.minimum": "how much of each bar shows once the "
            + "shelf is full — which items are visible",
        "space_bar.enabled": functionality,
        "space_bar.reserve": functionality,
        "app_bar.reserve": functionality,
        "space_bar.glyph_span": functionality,
        "space_bar.inactive_content": functionality,
        "space_bar.peek_on_hover": functionality,
        "space_bar.front_app_title_cap": functionality,
        "space_bar.show_front_app": functionality,
        "space_bar.hide_empty": functionality,
        "space_bar.group_adjacent_windows": functionality,
        "space_bar.sticky_badge": functionality,
        "space_bar.spring_delay": functionality,
        "space_bar.item_label": functionality,
        "app_bar.title_cap": functionality,
        "app_bar.group_adjacent_windows": functionality,
        "border.enabled": functionality,
        "border.unfocused_enabled": functionality,
        "border.draw_order": "whether the ring draws over or "
            + "under the window's own chrome — which one shows",
        "gap.override": "a Space's own exception to the global "
            + "gaps, set on that Space and kept through a look",
        "space_bar.edge_override": screenEdges,
        "app_bar.edge_override": screenEdges,
    ]

    /// Why a bar's per-screen edges stay out (#1948).
    private static let screenEdges =
        "a screen's own edge names this Mac's screens, and kept "
        + "through a look it stays the strongest"

    private static let functionality =
        "which items exist, what they show or what they do"

    /// Extracts the look map from settings, every path in `paths`.
    public static func extract(
        from settings: TilingSettings,
        paths: [String] = all
    ) -> [String: JSONValue] {
        guard let root = JSONValue(encoding: settings) else { return [:] }
        var out: [String: JSONValue] = [:]
        for path in paths {
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
