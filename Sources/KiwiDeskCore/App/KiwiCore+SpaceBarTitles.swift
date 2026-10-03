import Foundation

extension KiwiCore {
    /// Expansion follows the Space shown on each display, rather
    /// than only the display carrying system focus (#1214).
    func expandsSpaceTitles(in space: Space, style: SpaceBarLook) -> Bool {
        style.expandActiveSpace && style.edge.isHorizontal
            && spaceBarSpaceIsShown(space)
    }

    private func spaceBarSpaceIsShown(_ space: Space) -> Bool {
        guard
            let display = state.workspaces.display(of: space.id)
        else { return false }
        return state.workspaces.currentSpace(on: display) == space.id
    }

    func inlineSpaceBarApp(
        _ app: SpaceBarItemView.App,
        space: Space,
        style: SpaceBarLook,
        expanded: Bool
    ) -> SpaceBarItemView.App {
        let hovered = spaceBars.titleHoveredWindow(in: space.id)
        guard style.edge.isHorizontal,
            expanded
                || (style.showHoverTitles && !spaceBarSpaceIsShown(space)
                    && hovered.map(app.windows.contains) == true)
        else { return app }
        var app = app
        let title =
            app.count == 1
            ? app.windows.first.flatMap { state.windows[$0]?.title } : nil
        app.inlineTitle = AppBarStyle.cappedTitle(
            title.flatMap { $0.isEmpty ? nil : $0 } ?? app.name,
            to: 24
        )
        return app
    }
}
