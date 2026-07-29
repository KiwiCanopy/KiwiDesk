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
/// inside production code.
///
/// Enforcement is split by route. The live wrapper
/// (`SystemStatusItem`) lives file-scoped `private` beside the
/// controller, so a test cannot name it even under
/// `@testable import` — sealed by construction. The remaining
/// routes — a bare construction taking the live default, a
/// hand-rolled handle naming `NSStatusBar` — are scanned by
/// `StatusItemSeamGuardTests`, which also pins the wrapper's
/// access level so the seal cannot be raised unnoticed.
///
/// The surface is only what the controller uses: the button
/// (icon rendering, popover anchoring) and the menu assignment.
/// Widen the protocol here rather than reaching around it.
@MainActor
protocol StatusItemHandle: AnyObject {
    var button: NSStatusBarButton? { get }
    var menu: NSMenu? { get set }
}
