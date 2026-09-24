import Foundation

/// `scroll.*` — scrolling layout command records (#1033). The
/// largest exemplar group: one of every argument shape the
/// surface has.
extension APIReference {
    static let scrollRecords: [String: APIRecord] = [
        "set_slot_size": APIRecord(
            "Sets the column or row size in points; a \"NN%\" "
                + "string is a fraction, 0 is auto.",
            .number("size")
        ),
        "set_anchor": APIRecord(
            "Sets where the focused window comes to rest in the "
                + "viewport.",
            .choice("anchor", ScrollingParams.Anchor.self)
        ),
        "set_orientation": APIRecord(
            "Sets whether columns scroll left/right or rows "
                + "scroll up/down.",
            .choice(
                "orientation",
                ScrollingParams.Orientation.self
            )
        ),
        "set_new_window_placement": APIRecord(
            "Sets where a new window lands in the row.",
            .choice("placement", SpawnPlacement.self)
        ),
        "set_wrap_focus": APIRecord(
            "Wraps focus from either end of the row to the far "
                + "end.",
            .boolean("enabled")
        ),
        "set_fill_when_alone": APIRecord(
            "A lone window takes the whole screen instead of "
                + "one slot; off keeps the slot size.",
            .boolean("enabled")
        ),
        "set_slot_size_override": APIRecord(
            "Overrides the slot size for one Space; same value "
                + "shape as the global setter.",
            .space("space"),
            .number("size")
        ),
        "set_anchor_override": APIRecord(
            "Overrides the anchor for one Space.",
            .space("space"),
            .choice("anchor", ScrollingParams.Anchor.self)
        ),
        "set_orientation_override": APIRecord(
            "Overrides the orientation for one Space.",
            .space("space"),
            .choice(
                "orientation",
                ScrollingParams.Orientation.self
            )
        ),
        "set_app_bar_enabled": APIRecord(
            "Shows or hides the App Bar in the scrolling layout.",
            .boolean("enabled")
        ),
        "set_app_bar_active_indicator": APIRecord(
            "Overrides the App Bar's focus marker for this "
                + "layout.",
            .choice(
                "indicator",
                AppBarStyle.ActiveIndicator.self
            )
        ),
        "set_app_bar_content": APIRecord(
            "Overrides what the App Bar's items draw for this "
                + "layout.",
            .choice("content", AppBarStyle.Content.self)
        ),
        "set_app_bar_title_cap": APIRecord(
            "Overrides the App Bar's title length cap for this "
                + "layout.",
            .integer("characters")
        ),
        "set_app_bar_group_adjacent_windows": APIRecord(
            "Overrides same-app window grouping in the App Bar "
                + "for this layout.",
            .boolean("enabled")
        ),
    ]
}
