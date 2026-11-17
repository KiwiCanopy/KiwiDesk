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
    /// A key pressed while the panel is key; true where it was used.
    var onKey: @MainActor (UInt16) -> Bool = { _ in false }
    /// KiwiHub's navigation alternatives, read at each press
    /// (#3398).
    var keys: @MainActor () -> KiwiHubKeys = { KiwiHubKeys() }

    override var canBecomeKey: Bool { takesKey }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        let code = arrow(of: event) ?? event.keyCode
        if !onKey(code) { super.keyDown(with: event) }
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
        // A ⌘ alternative walks, never closes (#3398).
        if let code = arrow(of: event) {
            _ = onKey(code)
            return true
        }
        let walks =
            walksHeldKeys && BarPeekPanel.ListKey.all.contains(event.keyCode)
        _ = onKey(walks ? event.keyCode : UInt16.max)
        return true
    }

    private func arrow(of event: NSEvent) -> UInt16? {
        BarPeekListKeys.arrow(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            keys: keys()
        )
    }
}
