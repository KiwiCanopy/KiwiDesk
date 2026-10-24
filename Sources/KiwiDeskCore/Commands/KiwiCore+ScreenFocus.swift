import Foundation

/// `focus_display_last` and `focus_display <direction>` (#2512):
/// focus moves to another screen's shown Space through the one
/// `switchSpace`, which hands the pointer over (#2548) and files
/// the arrival in the Space history; neither changes which Space a
/// screen shows.
extension KiwiCore {
    /// The screen the focus was on before this one: the newest
    /// visit to a connected screen other than this one, or — with
    /// exactly two screens and nothing recorded — the other one.
    func lastScreen() -> DisplayID? {
        guard let here = focusedScreen else { return nil }
        let connected = state.workspaces.allDisplays.map(\.id)
        if let visited = spaceHistory.screens.first(where: {
            $0 != here && connected.contains($0)
        }) {
            return visited
        }
        let others = connected.filter { $0 != here }
        return others.count == 1 ? others.first : nil
    }

    /// `focus_display_last`: like ⌘Tab for screens. With one screen,
    /// or nothing recorded among three or more, the wordless dead-end
    /// bump — toward the right, as at a row's end — and a failure.
    func focusDisplayLast() -> CommandResponse {
        noteSpaceVisits()
        guard let target = lastScreen() else {
            bumpAtScreenEdge(.right)
            return .fail("no other screen")
        }
        return focusScreen(target)
    }

    /// `focus_display <direction>`: the nearest screen that way by
    /// geometry, a diagonal one counting only where it overlaps on
    /// the cross axis (`ScreenHop.ahead`); stops at the edge.
    func focusDisplay(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = Direction(rawValue: raw)
        else { return .expected(Direction.self) }
        let screens = tiler.displayFrames()
        guard let here = focusedScreen,
            let frame = screens.first(where: { $0.id == here })?.frame,
            let target = ScreenHop.ahead(
                of: frame,
                in: direction,
                band: frame,
                among: screens.filter { $0.id != here }
            ).first
        else {
            bumpAtScreenEdge(direction)
            return .fail("no screen \(raw) of focus")
        }
        return focusScreen(target)
    }

    /// Switches to the Space `display` shows. An empty one still
    /// takes the focused screen there, so the next press acts from
    /// it.
    private func focusScreen(_ display: DisplayID) -> CommandResponse {
        guard let shown = state.workspaces.activeSpace(on: display) else {
            return .fail("no Space on that screen")
        }
        switchSpace(to: shown, warp: true)
        return .ok()
    }

    /// The dead-end bump on the focused window (#436); an empty
    /// Space has no ring and says nothing.
    private func bumpAtScreenEdge(_ direction: Direction) {
        guard let space = activeSpace,
            let focused = state.focusAnchor(of: space)
        else { return }
        flashDeadEnd(focused, direction: direction)
    }
}
