import Foundation

/// `focus_display_last` and `focus_display <direction>` (#2512):
/// focus moves to another screen's shown Space through the one
/// `switchSpace`, which hands the pointer over (#2548) and files
/// the arrival in the Space history; neither changes which Space a
/// screen shows.
extension KiwiCore {
    /// The area the focus was in before this one — a screen's one
    /// area where it is not split (#3517): the newest visit to a
    /// laid-out area other than this one, or — with exactly two
    /// areas and nothing recorded — the other one.
    func lastScreen() -> PlacementID? {
        guard let here = focusedPlacement else { return nil }
        let live = state.workspaces.allPlacements.map(\.id)
        if let visited = spaceHistory.areas.first(where: {
            $0 != here && live.contains($0)
        }) {
            return visited
        }
        let others = live.filter { $0 != here }
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
        guard let target = screenAhead(direction) else {
            bumpAtScreenEdge(direction)
            return .fail("no screen \(raw) of focus")
        }
        return focusScreen(target)
    }

    /// The nearest screen or area `direction` of the focused one,
    /// the one answer every screen verb's direction form takes
    /// (#3117, #3517).
    func screenAhead(_ direction: Direction) -> PlacementID? {
        let screens = placementFrames()
        guard let here = focusedPlacement,
            let frame = screens.first(where: { $0.id == here })?.frame
        else { return nil }
        return ScreenHop.ahead(
            of: frame,
            in: direction,
            band: frame,
            among: screens.filter { $0.id != here }
        ).first
    }

    /// Switches to the Space an area shows (#3517).
    private func focusScreen(_ area: PlacementID) -> CommandResponse {
        guard let shown = state.workspaces.activeSpace(on: area) else {
            return .fail("no Space on that screen")
        }
        switchSpace(to: shown, warp: true)
        return .ok()
    }

    /// The dead-end bump on the focused window (#436); an empty
    /// Space has no ring and says nothing.
    func bumpAtScreenEdge(_ direction: Direction) {
        guard let space = activeSpace,
            let focused = state.focusAnchor(of: space)
        else { return }
        flashDeadEnd(focused, direction: direction)
    }
}
