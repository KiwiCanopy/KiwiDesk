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

    /// A chord while the list is key is the user's for the app
    /// beneath, never KiwiDesk's menu: a ⌘Q must not quit KiwiDesk
    /// (gui.md ▸ a non-activating key panel). It closes the list and
    /// is swallowed, as any key the list does not use.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // AppKit offers every key press here before `keyDown`, the
        // arrows included: only a ⌘ chord is the menu's to take.
        guard takesKey, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        _ = onKey(UInt16.max)
        return true
    }
}
