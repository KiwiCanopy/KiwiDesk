import AppKit

/// Jump to window's key window (#1875). Borderless, so it opts
/// into key status and answers File ▸ Close itself (#1533). The
/// panel's keys are read here, ahead of the search field: an
/// arrow, Return or a ⌘ digit never reaches the field's editor,
/// and every other press types into it — save while an input
/// method composes, when every key is the composition's.
final class JumpPanel: NSPanel {
    var onCancel: () -> Void = {}
    var onKey: (JumpKey) -> Void = { _ in }
    var onModifiers: (NSEvent.ModifierFlags) -> Void = { _ in }
    var onComposing: (Bool) -> Void = { _ in }

    override var canBecomeKey: Bool { true }

    /// Non-activating, so KiwiDesk's menu is not the one in the
    /// menu bar: the File and Edit chords — ⌘W's Close (#1533),
    /// the edit chords — are handed to it here, and nothing else.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        super.performKeyEquivalent(with: event)
            || MainMenu.performPanelChord(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onKey(.escape)
    }

    /// ⌘W closes like Esc on an empty field.
    override func performClose(_ sender: Any?) {
        onCancel()
    }

    override func validateUserInterfaceItem(
        _ item: any NSValidatedUserInterfaceItem
    ) -> Bool {
        if item.action == #selector(NSWindow.performClose(_:)) {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            onModifiers(event.modifierFlags)
        case .keyDown:
            if !composing,
                let key = JumpKey.of(
                    keyCode: event.keyCode,
                    modifiers: event.modifierFlags
                )
            {
                onKey(key)
                return
            }
        default:
            break
        }
        super.sendEvent(event)
        if event.type == .keyDown { onComposing(composing) }
    }

    /// Whether the field's editor holds marked text: Return then
    /// commits it, Esc cancels it and the arrows pick a candidate.
    var composing: Bool {
        (firstResponder as? NSTextInputClient)?.hasMarkedText() == true
    }
}
