import Foundation

/// Which Space each placement shows (#3517): split from
/// `WorkspaceManager.swift` at the §2.1 ceiling.
extension WorkspaceManager {
    /// Shows `id` on `placement`; refuses a space that does not
    /// live there, as `show(_:on:)` above.
    public mutating func show(_ id: SpaceID, on placement: PlacementID) {
        ensureSpace(id)
        guard spacePlacement[id] == placement else { return }
        if activeSpace.flatMap({ spacePlacement[$0] }) == placement {
            activate(id)
            return
        }
        secondaryShown[placement] = id
    }

    /// The space a physical screen shows: the active space where it
    /// lives on that screen, else area 0's — the area a bare screen
    /// reference names. On an unsplit screen, its one area's.
    public func activeSpace(on display: DisplayID) -> SpaceID? {
        if let active = activeSpace,
            spacePlacement[active]?.display == display
        {
            return active
        }
        // A screen never upserted (a fixture) has no placement
        // record; its Spaces' own placement stands in.
        let placed = order.lazy.compactMap { self.spacePlacement[$0] }
        guard
            let lead = leadPlacement(of: display)
                ?? placed.first(where: { $0.display == display })
        else { return nil }
        return activeSpace(on: lead)
    }

    /// The space a placement shows.
    public func activeSpace(on placement: PlacementID) -> SpaceID? {
        if let active = activeSpace, spacePlacement[active] == placement {
            return active
        }
        // Self-healing: a pick counts only while that space still
        // lives on THIS placement — a stale entry would lay one
        // space in two places, so it is ignored rather than
        // honored.
        if let shown = secondaryShown[placement],
            spacePlacement[shown] == placement
        {
            return shown
        }
        return spaces(on: placement).first
    }

    /// All spaces currently visible across placements.
    public var visibleSpaces: Set<SpaceID> {
        var result: Set<SpaceID> = []
        if let active = activeSpace { result.insert(active) }
        for placement in placements.keys {
            if let shown = activeSpace(on: placement) {
                result.insert(shown)
            }
        }
        for display in displays.keys {
            if let shown = activeSpace(on: display) {
                result.insert(shown)
            }
        }
        return result
    }
}
