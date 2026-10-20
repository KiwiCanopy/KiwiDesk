import CoreGraphics

/// The floor a window or a Space's layout tiles to, read through
/// the one resolver (`TilingSettings.minWindowSize(for:in:)`,
/// #2237).
extension KiwiCore {
    /// The floor `space`'s own layout tiles its members to.
    func minWindowSize(in space: Space) -> MinSize {
        tiler.settings.minWindowSize(for: space.mode, in: space.id)
    }

    /// One window's floor: Floating's for a window
    /// `EffectiveFloat.applies` to, else the layout of the Space it
    /// renders in — so one window always has one floor. A window
    /// no Space holds takes Floating's, since no layout places it.
    func minWindowSize(of id: WindowID) -> MinSize {
        let space =
            state.windows[id].flatMap(state.renderSpace(of:))
            ?? state.workspaces.space(of: id)
        let mode = space.flatMap { state.workspaces[$0]?.mode }
        let floats = EffectiveFloat.applies(
            isFloating: state.windows[id]?.isFloating == true,
            mode: mode
        )
        return tiler.settings.minWindowSize(
            for: floats ? .floating : mode ?? .floating,
            in: space
        )
    }
}
