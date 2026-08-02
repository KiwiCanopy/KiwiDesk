import AppKit

/// KiwiDesk holds `.accessory` for its whole life, so this file
/// is deliberately down to one call: how a menu-bar app gets a
/// window in front of the user without a Dock tile to click.
///
/// The promote/demote pair that used to live here is gone on
/// purpose. Every content window that raised `.regular` had to
/// remember to release it, and the release had to survive being
/// the *last* of {Settings, onboarding, Config Issues} to close —
/// a rule spread across three controllers, which is exactly how
/// the app came to strand itself `.regular` with nothing on
/// screen. Not promoting is the only version of that rule with
/// nowhere to forget it. See "Permanent accessory mode" in
/// `docs/design-decisions.md`.
extension NSApplication {
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
}
