import Foundation

/// A lens's hold on KiwiDesk's own navigation (#2103 rulings 30,
/// 35, 36, 44, 45): while a lens keeps focus on its apps, the focus
/// and swap keys and the scroll gesture skip every window the lens
/// leaves out; while a lens is on, the window switcher lists its
/// apps first. A click, a bar item, hover focus and the window
/// switcher are deliberate picks and skip nothing.
extension KiwiCore {
    /// The windows a step skips now: every window the lens on leaves
    /// out — another app's, or a member's its titles do not match —
    /// asked per window of the one `visionLensClear` the plates take
    /// (ruling 44). Never dimmed clears a window without making it a
    /// member, so it is skipped too. Nil while no lens keeps focus.
    func lensKeySkip() -> ((WindowID) -> Bool)? {
        guard visionLook.lens?.keepFocus == true else { return nil }
        return { [self] id in
            // The pocket's clear pair is never skipped (#2446).
            guard let window = state.windows[id],
                !visionPocketPair().contains(id)
            else { return false }
            return !visionLensClear(window.appRef)
                .clears(title: window.title)
        }
    }

    /// Whether the lens on holds `app` at all — a window switcher
    /// row's question, which names apps (ruling 36); false while no
    /// lens is on.
    func lensHolds(_ app: AppRef) -> Bool {
        visionLensClear(app) != .none
    }
}

extension ManagedWindow {
    /// The app this window belongs to, as an app list names it.
    var appRef: AppRef { AppRef(bundleID: appBundleID, name: appName) }
}
