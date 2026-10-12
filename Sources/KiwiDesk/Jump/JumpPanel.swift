import AppKit

/// Jump to window's key window (#1875). Borderless, so it opts
/// into key status and answers File ▸ Close itself (#1533). The
/// panel's keys are read here, ahead of the search field: an
/// arrow, Return or a ⌘ digit never reaches the field's editor,
/// and every other press types into it.
final class JumpPanel: NSPanel {
    var onCancel: () -> Void = {}
    var onKey: (JumpKey) -> Void = { _ in }
    var onModifiers: (NSEvent.ModifierFlags) -> Void = { _ in }

    override var canBecomeKey: Bool { true }

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
            if let key = JumpKey.of(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags
            ) {
                onKey(key)
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }
}
