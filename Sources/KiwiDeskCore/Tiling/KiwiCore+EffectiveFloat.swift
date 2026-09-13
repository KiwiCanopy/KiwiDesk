import Foundation

extension KiwiCore {
    /// Whether `id` is an EFFECTIVE float on the active space —
    /// its own flag, or membership of a space that lays nothing
    /// out (#1178). The one door for a consumer judging on the
    /// ACTIVE space: the mode arm is answered only for a MEMBER,
    /// nil otherwise, per `EffectiveFloat.applies`' contract — a
    /// tiled sticky traveler renders here without belonging, and
    /// its home space's strips are on another screen. The flag
    /// arm is unconditional.
    func isEffectiveFloatOnActiveSpace(_ id: WindowID) -> Bool {
        let active = activeSpace
        return EffectiveFloat.applies(
            isFloating: state.windows[id]?.isFloating == true,
            mode: active?.windows.contains(id) == true
                ? active?.mode
                : nil
        )
    }
}
