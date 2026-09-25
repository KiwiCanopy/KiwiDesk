import Foundation

/// `app_bar.*` — global App Bar style command records (#1033).
/// An exemplar group: colour setters show `.color`, pickers a
/// `.choice` reading its decoder's cases.
extension APIReference {
    static let appBarRecords: [String: APIRecord] = [
        "set_active_indicator": APIRecord(
            "Sets how the focused window's item is marked.",
            .choice(
                "indicator",
                AppBarStyle.ActiveIndicator.self
            )
        ),
        "set_content": APIRecord(
            "Sets what each item draws: the icon, the window "
                + "title, or both.",
            .choice("content", AppBarStyle.Content.self)
        ),
        "set_title_cap": APIRecord(
            "Sets how many characters of a window title an item "
                + "shows, longer ones ending in an ellipsis.",
            .integer("characters")
        ),
        "set_group_adjacent_windows": APIRecord(
            "Collapses adjacent same-app windows into one item "
                + "with a count badge.",
            .boolean("enabled")
        ),
    ]
}
