import AppKit

/// Whether a bar item owns the pointer (#1517): a tracking area
/// fires wherever its rect lies, covered or not, so an item under
/// the overflow count would light while the pointer is on the
/// count. The item hovers only where the window's hit test lands
/// on it or inside it.
@MainActor
enum BarHoverHit {
    #if DEBUG
        /// Test seam over the resting pointer, in window points;
        /// nil reads the machine.
        static var pointerOverride: ((NSWindow) -> CGPoint)?
    #endif

    static func owns(_ view: NSView, _ event: NSEvent) -> Bool {
        guard let content = view.window?.contentView else { return true }
        return owns(view, at: event.locationInWindow, in: content)
    }

    /// Whether `view` owns the pointer where it rests now. A render
    /// that moves an item out from under a resting pointer gets no
    /// exit event, so the hover is re-read here (#1665).
    static func ownsPointer(_ view: NSView) -> Bool {
        guard let window = view.window,
            let content = window.contentView
        else { return false }
        var point = window.mouseLocationOutsideOfEventStream
        #if DEBUG
            if let pointerOverride { point = pointerOverride(window) }
        #endif
        return owns(view, at: point, in: content)
    }

    private static func owns(
        _ view: NSView,
        at windowPoint: CGPoint,
        in content: NSView
    ) -> Bool {
        let point = content.convert(windowPoint, from: nil)
        guard let hit = content.hitTest(point) else { return false }
        return hit === view || hit.isDescendant(of: view)
    }
}
