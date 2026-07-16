import KiwiDeskCore

/// The shared App Bar option lists so the global editor and the
/// per-layout override pickers stay in sync — one source of the
/// value/label pairs both surfaces render (as segments now, #291).
/// Split out of `AppBarOverrideControls.swift` to keep that file
/// under the line ceiling.
enum AppBarOptions {
    @MainActor
    static let position: [(AppBarStyle.Position, String)] = [
        (.start, L("app_bar.position.start", "Start")),
        (.end, L("app_bar.position.end", "End")),
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
