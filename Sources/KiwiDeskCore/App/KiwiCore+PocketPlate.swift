import AppKit

/// Drives the pocket plate (#2678): under Several windows it stays on
/// the active Space's screen while two windows are inside, at the
/// pocket's edge and position, and a click lists them. It wears
/// KiwiShelf's look, so it is synced at the tail of every
/// `updateBars()` and stands down on that pass's verdict.
extension KiwiCore {
    /// Shows or hides the plate; `standingDown` is the bar pass's.
    func updatePocketPlate(standingDown: Set<DisplayID>) {
        let spec = pocketPlateSpec(standingDown: standingDown)
        if spec == nil, shelves.peek.shown?.view === pocketPlate.view {
            shelves.peek.dismiss()
        }
        pocketPlate.sync(spec)
    }

    /// What the plate draws, nil while it is not on screen.
    func pocketPlateSpec(
        standingDown: Set<DisplayID>
    ) -> PocketPlateOverlay.Spec? {
        let style = tiler.settings.pocketStyle
        let inside = state.pocketedWindows
        guard
            Self.pocketPlateShows(capacity: style.capacity, inside: inside),
            let space = state.workspaces.activeSpace,
            let display = state.workspaces.display(of: space),
            !standingDown.contains(display),
            let screen = TilingEngine.screen(for: display)
        else { return nil }
        let shelf = briefPocketShelf()
        let count = "\(inside.count)"
        let square = BriefPocketPlan.pocketFrame(
            in: pocketRegion(on: display, screen: screen),
            edge: style.edge,
            position: style.position
        )
        let frame = Self.pocketPlateFrame(
            square: square,
            extra: BriefPocketView.countWidth(count, shelf: shelf),
            edge: style.edge
        )
        return PocketPlateOverlay.Spec(
            frame: GeometryUtils.flip(
                frame,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            shelf: shelf,
            markHex: style.color,
            count: count,
            name: L(
                "pocket.plate.ax",
                "Pocket, windows inside: %1$d",
                inside.count
            )
        )
    }

    /// Whether the plate stays on screen: Several windows, and two
    /// windows inside.
    static func pocketPlateShows(
        capacity: PocketCapacity,
        inside: [WindowID]
    ) -> Bool {
        capacity == .several && inside.count >= 2
    }

    /// The plate's frame (AX): the pocket's `square` widened by
    /// `extra` for the count, away from a side edge it sits on.
    static func pocketPlateFrame(
        square: CGRect,
        extra: CGFloat,
        edge: AppBarEdge
    ) -> CGRect {
        var frame = square
        frame.size.width += extra
        switch edge {
        case .right: frame.origin.x -= extra
        case .left: break
        case .top, .bottom: frame.origin.x -= extra / 2
        }
        return frame
    }

    /// The plate's click and VoiceOver press, wired once at boot.
    func wirePocketPlate() {
        let view = pocketPlate.view
        view.onClick = { [weak self] in self?.openPocketList() }
        view.onPress = { [weak self] in self?.openPocketList() }
        pocketPlate.onPanelPress = { [weak self] hit, type in
            self?.shelves.peek.pressed(on: hit, type: type)
        }
    }

    /// Grows the list of the windows inside out of the plate.
    func openPocketList() {
        shelves.peek.show(
            pocketPlate.view,
            source: .pocket(state.pocketedWindows),
            space: nil,
            edge: tiler.settings.pocketStyle.edge
        )
    }
}
