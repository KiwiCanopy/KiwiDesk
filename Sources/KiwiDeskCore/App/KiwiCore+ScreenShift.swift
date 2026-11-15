import CoreGraphics

/// The boxed-in screen offer's Core doors (#2756): the verdict
/// the Screens page and the Mac Checklist read, and the one write
/// the offer's yes makes. Core names the screens; the GUI words
/// them (core-boundaries.md).
extension KiwiCore {
    /// The live arrangement: every screen the tiler parks on,
    /// with its usable area from `TilingEngine.displayFrames`, so
    /// the verdict scores the corners the stash parks in.
    public func arrangedScreens() -> [ArrangedScreen] {
        let names = Dictionary(
            state.workspaces.allDisplays.map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        return tiler.displayFrames().compactMap { id, visible in
            guard let uuid = DisplayArrangement.uuid(of: id) else {
                return nil
            }
            return ArrangedScreen(
                id: uuid,
                name: names[id] ?? uuid,
                frame: DisplayArrangement.bounds(of: id),
                visible: visible,
                isMain: DisplayArrangement.isMain(id)
            )
        }
    }

    /// The arrangement's one offer; nil while no screen is boxed
    /// in.
    public func screenOffer() -> ScreenOffer? {
        ScreenShiftPlan.offer(arrangedScreens())
    }

    /// Applies the offer's moves after the user's yes, in one
    /// configuration; false when a screen is gone or the
    /// arrangement did not land. The retile follows macOS's own
    /// screen-change notice.
    @discardableResult
    public func applyScreenShifts(_ shifts: [ScreenShift]) -> Bool {
        let ids = tiler.displayFrames().map(\.id)
        var moves: [DisplayID: CGVector] = [:]
        for shift in shifts {
            guard
                let display = ids.first(where: {
                    DisplayArrangement.uuid(of: $0) == shift.screen
                })
            else { return false }
            moves[display] = shift.delta
        }
        let landed = DisplayArrangement.shift(moves, among: ids)
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
