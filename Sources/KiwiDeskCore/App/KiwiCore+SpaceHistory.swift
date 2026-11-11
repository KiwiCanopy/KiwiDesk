import Foundation

/// The live Space history and the setting it is walked by (#1655).
struct SpaceHistoryState {
    var trails = SpaceHistory()
    /// The global base: `gui.json`'s, or what `init.lua`'s
    /// `set_space_history` declared.
    var base = SpaceHistoryKind.defaultKind
    /// The live profile's sparse override; nil follows the base.
    var profileOverride: SpaceHistoryKind?
    /// The screens the focus arrived on, newest first, for
    /// `focus_display_last` (#2512); session-only, and no setting
    /// governs it.
    var screens: [DisplayID] = []

    var kind: SpaceHistoryKind { profileOverride ?? base }
}

/// `focus_space_back` / `focus_space_forward` walk the history and
/// `focus_space_last` toggles along it (#3206);
/// `focus_space_previous` / `focus_space_next` step the Space
/// order (#1655, rulings 2026-10-09). All four act on the focused
/// screen and never create a Space; the history refuses at an end
/// with the row-end bump the ⌃⌥⌘ + scroll step makes (#1519), and
/// the order step wraps unless Wrap focus is Off (#2592).
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
        if let here = focusedScreen, spaceHistory.screens.first != here {
            spaceHistory.screens.removeAll { $0 == here }
            spaceHistory.screens.insert(here, at: 0)
        }
    }

    /// The screen a key verb acts on: the focused one.
    var focusedScreen: DisplayID? {
        state.workspaces.activeSpace.flatMap {
            state.workspaces.display(of: $0)
        }
    }

    /// The trail the setting names for the focused screen, the
    /// Space it shows, and which entries a step may land on: a
    /// living Space and, per screen, one still on that screen.
    /// Both history verbs read it (#3206); nil per screen with
    /// no focused screen.
    func spaceHistoryWalk() -> (
        key: SpaceHistory.Key,
        shown: SpaceID?,
        reachable: (SpaceID) -> Bool
    )? {
        let screen = focusedScreen
        let perScreen = spaceHistory.kind == .perScreen
        let key: SpaceHistory.Key
        let shown: SpaceID?
        if perScreen {
            guard let screen else { return nil }
            key = .screen(screen)
            shown = state.workspaces.activeSpace(on: screen)
        } else {
            key = .allScreens
            shown = state.workspaces.activeSpace
        }
        let workspaces = state.workspaces
        let reachable: (SpaceID) -> Bool = { space in
            workspaces[space] != nil
                && (!perScreen || workspaces.display(of: space) == screen)
        }
        return (key, shown, reachable)
    }

    /// One step back (−1) or forward (+1) through the history the
    /// setting names: a cursor, never a visit. An entry whose
    /// Space is gone — or, per screen, now lives on another
    /// screen — is skipped.
    func focusSpaceInHistory(by direction: Int) -> CommandResponse {
        noteSpaceVisits()
        guard let walk = spaceHistoryWalk() else {
            return .fail("no focused screen")
        }
        guard
            let found = spaceHistory.trails.step(
                under: walk.key,
                by: direction,
                shown: walk.shown,
                reachable: walk.reachable
            )
        else {
            bumpAtSpaceEnd(direction)
            return .fail(
                "no Space \(direction < 0 ? "back" : "forward") "
                    + "in the history"
            )
        }
        spaceHistory.trails.move(under: walk.key, to: found.index)
        switchSpace(to: found.space, warp: true)
        return .ok()
    }

    /// `focus_space_last`: like ⌘Tab for Spaces (#3206). The
    /// Space the history last left, as an ordinary arrival — a
    /// visit, so repeated use toggles between two.
    func focusSpaceLast() -> CommandResponse {
        noteSpaceVisits()
        guard let walk = spaceHistoryWalk() else {
            return .fail("no focused screen")
        }
        guard
            let target = spaceHistory.trails.last(
                under: walk.key,
                shown: walk.shown,
                reachable: walk.reachable
            )
        else {
            bumpAtSpaceEnd(-1)
            return .fail("no last Space in the history")
        }
        switchSpace(to: target, warp: true)
        return .ok()
    }

    /// The previous (−1) or next (+1) Space in the focused
    /// screen's order — the Space Bar's, as the scroll step reads
    /// it.
    func focusSpaceInOrder(by step: Int) -> CommandResponse {
        guard let screen = focusedScreen else {
            return .fail("no focused screen")
        }
        guard stepSpace(on: screen, by: step, warp: true, scrolled: false)
        else {
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
