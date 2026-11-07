import Foundation

/// What a display's App Bar draws, built before the shelf places
/// it (#1517), for the bar refresh and the show/hide refusal alike.
extension KiwiCore {
    /// What one display's App Bar would draw, before the shelf
    /// places it.
    struct AppBarContent {
        let space: Space
        let style: AppBarLook
        let groups: [[WindowID]]
        /// The groups' items, then each float's (#1826).
        let items: [AppBarOverlay.Item]

        /// Every window the bar draws: each group's windows, then
        /// one per float item — the hidden mark's count (#2567).
        var windowCount: Int {
            groups.reduce(0) { $0 + $1.count } + items.count - groups.count
        }
    }

    /// The App Bar content for the space shown on `display`, or
    /// nil when that space hosts no non-empty bar.
    func appBarContent(
        on display: DisplayID,
        settings: TilingSettings
    ) -> AppBarContent? {
        guard
            let id = state.workspaces.currentSpace(on: display),
            let space = state.workspaces[id]
        else { return nil }
        return appBarContent(space: space, settings: settings)
    }

    /// The App Bar content for `space`, or nil when its layout hosts
    /// no bar or it has no items — built whatever the bar's
    /// visibility, since a hidden bar's shortcut may show it (#761).
    func appBarContent(
        space: Space,
        settings: TilingSettings
    ) -> AppBarContent? {
        guard let host = barHost(for: space) else { return nil }
        let style = host.resolvedBar(
            global: settings.appBarGlobalLook
        )
        let groups = barGroups(
            in: space,
            grouping: style.groupAdjacentWindows
        )
        let floats = appBarFloats(in: space)
        guard !groups.isEmpty || !floats.isEmpty else { return nil }
        let seen = appBarVisibility(of: space, floats: floats)
        // A group takes its first member's: the window its click
        // focuses (#2234).
        let items =
            groups.map {
                barItem(for: $0, style: style, visibility: seen)
            }
            + floats.map {
                barItem(
                    for: [$0],
                    style: style,
                    floating: true,
                    visibility: seen
                )
            }
        return AppBarContent(
            space: space,
            style: style,
            groups: groups,
            items: items
        )
    }
}
