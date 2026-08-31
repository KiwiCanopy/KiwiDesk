import KiwiDeskCore

/// Incoming window slot resolution for layout schematics
/// (`Space.insert(_:placement:)`, `Space.insertIntoTrack`, #702,
/// `LayoutSchematicPlacementTests`, `LayoutSchematicPlacementScanTests`,
/// `LayoutSchematicTrackEngineTests`).
enum SchematicPlacement {
    /// Simulates window insertion into `Space` to determine resulting indices
    /// for incoming and focused windows (#702).
    static func splice(
        _ placement: SpawnPlacement,
        count: Int,
        focus: Int
    ) -> (incoming: Int, focus: Int) {
        let established = (0..<max(0, count)).map {
            WindowID(UInt32($0))
        }
        assert(
            established.indices.contains(focus),
            "focus \(focus) outside \(count) established windows"
        )
        let incoming = WindowID(UInt32(max(0, count)))
        var space = Space(
            id: "schematic",
            windows: established,
            focused: established.indices.contains(focus)
                ? established[focus] : established.last
        )
        space.insert(incoming, placement: placement)
        let landed = space.windows.firstIndex(of: incoming) ?? 0
        let settled =
            space.focused.flatMap {
                space.windows.firstIndex(of: $0)
            } ?? landed
        return (landed, settled)
    }
}
