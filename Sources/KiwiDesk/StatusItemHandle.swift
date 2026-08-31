import AppKit

/// Menu bar status item injection seam (#565 shape): production
/// default stays the live system item, tests inject a fake and
/// never touch `NSStatusBar.system` — never test-detection in
/// production code. The live wrapper stays file-private (sealed
/// by construction); `StatusItemSeamGuardTests` scans the other
/// routes. Widen this protocol rather than reaching around it.
@MainActor
protocol StatusItemHandle: AnyObject {
    var button: NSStatusBarButton? { get }
    var menu: NSMenu? { get set }
}
