import AppKit

extension NSApplication {
    /// Raise KiwiDesk to `.regular` (Dock tile + menu bar), and
    /// for the bare executable only, assert a Dock icon.
    ///
    /// The bare executable ships no icon, so the tile created on
    /// promotion shows the generic placeholder. An
    /// `applicationIconImage` set earlier — while `.accessory`,
    /// before any tile exists — does not carry onto that fresh
    /// tile, so the mark must be applied *after* the policy flip.
    ///
    /// **Inside the packaged `.app` this must NOT run.** The
    /// assignment *overrides* the bundle's icon rather than
    /// deferring to it, so leaving it unconditional replaced the
    /// real `AppIcon` — squircle, layers, the lot — with the flat
    /// 512 px `AppMark.png` raster the moment Settings opened
    /// (#89). Keyed on `CFBundleIconName` because that is exactly
    /// the question being asked: did the bundle bring its own
    /// icon?
    @MainActor func activateAsRegular() {
        setActivationPolicy(.regular)
        let bundled =
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleIconName"
            ) != nil
        guard !bundled else { return }
        if let icon = BrandAssets.appMark {
            applicationIconImage = icon
        }
    }

    /// Bring a content window fully to the front — the strong
    /// activation a menu-bar/agent process needs.
    ///
    /// Cooperative `activate()` foregrounds the app only when the
    /// activation was user-initiated. A window opened on **service
    /// (launchd) start** (onboarding) never is, so it reliably
    /// lands behind the frontmost app. A bare executable has no
    /// bundle identity, which made even a menu-bar-triggered
    /// Settings open flaky; the packaged `.app` (#89) fixes that
    /// case, but the launchd one is unchanged. `orderFrontRegardless()` +
    /// `activate(ignoringOtherApps:)` is the escape hatch AppKit
    /// reserves for exactly this case (already relied on by
    /// `SingleInstanceGuard`). The packaged `.app` (#89) will make
    /// the cooperative path reliable and let this soften.
    @MainActor func forceFront(_ window: NSWindow) {
        // Two order-front calls by intent, not accident:
        // `makeKeyAndOrderFront` sets the key window but only
        // orders front *within* an active app; `orderFrontRegardless`
        // additionally shows the window while the process is still
        // `.accessory`/inactive — the launchd case the cooperative
        // `activate()` can't foreground on its own.
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        activate(ignoringOtherApps: true)
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
