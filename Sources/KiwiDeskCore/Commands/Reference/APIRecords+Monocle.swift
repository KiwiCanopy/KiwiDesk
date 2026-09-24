import Foundation

/// `monocle.*` — monocle layout command records (#1033).
extension APIReference {
    static let monocleRecords: [String: APIRecord] = [
        "set_orientation": APIRecord(
            "Sets the axis along which focus cycles through "
                + "windows.",
            .choice(
                "orientation",
                MonocleParams.Orientation.self
            )
        ),
        "set_orientation_override": APIRecord(
            "Overrides the orientation for one Space.",
            .space("space"),
            .choice(
                "orientation",
                MonocleParams.Orientation.self
            )
        ),
        "set_hide_style": APIRecord(
            "Sets how unfocused monocle windows are hidden.",
            .choice("style", MonocleParams.HideStyle.self)
        ),
        "set_wrap_focus": APIRecord(
            "Wraps focus from either end of the cycle to the "
                + "other.",
            .boolean("enabled")
        ),
        "set_new_window_placement": APIRecord(
            "Sets where a new window lands in the monocle cycle.",
            .choice("placement", SpawnPlacement.self)
        ),
        "set_app_bar_enabled": APIRecord(
            "Shows or hides the App Bar in the monocle layout.",
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
