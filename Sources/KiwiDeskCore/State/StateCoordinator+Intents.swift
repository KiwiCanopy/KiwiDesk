import Foundation

/// The manual float/sticky intent logic of `StateCoordinator`,
/// split from the event fold for the file ceiling: the command
/// entry points (`setFloating`, `setSticky`,
/// `clearFloatOverride`) and the close/reopen memory that
/// carries an intent across a window's tracking gaps (#160,
/// #414). The stored maps stay on the struct
/// (`manualFloatOverrides`, `rememberedFloating`,
/// `rememberedSticky`).
extension StateCoordinator {
    /// Marks a window floating/tiled (`make_floating`). The
    /// verdict is remembered as a manual override so it can
    /// survive the window closing and reopening (#160).
    public mutating func setFloating(
        _ id: WindowID,
        _ floating: Bool
    ) {
        guard windows[id] != nil else { return }
        windows.setFloating(id, floating)
        manualFloatOverrides[id] = floating
    }

    /// Sets a window's sticky scope (`make_sticky` /
    /// `make_display_sticky` / `make_unsticky`, #414/#445). No
    /// override map alongside: sticky has no detection source to
    /// fight, so the window value itself is the whole live state;
    /// close/reopen memory is `rememberedSticky`.
    public mutating func setSticky(
        _ id: WindowID,
        _ scope: StickyScope
    ) {
        guard windows[id] != nil else { return }
        windows.setSticky(id, scope)
    }

    /// Returns a window to detection control (`make_auto`):
    /// clears its manual override and the close/reopen memory
    /// of its identity, so detection verdicts apply again and
    /// nothing resurrects the old intent on reopen (#164).
    public mutating func clearFloatOverride(_ id: WindowID) {
        manualFloatOverrides[id] = nil
        if let window = windows[id] {
            rememberedFloating[WindowIdentity(of: window)] = nil
        }
    }

    /// Moves a window's manual float override (if any) into
    /// the close/reopen memory, keyed by its identity (#160).
    /// An empty title carries no identity — every pre-title
    /// window of the app would match it — so the override is
    /// dropped instead of remembered.
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

    /// Restores a remembered float intent onto a (re)tracked
    /// window: the manual verdict beats the fresh detection
    /// one, and the override re-arms so the next close cycle
    /// remembers it again (#160). Runs at creation and again
    /// on title changes (lazy-title apps); a live manual
    /// override is never clobbered.
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

    /// Writes a closing window's sticky state into the
    /// close/reopen memory (#414). Membership IS the intent:
    /// a sticky close inserts, a non-sticky close clears any
    /// stale entry of the same identity (last close wins). An
    /// empty title carries no identity — skipped, like float.
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

    /// Restores a remembered sticky intent onto a (re)tracked
    /// window, consuming the entry; the flag re-arms at the
    /// next close through `rememberStickyIntent`. Runs at
    /// creation and again on title changes (lazy-title apps),
    /// mirroring the float restore.
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
