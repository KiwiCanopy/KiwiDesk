import AppKit

/// Whether a bar item owns the pointer (#1517): a tracking area
/// fires wherever its rect lies, covered or not, so an item under
/// the overflow count would light while the pointer is on the
/// count. The item hovers only where the window's hit test lands
/// on it or inside it.
@MainActor
enum BarHoverHit {
    static func owns(_ view: NSView, _ event: NSEvent) -> Bool {
        guard let content = view.window?.contentView else { return true }
        let point = content.convert(event.locationInWindow, from: nil)
        guard let hit = content.hitTest(point) else { return false }
        return hit === view || hit.isDescendant(of: view)
    }
}
