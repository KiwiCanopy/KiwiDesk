import Foundation

/// The live layout cycle and the setting it is walked by (#453),
/// shaped as `SpaceHistoryState` (#1655).
struct ModeCycleState {
    /// The global base: `gui.json`'s, or what `init.lua`'s
    /// `set_mode_cycle` declared.
    var base = ModeCycle.defaultList
    /// The live profile's sparse override; nil follows the base.
    var profileOverride: [LayoutMode]?

    var list: [LayoutMode] { profileOverride ?? base }
}

/// `cycle_mode` and `set_mode_cycle` (#453): the focused Space
/// steps to the next layout in the user's list, through
/// `set_mode`'s own write so the Layout menu's not-saved state and
/// Keep (#1179) follow a keyed change like a menu pick.
extension KiwiCore {
    /// Steps the focused Space — the one `set_mode` without a
    /// Space names — and never creates one.
    func cycleMode(_ args: [JSONValue]) -> CommandResponse {
        let direction: ModeCycleDirection
        if let first = args.first {
            guard let raw = first.stringValue,
                let named = ModeCycleDirection(rawValue: raw)
            else { return .expected(ModeCycleDirection.self) }
            direction = named
        } else {
            direction = .next
        }
        guard let space = state.workspaces.activeSpace,
            let current = state.workspaces[space]?.mode
        else { return .fail("no focused Space") }
        guard
            let next = ModeCycle.step(
                from: current,
                in: modeCycle.list,
                direction: direction
            )
        else { return .fail("the layout cycle is empty") }
        return setMode([.string(space.raw), .string(next.rawValue)])
    }

    /// `set_mode_cycle({...})`: the list the cycle walks, in order
    /// — at least two layouts, each once — as one Lua table or, from
    /// the CLI, one argument per layout. Writes the BASE, so a
    /// profile's own override still wins: a config load resets
    /// it, and where Settings owns the config every re-apply of
    /// `gui.json` (a profile apply, a rule write) puts the stored
    /// list back.
    func setModeCycle(_ args: [JSONValue]) -> CommandResponse {
        let items: [JSONValue]
        if case .array(let list)? = args.first, args.count == 1 {
            items = list
        } else {
            items = args
        }
        let raws = items.compactMap(\.stringValue)
        let modes = raws.compactMap(LayoutMode.init(rawValue:))
        guard modes.count == items.count else {
            return .expected(LayoutMode.self)
        }
        guard ModeCycle.isValid(modes) else {
            return .fail(
                "expected at least \(ModeCycle.minimumCount) different "
                    + "layouts"
            )
        }
        modeCycle.base = modes
        return .ok()
    }

    /// The resolve: the base with the live profile's override on
    /// top. A config load passes the base it read; a profile apply
    /// passes nil and keeps the base in hand, which under a
    /// Lua-owned config is what `init.lua` declared.
    func applyModeCycle(
        base: [LayoutMode]? = nil,
        profile: [LayoutMode]?
    ) {
        if let base { modeCycle.base = base }
        modeCycle.profileOverride = profile
    }
}
