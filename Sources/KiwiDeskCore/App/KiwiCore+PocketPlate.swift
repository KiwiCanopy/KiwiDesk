import AppKit

/// Drives the pocket on screen (#2678): while Several windows holds
/// it, one pocket on every display, at the slot its shelf pins at a
/// bar edge's outer end, faded while empty, a count badge from two
/// inside; during a window drag it shows as the drop target too. A
/// click lists the windows inside. It wears KiwiShelf's look, so it
/// is synced at the tail of every `updateBars()` and stands down on
/// that pass's verdict, which the overlay keeps.
extension KiwiCore {
    /// Whether the pocket stays on screen (#2678): Several windows.
    var pocketHoldsSeveral: Bool { appWide.pocketCapacity == .several }

    /// Takes the bar pass's pocket slots, then syncs.
    func updatePocketPlate(slots: [DisplayID: CGRect]) {
        pocketPlate.slots = slots
        updatePocketPlate()
    }

    /// Shows or hides each display's pocket. A list open on one
    /// closes when that pocket changes — what it lists, or where it
    /// stands.
    func updatePocketPlate() {
        let specs = pocketPlateSpecs()
        if let view = shelves.peek.shown?.view as? PocketPlateView,
            let display = pocketPlate.display(of: view),
            specs.first(where: { $0.display == display })
                != pocketPlate.specs[display]
        {
            shelves.peek.dismiss()
        }
        pocketPlate.sync(specs)
    }

    /// The windows the pocket counts, shows for and lists: those
    /// inside that are tracked, so a hidden app's window, which no
    /// row can name, counts for nothing.
    var pocketPlateWindows: [WindowID] {
        state.pocketedWindows.filter { state.windows[$0] != nil }
    }

    /// What each display's pocket draws; empty while none is on
    /// screen.
    func pocketPlateSpecs() -> [PocketPlateOverlay.Spec] {
        let inside = pocketPlateWindows
        let dragging = pocketPlate.dragging != nil
        guard
            Self.pocketPlateShows(
                several: pocketHoldsSeveral,
                dragging: dragging
            )
        else { return [] }
        let shelf = briefPocketShelf()
        // The count shows from two up.
        let count = inside.count >= 2 ? "\(inside.count)" : ""
        let name = L(
            "pocket.plate.ax",
            "Pocket, windows inside: %1$d",
            inside.count
        )
        return state.workspaces.allDisplays.compactMap { display in
            guard !pocketPlate.standingDown.contains(display.id),
                let frame = pocketFrame(on: display.id)
            else { return nil }
            let edge = shelf.pocketEdge
            return PocketPlateOverlay.Spec(
                display: display.id,
                windows: inside,
                frame: GeometryUtils.flip(
                    frame,
                    primaryHeight: GeometryUtils.primaryHeight
                ),
                shelf: shelf,
                markHex: tiler.settings.pocketStyle.color,
                count: count,
                badgeLeading: edge == .right
                    || (edge.isHorizontal && shelf.pocketLeansEnd),
                platePiece: !shelf.plateSpans,
                faded: inside.isEmpty,
                dropHovered: pocketPlate.dropHovered,
                name: name
            )
        }
    }

    /// Where `display`'s pocket stands (AX): its shelf's pinned
    /// slot, else — an edge no bar draws on — the square at its
    /// position.
    func pocketFrame(on display: DisplayID) -> CGRect? {
        if let slot = pocketPlate.slots[display] { return slot }
        guard let screen = TilingEngine.screen(for: display) else {
            return nil
        }
        let shelf = tiler.settings.kiwishelf
        return BriefPocketPlan.pocketFrame(
            in: pocketRegion(on: display, screen: screen),
            edge: shelf.pocketEdge,
            position: shelf.pocketPosition
        )
    }

    /// Whether the pocket is on screen: always while Several windows
    /// holds it, and during a window drag as its drop target.
    static func pocketPlateShows(several: Bool, dragging: Bool) -> Bool {
        several || dragging
    }

    /// Whether a play on `display` draws its own pocket: not where
    /// a pocket stands, read from the state the play shows, since a
    /// take-out plays before its retile syncs the pocket.
    func briefPocketDrawsPocket(on display: DisplayID) -> Bool {
        !pocketPlateSpecs().contains { $0.display == display }
    }

    /// The pockets' click and VoiceOver press, wired once at boot.
    func wirePocketPlate() {
        pocketPlate.onClick = { [weak self] view in
            self?.openPocketList(from: view)
        }
        pocketPlate.onPanelPress = { [weak self] hit, type in
            self?.shelves.peek.pressed(on: hit, type: type)
        }
    }

    /// Grows the list of the windows inside out of `view`.
    func openPocketList(from view: PocketPlateView) {
        shelves.peek.show(
            view,
            source: .pocket(pocketPlateWindows),
            space: nil,
            edge: tiler.settings.kiwishelf.pocketEdge
        )
    }
}
