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
        /// A window point no bar item covers, for the pin.
        static let offWindow = CGPoint(x: -100_000, y: -100_000)
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
        return owns(view, at: restingPoint(in: window), in: content)
    }

    /// Where the pointer rests now, in `window`'s points.
    static func restingPoint(in window: NSWindow) -> CGPoint {
        #if DEBUG
            if let pointerOverride { return pointerOverride(window) }
        #endif
        return window.mouseLocationOutsideOfEventStream
    }

    private static func owns(
        _ view: NSView,
        at windowPoint: CGPoint,
        in content: NSView
    ) -> Bool {
        // `hitTest` reads its superview's coordinates: the content
        // root is flipped, so its own would mirror y and land on
        // another item along a side bar (#3414).
        let point =
            content.superview?.convert(windowPoint, from: nil)
            ?? windowPoint
        guard let hit = content.hitTest(point) else { return false }
        return hit === view || hit.isDescendant(of: view)
    }
}
