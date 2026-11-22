import CoreGraphics
import Foundation

/// Display tracking and space assignment for WorkspaceManager.
extension WorkspaceManager {
    /// The physical screens (#3517 ruling 10).
    public var allDisplays: [Display] {
        Array(displays.values)
    }

    public mutating func upsertDisplay(_ display: Display) {
        displays[display.id] = display
        rebuildPlacements(of: display.id)
    }

    @discardableResult
    public mutating func removeDisplay(
        _ id: DisplayID
    ) -> Display? {
        for (space, placement) in spacePlacement
        where placement.display == id {
            spacePlacement[space] = nil
        }
        secondaryShown = secondaryShown.filter { $0.key.display != id }
        placements = placements.filter { $0.key.display != id }
        return displays.removeValue(forKey: id)
    }

    /// Places `space` on `display`'s area 0 — the whole
    /// screen when it is not split.
    public mutating func assign(
        _ space: SpaceID,
        to display: DisplayID
    ) {
        assign(
            space,
            to: leadPlacement(of: display)
                ?? PlacementID(display: display, area: 0)
        )
    }

    public mutating func assign(
        _ space: SpaceID,
        to placement: PlacementID
    ) {
        // Placing a Space is not asking for it: only a missing one
        // enters the `referenced` ledger (#1526, #1509).
        if self[space] == nil { ensureSpace(space) }
        spacePlacement[space] = placement
        // Reassigning a space can strand a `secondaryShown` entry
        // that still points at it on its OLD placement; drop any
        // entry no longer matching its placement so stale picks
        // never accumulate (the read path also ignores them).
        secondaryShown = secondaryShown.filter { placement, space in
            spacePlacement[space] == placement
        }
    }

    /// The physical screen `space` lays out on.
    public func display(of space: SpaceID) -> DisplayID? {
        spacePlacement[space]?.display
    }

    /// The area `space` lays out in.
    public func placement(of space: SpaceID) -> PlacementID? {
        spacePlacement[space]
    }

    /// Spaces on any area of one physical screen, in creation order.
    public func spaces(on display: DisplayID) -> [SpaceID] {
        order.filter { spacePlacement[$0]?.display == display }
    }

    /// Spaces placed in one area, in creation order.
    public func spaces(on placement: PlacementID) -> [SpaceID] {
        order.filter { spacePlacement[$0] == placement }
    }

    /// The space a display currently shows. Alias of
    /// `activeSpace(on:)`; kept for the bar/overlay call sites
    /// that predate the per-display active model.
    public func currentSpace(on display: DisplayID) -> SpaceID? {
        activeSpace(on: display)
    }

    /// Every placement target, screens in id order and each
    /// screen's areas in reading order.
    public var allPlacements: [Placement] {
        displays.keys.sorted { $0.raw < $1.raw }
            .flatMap { placements(of: $0) }
    }

    /// One physical screen's areas, in reading order.
    public func placements(of display: DisplayID) -> [Placement] {
        placements.values.filter { $0.display == display }
            .sorted { ($0.area.y, $0.area.x) < ($1.area.y, $1.area.x) }
    }

    public subscript(placement id: PlacementID) -> Placement? {
        placements[id]
    }

    /// The placement a stored area `key` names on `display`, else
    /// that screen's area 0 — a key naming an area the split no
    /// longer has falls back there (ruling 22). Nil only for a
    /// screen with no placement record.
    public func placement(
        keyed key: ScreenAreaKey,
        on display: DisplayID
    ) -> PlacementID? {
        guard key.fingerprint == displays[display]?.fingerprint else {
            return leadPlacement(of: display)
        }
        let areas = placements(of: display)
        // The one fallback rule, which Settings' picture reads too.
        let landing = ScreenSplit(areas: areas.map(\.area)).landing(key)
        return areas.first { $0.area.id == landing }?.id
    }

    /// `display`'s area 0, the area a bare screen reference names.
    public func leadPlacement(of display: DisplayID) -> PlacementID? {
        placements(of: display).first { $0.area.id == 0 }?.id
    }

    /// Replaces every screen's split and rebuilds the placements.
    public mutating func setAreaSplits(_ splits: [String: ScreenSplit]) {
        guard splits != areaSplits else { return }
        areaSplits = splits
        for id in displays.keys { rebuildPlacements(of: id) }
    }

    /// The one writer of `placements` for `display`: its split when
    /// one is stored and tiles its frame, else one whole area. A
    /// space whose area is gone falls back to area 0 (ruling 22).
    mutating func rebuildPlacements(of id: DisplayID) {
        placements = placements.filter { $0.key.display != id }
        guard let display = displays[id] else { return }
        let width = Int(display.frame.width)
        let height = Int(display.frame.height)
        let areas =
            ScreenSplit.effective(
                areaSplits[display.fingerprint],
                width: width,
                height: height
            )?.areas
            ?? ScreenSplit.whole(width: width, height: height).areas
        for area in areas {
            let pid = PlacementID(display: id, area: area.id)
            placements[pid] = Placement(
                id: pid,
                area: area,
                key: ScreenAreaKey(
                    fingerprint: display.fingerprint,
                    areaID: area.id
                )
            )
        }
        let fallback = leadPlacement(of: id)
        for (space, placement) in spacePlacement
        where placement.display == id && placements[placement] == nil {
            spacePlacement[space] = fallback
        }
        secondaryShown = secondaryShown.filter { placement, space in
            placements[placement] != nil
                && spacePlacement[space] == placement
        }
    }
}
