import AppKit

/// Menu bar status item injection seam (`StatusItemSeamGuardTests`, #565).
@MainActor
protocol StatusItemHandle: AnyObject {
    var button: NSStatusBarButton? { get }
    var menu: NSMenu? { get set }
}
