import Foundation

/// The focus-wrap setting's live state (#2493).
struct FocusWrapState {
    /// The global base: `gui.json`'s, or what `init.lua`'s
    /// `set_focus_wrap` declared.
    var base = FocusWrap.defaultMode
    /// The live profile's sparse override; nil follows the base.
    var profileOverride: FocusWrap?

    var mode: FocusWrap { profileOverride ?? base }
}

extension KiwiCore {
    /// The resolve: the base with the live profile's override on
    /// top. A config load passes the base it read; a profile apply
    /// passes nil and keeps the base in hand, which under a
    /// Lua-owned config is what `init.lua` declared.
    func applyFocusWrap(base: FocusWrap? = nil, profile: FocusWrap?) {
        if let base { focusWrap.base = base }
        focusWrap.profileOverride = profile
    }

    /// `set_focus_wrap`: writes the BASE, so a profile's own
    /// override still wins, and lasts until the next config load.
    func setFocusWrap(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let mode = FocusWrap(rawValue: raw)
        else { return .expected(FocusWrap.self) }
        focusWrap.base = mode
        return .ok()
    }
}
