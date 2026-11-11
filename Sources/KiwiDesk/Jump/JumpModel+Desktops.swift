import AppKit
import KiwiDeskCore

/// KiwiHub's Desktops side (#1229): its keys, its clicks and its
/// query. The state decides; this hands its outcome to the panel.
extension JumpModel {
    /// Reads the desk now and opens on the KiwiHub screen's line.
    func enterDesktops() {
        endDesktopsRefusal()
        let overview = loadDesktops()
        desktops = state(of: overview)
        let pids = overview.screens.flatMap(\.desktops)
            .flatMap(\.spaces).flatMap(\.windows).map(\.pid)
        desktopIcons = loadIcons(Set(pids))
    }

    func setDesktopsQuery(_ query: String) {
        guard desktops != nil else { return }
        endDesktopsRefusal()
        desktops?.setQuery(query)
        onAnnounce(desktopsSpoken)
    }

    func handleDesktops(_ key: JumpKey, repeated: Bool) {
        endDesktopsRefusal()
        if key == .settings {
            onDesktopsSettings()
            return
        }
        guard var state = desktops else { return }
        let outcome = state.press(key, repeated: repeated)
        desktops = state
        answer(outcome)
    }

    /// A click on a Space line, or a card's title for its shown
    /// line, is ↩ there on release (#3209): a line goes to its Space,
    /// a title to its Desktop, and a carry drops; ⇧ moves your window
    /// there. A double click's second press acts on nothing.
    func clickPlace(
        _ place: DesktopsPlace,
        count: Int,
        modifiers: NSEvent.ModifierFlags,
        opens: Bool
    ) {
        guard scope == .desktops, var state = desktops else { return }
        endDesktopsRefusal()
        restPointerForClick()
        guard count < 2 else { return }
        let modifiers = pickModifiers(modifiers)
        state.select(place)
        desktops = state
        // ⌘↩ and ⌥↩ name a window, which a place is not.
        guard modifiers.isDisjoint(with: [.option, .command]) else { return }
        if state.isCarrying || modifiers.contains(.shift) {
            let moveHere = !state.isCarrying
            return handleDesktops(.pick(moveHere: moveHere), repeated: false)
        }
        if opens {
            handleDesktops(.pick(moveHere: false), repeated: false)
        } else if let desktop = state.desktop(place) {
            onDesktopsAction(.jumpDesktop(desktop))
        }
    }

    /// A click on a window's icon is ↩ on it on release (#3209):
    /// it jumps there, and a carry drops on its Space; ⇧ Move here,
    /// ⌥ Swap here, ⌘ pick up or put back. A double click's second
    /// press acts on nothing, and ⌥ during a carry nothing, as ⌥↩.
    func clickWindow(
        _ id: WindowID,
        in place: DesktopsPlace,
        count: Int,
        modifiers: NSEvent.ModifierFlags
    ) {
        guard scope == .desktops, var state = desktops else { return }
        endDesktopsRefusal()
        restPointerForClick()
        guard count < 2 else { return }
        let held = pickModifiers(modifiers)
            .intersection([.shift, .option, .command])
        // ⌥↩ swaps no window while windows ride along.
        if state.isCarrying, held.contains(.option) { return }
        if state.isCarrying, !held.contains(.command) {
            state.select(place)
            desktops = state
            return handleDesktops(.pick(moveHere: false), repeated: false)
        }
        state.select(window: id, in: place)
        desktops = state
        if held.contains(.command) {
            handleDesktops(.pickUp, repeated: false)
        } else if held.contains(.option) {
            handleDesktops(.swapHere, repeated: false)
        } else {
            let moveHere = held.contains(.shift)
            handleDesktops(.pick(moveHere: moveHere), repeated: false)
        }
    }

    /// A "+n" count: opens the Space on the next window hidden on
    /// that side, one more per click (#1229 ▸ Mouse).
    func clickMore(_ place: DesktopsPlace, forward: Bool) {
        guard scope == .desktops, var state = desktops else { return }
        endDesktopsRefusal()
        state.revealMore(place, forward: forward)
        desktops = state
    }

    /// A drop of dragged windows on a place: a move, and you stay.
    func dropWindows(_ ids: [WindowID], on place: DesktopsPlace) {
        guard scope == .desktops, let state = desktops else { return }
        endDesktopsRefusal()
        guard let target = state.target(place) else {
            return answer(.refuse(.noSpace))
        }
        // A drag carries what ⌘↩ may pick up, and nothing else.
        for id in ids {
            if let window = state.overview.window(id),
                let block = window.block
            {
                return answer(.refuse(.carryBlocked(window, block)))
            }
        }
        let there = Set(state.line(place)?.windows.map(\.id) ?? [])
        let moving = ids.filter { !there.contains($0) }
        guard !moving.isEmpty else {
            return answer(.refuse(.alreadyThere(target.space)))
        }
        answer(.act(.drop(moving, target, follow: false)))
    }

    private func answer(_ outcome: DesktopsOutcome) {
        switch outcome {
        case .moved:
            onAnnounce(desktopsSpoken)
        case .act(let action):
            onDesktopsAction(action)
        case .refuse(.carryBlocked(let window, let block)):
            refuseDesktops(
                DesktopsText.refusal(.carryBlocked(window, block)),
                swelling: .window(window.id)
            )
        case .refuse(let refusal):
            refuseDesktops(DesktopsText.refusal(refusal))
        case .close:
            onClose()
        case .dead:
            onDeadKey()
        }
    }

    /// After a drop that keeps KiwiHub open (#3165): reads the desk
    /// again and selects `target`'s line.
    func reloadDesktops(selecting target: DesktopsTarget) {
        guard scope == .desktops else { return }
        let query = desktops?.query ?? ""
        enterDesktops()
        guard var state = desktops else { return }
        if !query.isEmpty { state.setQuery(query) }
        let overview = state.overview
        for (screen, row) in overview.screens.enumerated()
        where row.display == target.display {
            for (desktop, card) in row.desktops.enumerated()
            where card.native == target.desktop.native {
                guard
                    let line = card.spaces.firstIndex(where: {
                        $0.space == target.space
                    })
                else { continue }
                state.select(
                    DesktopsPlace(screen: screen, desktop: desktop, line: line)
                )
            }
        }
        desktops = state
    }

    /// Reads the desk again under the open side, for a drop still
    /// landing (#3208): the place, and the window inside it, stay
    /// selected where they still exist, and the search and a shown
    /// refusal stay as they are. A carry waits for the next read.
    func refreshDesktops() {
        guard scope == .desktops, let old = desktops, !old.isCarrying
        else { return }
        let overview = loadDesktops()
        var fresh = state(of: overview)
        if !old.query.isEmpty { fresh.setQuery(old.query) }
        if let place = old.place, let line = fresh.line(place) {
            if let id = old.window,
                line.windows.contains(where: { $0.id == id })
            {
                fresh.select(window: id, in: place)
            } else {
                fresh.select(place)
            }
        }
        let pids = Set(
            overview.screens.flatMap(\.desktops).flatMap(\.spaces)
                .flatMap(\.windows).map(\.pid)
        ).subtracting(desktopIcons.keys)
        if !pids.isEmpty { desktopIcons.merge(loadIcons(pids)) { $1 } }
        desktops = fresh
    }

    /// The side's state over `overview`, sized from the panel.
    private func state(of overview: DesktopOverview) -> DesktopsState {
        let geometry = DesktopsGeometry(
            overview: overview,
            width: panelWidth,
            cap: sheetCap
        )
        return DesktopsState(overview: overview, geometry: geometry)
    }

    /// What VoiceOver hears for the selection now.
    var desktopsSpoken: String {
        guard let state = desktops else { return "" }
        return DesktopsText.spoken(state)
    }

    private func restPointerForClick() { clearHover() }
}
