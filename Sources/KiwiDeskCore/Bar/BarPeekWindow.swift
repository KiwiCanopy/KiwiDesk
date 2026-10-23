import AppKit

/// The peek's panel window: non-activating, never main, and key only
/// while a grown list shows (#2563), so Escape and the arrow keys
/// reach its rows without activating KiwiDesk.
final class BarPeekWindow: NSPanel {
    /// Whether the panel may take the keyboard: the grown list's.
    var takesKey = false
    /// A key pressed while the panel is key; true where it was used.
    var onKey: @MainActor (UInt16) -> Bool = { _ in false }

    override var canBecomeKey: Bool { takesKey }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if !onKey(event.keyCode) { super.keyDown(with: event) }
    }
}
