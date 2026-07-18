import KiwiDeskCore

/// The shared App Bar option lists so the global editor and the
/// per-layout override pickers stay in sync — one source of the
/// value/label pairs both surfaces render (as segments now, #291).
/// Split out of `AppBarOverrideControls.swift` to keep that file
/// under the line ceiling.
enum AppBarOptions {
    @MainActor
    static let edge: [(AppBarEdge, String)] = [
        (.top, L("app_bar.edge.top", "Top")),
        (.bottom, L("app_bar.edge.bottom", "Bottom")),
        (.left, L("app_bar.edge.left", "Left")),
        (.right, L("app_bar.edge.right", "Right")),
    ]
    @MainActor
    static let tabBackground: [(AppBarStyle.TabBackground, String)] = [
        (.boxed, L("app_bar.tab_background.boxed", "Boxed")),
        (.plain, L("app_bar.tab_background.plain", "Plain")),
    ]
    @MainActor
    static let activeIndicator: [(AppBarStyle.ActiveIndicator, String)] = [
        (.ring, L("app_bar.active_indicator.ring", "Ring")),
        (
            .edgeMark,
            L(
                "app_bar.active_indicator.edge_mark",
                "Edge mark"
            )
        ),
        (.gap, L("app_bar.active_indicator.gap", "Gap")),
    ]
    /// #294 icon rendering. "System default" = the icon as
    /// macOS hands it out (the system-wide Icon & widget
    /// style already covers tinting wants); styled variants
    /// are not obtainable via public API (#362).
    @MainActor
    static let iconSource: [(BarAppIconSource, String)] = [
        (
            .appImage,
            L("app_bar.icon_source.app_image", "System default")
        ),
        (
            .appFont,
            L("app_bar.icon_source.app_font", "Glyphs")
        ),
    ]
    @MainActor
    static let content: [(AppBarStyle.Content, String)] = [
        (.icon, L("app_bar.content.icon", "Icon")),
        (.name, L("app_bar.content.name", "Name")),
        (
            .iconAndName,
            L("app_bar.content.icon_and_name", "Icon & name")
        ),
    ]
}
