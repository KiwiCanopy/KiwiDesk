import Foundation

/// Display bookkeeping — which display a space is assigned to
/// and what each display shows. Split from `WorkspaceManager`
/// for the file ceiling (§2.1); the backing maps (`order`,
/// `displays`, `spaceDisplay`, `secondaryShown`) stay declared
/// there and are internal for exactly this file's sake.
extension WorkspaceManager {
    public var allDisplays: [Display] {
        Array(displays.values)
    }

    public mutating func upsertDisplay(_ display: Display) {
        displays[display.id] = display
    }

    @discardableResult
    public mutating func removeDisplay(
        _ id: DisplayID
    ) -> Display? {
        for (space, display) in spaceDisplay where display == id {
            spaceDisplay[space] = nil
        }
        secondaryShown[id] = nil
        return displays.removeValue(forKey: id)
    }

    public mutating func assign(
        _ space: SpaceID,
        to display: DisplayID
    ) {
        ensureSpace(space)
        spaceDisplay[space] = display
        // Reassigning a space can strand a `secondaryShown` entry
        // that still points at it on its OLD display; drop any
        // entry no longer matching its display so stale picks
        // never accumulate (the read path also ignores them).
        secondaryShown = secondaryShown.filter { display, space in
            spaceDisplay[space] == display
        }
    }

    public func display(of space: SpaceID) -> DisplayID? {
        spaceDisplay[space]
    }

    /// Spaces assigned to one display, in creation order.
    public func spaces(on display: DisplayID) -> [SpaceID] {
        order.filter { spaceDisplay[$0] == display }
    }

    /// The space a display currently shows. Alias of
    /// `activeSpace(on:)`; kept for the bar/overlay call sites
    /// that predate the per-display active model.
    public func currentSpace(on display: DisplayID) -> SpaceID? {
        activeSpace(on: display)
    }
}
