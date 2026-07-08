import AppKit

extension NSApplication {
    /// Raise KiwiDesk to `.regular` (Dock tile + menu bar) and
    /// assert its Dock icon.
    ///
    /// The bare executable ships no `.icns`, so the tile created
    /// on promotion shows the generic placeholder. An
    /// `applicationIconImage` set earlier — while `.accessory`,
    /// before any tile exists — does not carry onto that fresh
    /// tile, so the mark must be applied *after* the policy
    /// flip. The packaged `.app` (#89) will supply a real icon
    /// and make the image assignment a harmless no-op.
    @MainActor func activateAsRegular() {
        setActivationPolicy(.regular)
        if let icon = BrandAssets.appMark {
            applicationIconImage = icon
        }
    }

    /// Return to menu-bar-only (`.accessory`) — but only if no
    /// other content window is still on screen. Closing one of
    /// {Settings, onboarding, Config Issues} must not drop the
    /// Dock tile while another is visible. Panels (the shared
    /// color panel) can't become main, so they don't count.
    @MainActor func deactivateIfNoWindows(
        excluding closing: NSWindow?
    ) {
        let othersVisible = windows.contains { win in
            win !== closing && win.isVisible && win.canBecomeMain
        }
        if !othersVisible {
            setActivationPolicy(.accessory)
        }
    }
}
