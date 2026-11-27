import CoreGraphics
import Foundation

/// The placement list's answers to the layout engine (#3517): the
/// area a Space lays out in and every split screen's areas for the
/// neighbour scan.
extension KiwiCore {
    /// A split screen's areas reach layout through these two hooks
    /// alone; an unsplit screen answers nil. Bootstrap-time.
    func wireScreenAreas() {
        tiler.spaceArea = { [weak self] space in
            self?.splitArea(of: space)
        }
        tiler.splitAreaBounds = { [weak self] in
            self?.splitAreaBounds() ?? []
        }
        tiler.onAreaSplits = { [weak self] old in
            self?.syncAreaSplits(from: old)
        }
    }

    /// The one door from the stored shares to the placement list
    /// (#3517, #3647 ▸ lane 3): each screen takes the split of the
    /// number `liveScreenOrder` gives it, resolved on its own size.
    /// Run by every write of `display_areas` through
    /// `tiler.onAreaSplits`, handed the shares before the write so
    /// a merge's Spaces follow it, and by the total resolve, which
    /// runs wherever the order can change, with nothing to follow.
    func syncAreaSplits(from old: [String: ScreenShares]? = nil) {
        let order = liveScreenOrder
        let shares = tiler.settings.displayAreas
        let remaps = (old.map { Self.areaRemaps(from: $0, to: shares) } ?? [])
            .compactMap { $0.runtime(in: order) }
        // The live Desktop memory follows a merge (ruling 22).
        if let old { remapAreaSpaces(from: old, to: shares) }
        let workspaces = state.workspaces
        let before = workspaces.allSpaces.compactMap { space in
            workspaces.placement(of: space.id)
                .flatMap { workspaces[placement: $0] }
                .map { (space.id, $0.key) }
        }
        state.workspaces.setAreaSplits(shares.splits(order: order))
        // A merged-away area's Spaces go to the survivor the
        // memory and the pins take, never area 0 by default.
        for (space, key) in before {
            guard let remap = remaps.first(where: { $0.vanished == key }),
                let display = state.workspaces.display(of: space),
                let survivor = state.workspaces.placement(
                    keyed: remap.survivor,
                    on: display
                )
            else { continue }
            state.workspaces.assign(space, to: survivor)
        }
    }

    /// `space`'s area — its rect in its screen's own points — its
    /// stored key and whether it leads its screen, nil where its
    /// screen is not split.
    func splitArea(
        of space: SpaceID
    ) -> (rect: CGRect, key: String, lead: Bool)? {
        guard let id = state.workspaces.placement(of: space),
            state.workspaces.placements(of: id.display).count > 1,
            let placement = state.workspaces[placement: id]
        else { return nil }
        return (
            placement.area.rect,
            placement.key.description,
            id == state.workspaces.leadPlacement(of: id.display)
        )
    }

    /// The AX frames of every area of every split screen, each
    /// clipped to its screen's visible frame.
    func splitAreaBounds() -> [CGRect] {
        state.workspaces.allDisplays.flatMap { display -> [CGRect] in
            let areas = state.workspaces.placements(of: display.id)
            guard areas.count > 1,
                let screen = TilingEngine.screen(for: display.id)
            else { return [] }
            return areas.map { tiler.areaFrame($0.area.rect, on: screen) }
        }
    }

    /// The area of a split screen an AX `frame` mostly covers, by
    /// the rule `TilingEngine.screen(containing:)` takes, nil on an
    /// unsplit screen (#3517 ruling 5). The physical screen is
    /// resolved first, so a frame never lands in another screen's
    /// area. The frame is read only while a screen is split.
    func areaPlacement(
        holding read: @autoclosure () -> CGRect
    ) -> PlacementID? {
        guard
            state.workspaces.allDisplays.contains(where: {
                state.workspaces.placements(of: $0.id).count > 1
            })
        else { return nil }
        let frame = read()
        guard let screen = TilingEngine.screen(containing: frame),
            let display = screen.kiwiDisplayID
        else { return nil }
        let areas = state.workspaces.placements(of: display).map {
            ($0.id, tiler.areaFrame($0.area.rect, on: screen))
        }
        guard areas.count > 1,
            let rect = GeometryUtils.rect(
                mostlyContaining: frame,
                among: areas.map(\.1)
            )
        else { return nil }
        return areas.first { $0.1 == rect }?.0
    }

    /// Every placement's AX frame for the screen hop (#3517 ruling
    /// 18): an unsplit screen's visible frame as `displayFrames`
    /// reports it, a split screen's areas through `areaFrame`. A
    /// screen with no placement record (a fixture) takes its
    /// Spaces' own.
    func placementFrames() -> [(id: PlacementID, frame: CGRect)] {
        tiler.displayFrames().flatMap { display, frame in
            let areas = state.workspaces.placements(of: display)
            guard areas.count > 1,
                let screen = TilingEngine.screen(for: display)
            else {
                let id =
                    areas.first?.id
                    ?? state.workspaces.allSpaces.lazy
                    .compactMap { self.state.workspaces.placement(of: $0.id) }
                    .first { $0.display == display }
                return id.map { [($0, frame)] } ?? []
            }
            return areas.map { area in
                (area.id, tiler.areaFrame(area.area.rect, on: screen))
            }
        }
    }

    /// The placement the focused Space shows in.
    var focusedPlacement: PlacementID? {
        state.workspaces.activeSpace.flatMap {
            state.workspaces.placement(of: $0)
        }
    }

    /// A screen-or-area argument (#3517 ruling 16), in order: a
    /// number names Screen N (#3647) and lands in its area 0; then
    /// a fingerprint or area key, area 0 where the area is gone;
    /// then `N#id`, Screen N's area; then a screen's name, its
    /// area 0; then an area's own name, refused where two share
    /// it.
    func resolveAreaArg(_ arg: JSONValue?) -> PlacementID? {
        let ws = state.workspaces
        if arg?.intValue != nil {
            return resolveDisplayArg(arg).flatMap(ws.leadPlacement)
        }
        guard let raw = arg?.stringValue else { return nil }
        let key = ScreenAreaKey(parsing: raw)
        if let screen = ws.allDisplays.first(where: {
            $0.fingerprint == key.fingerprint
        }) {
            return ws.placement(keyed: key, on: screen.id)
        }
        if let (screen, key) = numberedArea(raw) {
            return ws.placement(keyed: key, on: screen.id)
        }
        if let screen = resolveDisplayArg(arg) {
            return ws.leadPlacement(of: screen)
        }
        let named = ws.allPlacements.filter { $0.area.name == raw }
        return named.count == 1 ? named[0].id : nil
    }

    /// `N#id`: Screen N's area `id` (#3647), the screen it names and
    /// its runtime key; nil for any other string or a number no
    /// connected screen holds.
    func numberedArea(_ raw: String) -> (Display, ScreenAreaKey)? {
        guard let slot = ScreenSlotKey(parsing: raw), slot.areaID > 0
        else { return nil }
        guard let screen = screen(numbered: slot.number) else {
            return nil
        }
        return (
            screen,
            ScreenAreaKey(fingerprint: screen.fingerprint, areaID: slot.areaID)
        )
    }
}

/// The one store door for a split (#3517), shared by
/// `set_display_areas` and the load's reset (#3573).
extension KiwiCore {
    /// Stores `shares` as Screen `number`'s split. A merged-away
    /// area's keys move to the survivor in the same write as the
    /// split, as a Settings merge's do (ruling 22).
    func storeShares(_ shares: ScreenShares, number: Int) {
        let key = String(number)
        let previous = tiler.settings.displayAreas[key]
        var settings = tiler.settings
        let remaps =
            previous.map {
                Self.areaRemaps(from: [key: $0], to: [key: shares])
            } ?? []
        let order = liveScreenOrder
        for remap in remaps {
            guard let runtime = remap.runtime(in: order) else { continue }
            settings.apply(runtime)
            for (space, pin) in spacePins {
                spacePins[space] = runtime.rewrite(pin)
            }
        }
        // A whole split stays stored once one existed, so its next id
        // outlives the merge and a later split mints none reused
        // (ruling 21).
        settings.displayAreas[key] =
            shares.isWhole && previous == nil ? nil : shares
        tiler.settings = settings
    }

    /// The screen a split names: a connected screen by number,
    /// fingerprint or name, with the number it holds now.
    func splitScreen(
        _ arg: JSONValue?
    ) -> (fingerprint: String, width: Int, height: Int)? {
        guard let id = resolveDisplayArg(arg),
            let display = state.workspaces.allDisplays.first(where: {
                $0.id == id
            })
        else { return nil }
        return (
            display.fingerprint,
            Int(display.frame.width),
            Int(display.frame.height)
        )
    }
}
