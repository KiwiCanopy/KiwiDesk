import AppKit

/// The peek's menu tracking (#1946, #761): any menu opening closes
/// it, and the window a bar menu opens on holds its shelf while the
/// menu tracks. Split from `BarPeek.swift` at the 350-line ceiling.
extension BarPeek {
    /// Whether the menu tracking now opened on `window` — what holds
    /// a hiding shelf the menu belongs to (#761).
    func menuTracks(on window: NSWindow) -> Bool {
        var tracking = menusTracking > 0
        #if DEBUG
            if let menuTrackingOverride { tracking = menuTrackingOverride }
        #endif
        return tracking && menuAnchor == ObjectIdentifier(window)
    }

    /// A press that may open a bar menu on `window`.
    func noteMenuAnchor(_ window: NSWindow?) {
        menuAnchor = window.map(ObjectIdentifier.init)
    }

    func menuBegan() {
        menusTracking += 1
        dismiss()
    }

    func menuEnded() {
        menusTracking = max(menusTracking - 1, 0)
        if menusTracking == 0 { menuAnchor = nil }
    }
}
