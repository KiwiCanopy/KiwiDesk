import AppKit

/// Drives the pocket plate (#2678): it stays on the screen pocketed
/// windows wait on while two windows are inside, and shows on every
/// window drag as a drop target, at the pocket's edge and position;
/// a click lists the windows inside. It wears
/// KiwiShelf's look, so it is synced at the tail of every
/// `updateBars()` and stands down on that pass's verdict, which the
/// overlay keeps.
extension KiwiCore {
    /// Shows or hides the plate. A list open on it closes when the
    /// plate changes — what it lists, or where it stands.
    func updatePocketPlate() {
        let spec = pocketPlateSpec()
        if shelves.peek.shown?.view === pocketPlate.view,
            spec != pocketPlate.shown
        {
            shelves.peek.dismiss()
        }
        pocketPlate.sync(spec)
    }

    /// The windows the plate counts, shows for and lists: those
    /// inside that are tracked, so a hidden app's window, which no
    /// row can name, counts for nothing.
    var pocketPlateWindows: [WindowID] {
        state.pocketedWindows.filter { state.windows[$0] != nil }
    }

    /// What the plate draws, nil while it is not on screen.
    func pocketPlateSpec() -> PocketPlateOverlay.Spec? {
        let style = tiler.settings.pocketStyle
        let inside = pocketPlateWindows
        let dragging = pocketPlate.dragging != nil
        guard Self.pocketPlateShows(inside: inside, dragging: dragging),
            let display = pocketPlate.dragDisplay ?? state.pocketHomeDisplay,
            !pocketPlate.standingDown.contains(display),
            let screen = TilingEngine.screen(for: display)
        else { return nil }
        let shelf = briefPocketShelf()
        // The count shows from two up.
        let count = inside.count >= 2 ? "\(inside.count)" : ""
        let region = pocketRegion(on: display, screen: screen)
        let square = BriefPocketPlan.pocketFrame(
            in: region,
            edge: style.edge,
            position: style.position
        )
        let placed = Self.pocketPlateFrame(
            square: square,
            extra: count.isEmpty
                ? 0 : BriefPocketView.countWidth(count, shelf: shelf),
            region: region
        )
        return PocketPlateOverlay.Spec(
            display: display,
            windows: inside,
            frame: GeometryUtils.flip(
                placed.frame,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            shelf: shelf,
            markHex: style.color,
            count: count,
            markTrailing: placed.markTrailing,
            faded: inside.isEmpty,
            dropHovered: pocketPlate.dropHovered,
            name: L(
                "pocket.plate.ax",
                "Pocket, windows inside: %1$d",
                inside.count
            )
        )
    }

    /// Whether the plate is on screen: during a window drag, as its
    /// drop target, and otherwise while two windows are inside —
    /// which only Several windows lets in, and a switch back to One
    /// keeps, so each stays reachable.
    static func pocketPlateShows(
        inside: [WindowID],
        dragging: Bool
    ) -> Bool {
        dragging || inside.count >= 2
    }

    /// The plate's frame (AX): the pocket's `square`, where the
    /// brief pocket lands, widened by `extra` for the count —
    /// rightward, or leftward where that would leave `region`'s
    /// margin, the mark's square then trailing.
    static func pocketPlateFrame(
        square: CGRect,
        extra: CGFloat,
        region: CGRect
    ) -> (frame: CGRect, markTrailing: Bool) {
        var frame = square
        frame.size.width += extra
        let trailing =
            square.maxX + extra > region.maxX - BriefPocketPlan.margin
        if trailing { frame.origin.x -= extra }
        return (frame, trailing)
    }

    /// Whether a play on `display` draws its own pocket: not where
    /// the plate stands, read from the state the play shows, since a
    /// take-out plays before its retile syncs the plate.
    func briefPocketDrawsPocket(on display: DisplayID) -> Bool {
        pocketPlateSpec()?.display != display
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
            source: .pocket(pocketPlateWindows),
            space: nil,
            edge: tiler.settings.pocketStyle.edge
        )
    }
}
