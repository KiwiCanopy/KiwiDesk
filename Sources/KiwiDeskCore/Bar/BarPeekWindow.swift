import AppKit

/// The peek's panel window: non-activating, never main, and key only
/// while a grown list shows (#2563), so Escape and the arrow keys
/// reach its rows without activating KiwiDesk.
final class BarPeekWindow: NSPanel {
    /// Whether the panel may take the keyboard: the grown list's.
    var takesKey = false
    /// A key opened the list: it walks with that chord's ⌘ still held
    /// (#2974), since the arrows land before the chord lets go.
    var walksHeldKeys = false
    /// A key pressed while the panel is key, with its modifiers;
    /// true where it was used.
    var onKey: @MainActor (UInt16, NSEvent.ModifierFlags) -> Bool = {
        _,
        _ in false
    }

    override var canBecomeKey: Bool { takesKey }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if !onKey(event.keyCode, event.modifierFlags) {
            super.keyDown(with: event)
        }
    }

    /// A chord while the list is key is the user's for the app
    /// beneath, never KiwiDesk's menu: a ⌘Q must not quit KiwiDesk
    /// (gui.md ▸ a non-activating key panel). The list decides what
    /// it does (`BarPeekPanel.listKey`), and it is swallowed.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // AppKit offers every key press here before `keyDown`, the
        // arrows included: only a ⌘ chord is the menu's to take.
        guard takesKey, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        _ = onKey(event.keyCode, event.modifierFlags)
        return true
    }
}
