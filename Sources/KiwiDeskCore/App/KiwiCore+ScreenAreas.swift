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
    }

    /// The area an arriving window sits in, off the one arrival
    /// frame door (#3052); nil unless a screen is split.
    func arrivalArea(of window: ManagedWindow) -> PlacementID? {
        areaPlacement(holding: arrivalFrame(of: window))
    }
    /// `space`'s area — its rect in its screen's own points — and
    /// stored key, nil where its screen is not split.
    func splitArea(of space: SpaceID) -> (rect: CGRect, key: String)? {
        guard let id = state.workspaces.placement(of: space),
            state.workspaces.placements(of: id.display).count > 1,
            let placement = state.workspaces[placement: id]
        else { return nil }
        return (placement.area.rect, placement.key.description)
    }

    /// The AX frames of every area of every split screen.
    func splitAreaBounds() -> [CGRect] {
        state.workspaces.allDisplays.flatMap { display -> [CGRect] in
            let areas = state.workspaces.placements(of: display.id)
            guard areas.count > 1,
                let screen = TilingEngine.screen(for: display.id)
            else { return [] }
            return areas.map { tiler.areaFrame($0.area.rect, on: screen) }
        }
    }

    /// The area of a split screen an AX `frame` sits in — the one
    /// holding its centre — nil on an unsplit screen (#3517 ruling
    /// 5). Resolves the physical screen first, as `screen(containing:)`
    /// does, so a frame never lands in another screen's area.
    /// The frame is read only while a screen is split.
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
        let areas = state.workspaces.placements(of: display)
        guard areas.count > 1 else { return nil }
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        return areas.first {
            tiler.areaFrame($0.area.rect, on: screen).contains(centre)
        }?.id
    }

    /// Every placement's AX frame for the screen hop (#3517 ruling
    /// 18): an unsplit screen's visible frame as `displayFrames`
    /// reports it, a split screen's areas clipped to it. A screen
    /// with no placement record (a fixture) takes its Spaces' own.
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
                (
                    area.id,
                    frame.intersection(
                        tiler.areaFrame(area.area.rect, on: screen)
                    )
                )
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
    /// number names a physical screen, as Desktop bindings count
    /// them, and lands in its focused area, else its first; then a
    /// fingerprint or area key; then a screen's name, its first
    /// area; then an area's own name, refused where two share it.
    func resolveAreaArg(_ arg: JSONValue?) -> PlacementID? {
        let ws = state.workspaces
        func lead(_ display: DisplayID) -> PlacementID? {
            if let here = focusedPlacement, here.display == display {
                return here
            }
            return ws.placements(of: display).first?.id
        }
        if arg?.intValue != nil {
            return resolveDisplayArg(arg).flatMap(lead)
        }
        guard let raw = arg?.stringValue else { return nil }
        let key = ScreenAreaKey(parsing: raw)
        if let screen = ws.allDisplays.first(where: {
            $0.fingerprint == key.fingerprint
        }) {
            return ws.placements(of: screen.id).first { $0.key == key }?.id
        }
        if let screen = resolveDisplayArg(arg) { return lead(screen) }
        let named = ws.allPlacements.filter { $0.area.name == raw }
        return named.count == 1 ? named[0].id : nil
    }
}
