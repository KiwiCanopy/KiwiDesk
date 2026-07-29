import AppKit

/// The menu-bar slot behind `StatusItemController`, as a seam:
/// the production default is the real system item; tests inject
/// a per-file fake and never touch `NSStatusBar.system`.
///
/// Same defect class as the hotkey registrar (#565). The
/// controller's init used to create its `NSStatusItem` directly,
/// so every suite that exercised the quick-menu logic also
/// registered live menu-bar items nothing ever removed — a full
/// GUI run parked up to 15 blank slots in the real menu bar and
/// held WindowServer at sustained 40%+ CPU (observed
/// 2026-07-29). The fix is the #565 shape: an injection seam
/// whose production default stays live — never test-detection
/// inside production code. `StatusItemSeamGuardTests` pins both
/// sides: tests must inject a fake, and naming `NSStatusBar`
/// stays inside `SystemStatusItem`.
///
/// The surface is only what the controller uses: the button
/// (icon rendering, popover anchoring) and the menu assignment.
/// Widen the protocol here rather than reaching around it.
@MainActor
protocol StatusItemHandle: AnyObject {
    var button: NSStatusBarButton? { get }
    var menu: NSMenu? { get set }
}

/// The real slot: registers a visible item with the system menu
/// bar for the life of the process — right for the app, wrong
/// for a test process. No removal on deinit, deliberately: the
/// controller is app-lifetime, and `deinit` is nonisolated
/// where `NSStatusBar` is main-actor.
@MainActor
final class SystemStatusItem: StatusItemHandle {
    private let item: NSStatusItem

    init() {
        item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
    }

    var button: NSStatusBarButton? { item.button }

    var menu: NSMenu? {
        get { item.menu }
        set { item.menu = newValue }
    }
}
