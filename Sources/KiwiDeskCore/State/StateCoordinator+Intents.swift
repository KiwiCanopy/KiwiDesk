import Foundation

/// User float and sticky intent state management
/// (`WindowIdentity`, #160, #414, #1810).
extension StateCoordinator {
    /// Floats a window as the user's choice, or clears that choice
    /// and tiles it (#1810). A Tile also forgets the window's
    /// reopen memory, so nothing brings the float back.
    public mutating func setFloating(
        _ id: WindowID,
        _ floating: Bool
    ) {
        guard let window = windows[id] else { return }
        windows.setFloating(id, floating)
        if floating {
            userFloated.insert(id)
        } else {
            userFloated.remove(id)
            rememberedFloating.remove(WindowIdentity(of: window))
        }
    }

    /// Sets a window's sticky scope (`make_sticky`, #414, #445).
    public mutating func setSticky(
        _ id: WindowID,
        _ scope: StickyScope
    ) {
        guard windows[id] != nil else { return }
        windows.setSticky(id, scope)
    }

    /// Saves a user float into reopen memory keyed by identity
    /// (#160). An empty title carries no identity — every
    /// pre-title window of the app would match it — so the
    /// float is dropped instead of remembered.
    mutating func rememberFloatOverride(
        of window: ManagedWindow
    ) {
        guard userFloated.remove(window.id) != nil,
            !window.title.isEmpty
        else { return }
        rememberedFloating.insert(WindowIdentity(of: window))
    }

    /// Restores a remembered user float onto a (re)tracked window
    /// (#160).
    mutating func restoreFloatOverride(
        of window: ManagedWindow
    ) {
        guard !userFloated.contains(window.id),
            !window.title.isEmpty,
            rememberedFloating.remove(WindowIdentity(of: window))
                != nil
        else { return }
        windows.setFloating(window.id, true)
        userFloated.insert(window.id)
    }

    /// Saves closing window's sticky state into identity memory (#414).
    mutating func rememberStickyIntent(
        of window: ManagedWindow
    ) {
        guard !window.title.isEmpty else { return }
        let identity = WindowIdentity(of: window)
        if window.stickyScope == .none {
            rememberedSticky[identity] = nil
        } else {
            rememberedSticky[identity] = window.stickyScope
        }
    }

    /// Restores remembered sticky intent onto (re)tracked window (#414).
    mutating func restoreStickyIntent(
        of window: ManagedWindow
    ) {
        guard !window.title.isEmpty,
            let scope = rememberedSticky.removeValue(
                forKey: WindowIdentity(of: window)
            )
        else { return }
        windows.setSticky(window.id, scope)
    }
}
