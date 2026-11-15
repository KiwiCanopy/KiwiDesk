import CoreGraphics

/// The boxed-in screen offer's Core doors (#2756): the arrangement
/// the Screens page and the Mac Checklist plan over, and the one
/// write the offer's yes makes. Both go through `TilingEngine`'s
/// arrangement seams. Core names the screens; the GUI words them
/// (core-boundaries.md).
extension KiwiCore {
    /// The live arrangement: every screen the tiler parks on, with
    /// its usable area from `TilingEngine.displayFrames`, so the
    /// plan scores the corners the stash parks in. Empty when any
    /// screen cannot be read or named, so no plan moves screens
    /// around one it cannot see.
    public func arrangedScreens() -> [ArrangedScreen] {
        let frames = tiler.displayFrames()
        let names = Dictionary(
            state.workspaces.allDisplays.map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        guard let readings = tiler.readArrangement(frames.map(\.id))
        else { return [] }
        var screens: [ArrangedScreen] = []
        for (id, visible) in frames {
            guard
                let reading = readings.first(where: { $0.id == id }),
                let name = names[id]
            else { return [] }
            screens.append(
                ArrangedScreen(
                    id: reading.uuid,
                    name: name,
                    frame: reading.bounds,
                    visible: visible,
                    isMain: reading.isMain,
                    display: id
                )
            )
        }
        return screens
    }

    /// Applies the offer's moves after the user's yes, in one
    /// configuration; false when a screen is gone or the
    /// arrangement did not land. The retile follows macOS's own
    /// screen-change notice.
    @discardableResult
    public func applyScreenShifts(_ shifts: [ScreenShift]) -> Bool {
        let ids = tiler.displayFrames().map(\.id)
        guard let readings = tiler.readArrangement(ids) else {
            return false
        }
        var moves: [DisplayID: CGVector] = [:]
        for shift in shifts {
            guard
                let reading = readings.first(where: {
                    $0.uuid == shift.screen
                })
            else { return false }
            moves[reading.id] = shift.delta
        }
        let landed = tiler.writeArrangement(
            DisplayArrangement.targets(moves: moves, in: readings)
        )
        let words = shifts.map {
            "\($0.screen) (\(Int($0.delta.dx)), \(Int($0.delta.dy)))"
        }
        onLog(
            "screen shift: \(words.joined(separator: ", "))"
                + (landed ? "" : " did not land")
        )
        return landed
    }
}
