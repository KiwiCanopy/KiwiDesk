import Foundation

/// The live Space history and the setting it is walked by (#1655).
struct SpaceHistoryState {
    var trails = SpaceHistory()
    /// The global base: `gui.json`'s, or what `init.lua`'s
    /// `set_space_history` declared.
    var base = SpaceHistoryKind.defaultKind
    /// The live profile's sparse override; nil follows the base.
    var profileOverride: SpaceHistoryKind?

    var kind: SpaceHistoryKind { profileOverride ?? base }
}

/// `focus_space_back` / `focus_space_forward` walk the history;
/// `focus_space_previous` / `focus_space_next` step the Space
/// order (#1655, rulings 2026-10-09). All four act on the focused
/// screen, never create a Space, and refuse at an end with the
/// row-end bump the ⌃⌥⌘ + scroll step makes (#1519).
extension KiwiCore {
    /// Records what every screen shows now, and what the focused
    /// screen shows, as visits. Every arrival — a key, a click, a
    /// move-and-follow, a Desktop switch activating a bound
    /// profile's Space — reaches `emitSpaceChange` or a retile,
    /// which both call this, so no path names itself here.
    func noteSpaceVisits() {
        let screens = state.workspaces.allDisplays.map(\.id)
        spaceHistory.trails.keepScreens(Set(screens))
        for screen in screens {
            guard let shown = state.workspaces.activeSpace(on: screen)
            else { continue }
            spaceHistory.trails.visit(shown, under: .screen(screen))
        }
        if let active = state.workspaces.activeSpace {
            spaceHistory.trails.visit(active, under: .allScreens)
        }
    }

    /// The screen a key verb acts on: the focused one.
    var focusedScreen: DisplayID? {
        state.workspaces.activeSpace.flatMap {
            state.workspaces.display(of: $0)
        }
    }

    /// One step back (−1) or forward (+1) through the history the
    /// setting names: a cursor, never a visit. An entry whose
    /// Space is gone — or, per screen, now lives on another
    /// screen — is skipped.
    func focusSpaceInHistory(by direction: Int) -> CommandResponse {
        noteSpaceVisits()
        let screen = focusedScreen
        let key: SpaceHistory.Key
        let shown: SpaceID?
        switch spaceHistory.kind {
        case .perScreen:
            guard let screen else { return .fail("no focused screen") }
            key = .screen(screen)
            shown = state.workspaces.activeSpace(on: screen)
        case .allScreens:
            key = .allScreens
            shown = state.workspaces.activeSpace
        }
        let perScreen = spaceHistory.kind == .perScreen
        guard
            let found = spaceHistory.trails.step(
                under: key,
                by: direction,
                shown: shown,
                reachable: { space in
                    state.workspaces[space] != nil
                        && (!perScreen
                            || state.workspaces.display(of: space)
                                == screen)
                }
            )
        else {
            bumpAtSpaceEnd(direction)
            return .fail(
                "no Space \(direction < 0 ? "back" : "forward") "
                    + "in the history"
            )
        }
        spaceHistory.trails.move(under: key, to: found.index)
        switchSpace(to: found.space, warp: true)
        return .ok()
    }

    /// The previous (−1) or next (+1) Space in the focused
    /// screen's order — the Space Bar's, as the scroll step reads
    /// it.
    func focusSpaceInOrder(by step: Int) -> CommandResponse {
        guard let screen = focusedScreen else {
            return .fail("no focused screen")
        }
        guard stepSpace(on: screen, by: step, warp: true) else {
            return .fail(
                "no \(step < 0 ? "previous" : "next") Space on "
                    + "this screen"
            )
        }
        return .ok()
    }

    /// The row-end bump on the shown Space's focus, toward the
    /// step; an empty Space has no ring and says nothing.
    func bumpAtSpaceEnd(_ step: Int, on screen: DisplayID? = nil) {
        let shown =
            screen.flatMap { state.workspaces.activeSpace(on: $0) }
            ?? state.workspaces.activeSpace
        guard let space = shown.flatMap({ state.workspaces[$0] }),
            let focused = state.focusAnchor(of: space)
        else { return }
        flashDeadEnd(
            focused,
            direction: Self.direction(step, horizontal: true)
        )
    }

    /// The resolve: the base with the live profile's override on
    /// top. A config load passes the base it read; a profile apply
    /// passes nil and keeps the base in hand, which under a
    /// Lua-owned config is what `init.lua` declared.
    func applySpaceHistory(
        base: SpaceHistoryKind? = nil,
        profile: SpaceHistoryKind?
    ) {
        if let base { spaceHistory.base = base }
        spaceHistory.profileOverride = profile
    }

    /// `set_space_history`: writes the BASE, so a profile's own
    /// override still wins, and lasts until the next config load.
    func setSpaceHistory(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let kind = SpaceHistoryKind(rawValue: raw)
        else { return .expected(SpaceHistoryKind.self) }
        spaceHistory.base = kind
        return .ok()
    }
}
