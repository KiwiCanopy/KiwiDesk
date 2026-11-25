import Foundation

/// The Space order a Lua-owned config states (#3625): the order
/// in which its `init.lua` run first references each Space.
extension KiwiCore {
    /// The ids `ensureSpace` is handed while `body` runs, once
    /// each, in first-reference order — the braces are the window,
    /// so the script's asks can never be read after a later
    /// ensurer's. A run ledger rather than a before/after diff of
    /// the space set: a reload's `create_space` of a live space
    /// changes nothing a diff could see (#1509).
    func recordingSpaceReferences(
        _ body: () -> Void
    ) -> [SpaceID] {
        state.workspaces.referenced = []
        body()
        return state.workspaces.referenced
    }

    /// Puts the live Spaces in `declared` order on every load of a
    /// Lua-owned config, cold boot and reload alike; a Space the
    /// run never named — held, temporary, CLI-created — keeps its
    /// relative order behind them. An active profile's order is
    /// applied after this and wins.
    func applyLuaSpaceOrder(_ declared: [SpaceID]) {
        state.workspaces.reorder(matching: declared)
    }
}
