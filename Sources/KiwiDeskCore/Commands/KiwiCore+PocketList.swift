import AppKit

/// `pocket.toggle_list` (#2974): the pocket's list by key, at its Edge
/// and Position on the active Space's screen, grown out of it as a
/// click grows it. No bar reveals or moves: the pocket stands for its
/// list under One window, and the plan stays capacity-only.
extension KiwiCore {
    func pocketToggleListCommand() -> CommandResponse {
        // The chord closes a list open on any screen.
        if pocketListDisplay != nil {
            shelves.peek.dismiss()
            return .ok()
        }
        let workspaces = state.workspaces
        guard let space = workspaces.activeSpace,
            let display = workspaces.display(of: space)
        else { return .fail("the pocket draws on no screen here") }
        if shelfStandsDown(on: display) {
            cuePocketListStandDown(on: display)
            return .fail(
                "the pocket stays hidden while a window fills the screen"
            )
        }
        pocketPlate.openingList = display
        defer {
            pocketPlate.openingList = nil
            // A list that did not open leaves no pocket standing for it.
            if pocketListDisplay == nil { updatePocketPlate() }
        }
        // The pass refreshes what places a pocket that stood nowhere.
        updateBars(holdingForSwitch: false)
        guard let view = pocketPlate.view(on: display) else {
            return .fail("the pocket draws on no screen here")
        }
        shelves.peek.show(
            view,
            source: .pocket(pocketPlateWindows),
            space: nil,
            edge: tiler.settings.kiwishelf.pocketEdge,
            keyed: true
        )
        return pocketListDisplay == display
            ? .ok() : .fail("the pocket draws on no screen here")
    }

    /// The pill at the pocket's edge of the screen: spoken, since a
    /// key-opened list has no other twin to say why it did not open.
    private func cuePocketListStandDown(on display: DisplayID) {
        guard let screen = screen(for: display) else { return }
        let edge = tiler.settings.kiwishelf.pocketEdge
        soundIfDrawn(
            flashRefusalPill(
                near: refusalStrip(of: screen, edge: edge),
                on: display,
                edge: edge,
                text: PocketRefusal.listStandsDownSentence,
                symbol: "eye.slash",
                announce: true
            )
        )
    }
}
