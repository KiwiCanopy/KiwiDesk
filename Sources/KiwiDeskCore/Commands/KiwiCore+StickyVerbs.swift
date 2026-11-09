import Foundation

/// The focused window's sticky verbs, split from
/// `KiwiCore+Commands.swift` at the §2.1 ceiling.
extension KiwiCore {
    /// `make_sticky` / `make_display_sticky` / `make_unsticky`
    /// (#414/#445): sets the focused window's sticky SCOPE. No
    /// tri-state and no detection source — the scope is the whole
    /// story, and each verb writes its own scope outright, so
    /// `make_sticky` on a display-sticky window turns it global and
    /// vice versa (the #221 sibling-verb model). The window keeps
    /// its float/tiled state; the retile applies the effect (stash
    /// exemption, traveler injection) at once.
    func setFocusedSticky(
        _ scope: StickyScope
    ) -> CommandResponse {
        guard let focused = focusedWindowID else {
            return .fail("no focused window")
        }
        if state.pocketPhase(of: focused) != nil {
            return refusePocketSticky(focused)
        }
        state.setSticky(focused, scope)
        retile()
        return .ok()
    }

    /// `toggle_sticky` / `toggle_display_sticky` (#414/#445): the
    /// everyday sticky verbs, the two offered in the Settings
    /// shortcut list (#221 precedent). Each toggles ITS scope
    /// against off: already in `scope` → off; anything else
    /// (unsticky OR the other scope) → `scope`. So toggling display
    /// on a global sticky switches it to display, matching the
    /// `make_*` override semantics.
    func toggleFocusedSticky(
        _ scope: StickyScope
    ) -> CommandResponse {
        guard
            let focused = focusedWindowID,
            let window = state.windows[focused]
        else {
            return .fail("no focused window")
        }
        let next: StickyScope =
            window.stickyScope == scope ? .none : scope
        return setFocusedSticky(next)
    }
}
