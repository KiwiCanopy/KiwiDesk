import Foundation

/// Manual float and sticky intent state management
/// (`WindowIdentity`, #160, #414).
extension StateCoordinator {
    /// Marks a window floating or tiled, remembering override across
    /// restarts (#160).
    public mutating func setFloating(
        _ id: WindowID,
        _ floating: Bool
    ) {
        guard windows[id] != nil else { return }
        windows.setFloating(id, floating)
        manualFloatOverrides[id] = floating
    }

    /// Sets a window's sticky scope (`make_sticky`, #414, #445).
    public mutating func setSticky(
        _ id: WindowID,
        _ scope: StickyScope
    ) {
        guard windows[id] != nil else { return }
        windows.setSticky(id, scope)
    }

    /// Clears manual float override and remembered identity intent (#164).
    public mutating func clearFloatOverride(_ id: WindowID) {
        manualFloatOverrides[id] = nil
        if let window = windows[id] {
            rememberedFloating[WindowIdentity(of: window)] = nil
        }
    }

    /// Saves manual float override into reopen memory keyed by identity
    /// (#160).
    mutating func rememberFloatOverride(
        of window: ManagedWindow
    ) {
        guard
            let intent = manualFloatOverrides.removeValue(
                forKey: window.id
            ),
            !window.title.isEmpty
        else { return }
        rememberedFloating[WindowIdentity(of: window)] = intent
    }

    /// Restores remembered float override onto (re)tracked window (#160).
    mutating func restoreFloatOverride(
        of window: ManagedWindow
    ) {
        guard manualFloatOverrides[window.id] == nil,
            !window.title.isEmpty,
            let intent = rememberedFloating.removeValue(
                forKey: WindowIdentity(of: window)
            )
        else { return }
        windows.setFloating(window.id, intent)
        manualFloatOverrides[window.id] = intent
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
