import AppKit

/// Drives the pocket on screen (#2678): while Several windows holds
/// it, one pocket on every display, at the slot its shelf pins at a
/// bar edge's outer end or as a handle on an edge no bar shows, faded
/// while empty and unlit; during a window drag it shows as the drop
/// target too. A click lists the windows inside.
/// It wears KiwiShelf's look, so it is synced at the tail of every
/// `updateBars()` and stands down on that pass's verdict, which the
/// overlay keeps.
extension KiwiCore {
    /// Whether the pocket stays on screen (#2678): Several windows.
    var pocketHoldsSeveral: Bool { appWide.pocketCapacity == .several }

    /// Whether the pocket stands on `display` this pass: it stands,
    /// and that screen does not stand down — what the pocket draws
    /// and where a play lands both read (#2678 review 5).
    func pocketStands(on display: DisplayID) -> Bool {
        pocketStands && !pocketPlate.standingDown.contains(display)
    }

    /// Whether the pocket shows this pass; the shelf's plan reads the
    /// capacity alone, so a drag or a play moves no bar (#2793).
    var pocketStands: Bool {
        Self.pocketStands(
            several: pocketHoldsSeveral,
            dragging: pocketPlate.dragging != nil,
            playing: !pocketPlate.playing.isEmpty
        )
    }

    /// Takes the bar pass's pocket slots, then syncs.
    func updatePocketPlate(slots: [DisplayID: CGRect]) {
        pocketPlate.slots = slots
        updatePocketPlate()
    }

    /// Shows or hides each display's pocket. A list open on one
    /// closes when that pocket changes what it lists or where it
    /// stands — never for its hover, which the pointer leaves as it
    /// moves onto the list (#2678 review 1).
    func updatePocketPlate() {
        let specs = pocketPlateSpecs()
        if let display = pocketListDisplay,
            !Self.pocketListHolds(
                was: pocketPlate.specs[display],
                now: specs.first { $0.display == display }
            )
        {
            shelves.peek.dismiss()
        }
        pocketPlate.sync(specs)
    }

    /// The display whose pocket the peek lists, while it does.
    var pocketListDisplay: DisplayID? {
        (shelves.peek.shown?.view as? PocketPlateView)
            .flatMap(pocketPlate.display(of:))
    }

    /// Whether a list open on a pocket survives its pocket going
    /// from `was` to `now`: the same windows at the same place — a
    /// rise or a sink in place is the same place, since a list a
    /// VoiceOver press opened raises its handle.
    static func pocketListHolds(
        was: PocketPlateOverlay.Spec?,
        now: PocketPlateOverlay.Spec?
    ) -> Bool {
        guard let was, let now else { return false }
        return was.windows == now.windows && was.handle == now.handle
            && (was.frame == now.frame || was.risen != now.risen)
    }

    /// The windows the pocket counts, shows for and lists: the
    /// general list's inside that are tracked, so a hidden app's
    /// window, which no row can name, counts for nothing, and an
    /// app's own pocket window is its key's alone (#2612 ▸ 11).
    var pocketPlateWindows: [WindowID] {
        state.generalPocket.filter {
            $0.phase == .pocketed && state.windows[$0.window] != nil
        }.map(\.window)
    }

    /// What each display's pocket draws; empty while none is on
    /// screen.
    func pocketPlateSpecs() -> [PocketPlateOverlay.Spec] {
        let inside = pocketPlateWindows
        let dragging = pocketPlate.dragging != nil
        guard pocketStands else { return [] }
        let shelf = LiquidGlassGate.rendered(tiler.settings.kiwishelf)
        let name = L(
            "pocket.plate.ax",
            "Pocket, windows inside: %1$d",
            inside.count
        )
        let edge = shelf.pocketEdge
        let rise = Self.pocketRiseSide(thickness: shelf.thickness)
        // A list open on a risen pocket holds it out (#2678 review 1).
        let listed = pocketListDisplay
        return state.workspaces.allDisplays.compactMap {
            display -> PocketPlateOverlay.Spec? in
            guard pocketStands(on: display.id) else { return nil }
            let place = pocketPlace(on: display.id)
            // A handle's pocket rises out of it after a dwell or a push,
            // during a drag or a play, and while its list is open
            // (#2678); the pointer on it alone peeks its kiwis (#2807).
            let hovered = pocketPlate.hovered.contains(display.id)
            let risen =
                place == .handle
                && (dragging || pocketPlate.dwelled.contains(display.id)
                    || pocketPlate.playing[display.id] != nil
                    || listed == display.id)
            let peeking = place == .handle && hovered && !risen
            let found: CGRect? =
                switch place {
                case .section(let frame), .inside(let frame): frame
                case .whole: pocketMarkFrame(on: display.id)
                case .handle:
                    pocketHandleFrame(
                        on: display.id,
                        risen: risen,
                        peeking: peeking
                    )
                }
            guard let frame = found else { return nil }
            // A lit pocket shows full, empty or not (#2776).
            let lit = pocketPlate.dropHovered == display.id || hovered
            return PocketPlateOverlay.Spec(
                display: display.id,
                windows: inside,
                frame: GeometryUtils.flip(
                    frame,
                    primaryHeight: GeometryUtils.primaryHeight
                ),
                shelf: shelf,
                markHex: tiler.settings.pocketStyle.color,
                faded: inside.isEmpty && !lit,
                dropHovered: pocketPlate.dropHovered == display.id,
                name: name,
                // The whole mark stands on the edge it would hold a
                // handle on, with none drawn.
                handle: place.isSection ? nil : edge,
                risen: risen,
                peeking: peeking,
                risenSide: rise,
                // Inside the strip the mark stands at its frame's edge.
                outer: Self.pocketOuter(place, shelf: shelf),
                whole: !place.isSection && place != .handle,
                slides: place.slides
            )
        }
    }

    /// Whether the pocket is on screen: always while Several windows
    /// holds it; under One window during a window drag, as its drop
    /// target, and while a window goes in or out — on a bar's edge
    /// just inside the strip, which opens no slot (#2793).
    static func pocketStands(
        several: Bool,
        dragging: Bool,
        playing: Bool
    ) -> Bool {
        several || dragging || playing
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
        pocketPlate.onHover = { [weak self] display, on in
            self?.pocketHovered(display, on)
        }
        pocketPlate.onPush = { [weak self] display in
            self?.pocketPushed(display)
        }
        pocketPlate.onListChanged = { [weak self] in
            self?.updatePocketPlate()
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
