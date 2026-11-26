import AppKit
import KiwiDeskCore

/// The look picker's full-screen key panel (#3038). Borderless and
/// non-activating like KiwiHub's (#1875), so it opts into key status
/// and answers File ▸ Close itself (#1533). Its keys are read here,
/// ahead of the rename field, which takes every other press.
final class LookPickerPanel: NSPanel {
    /// A key press, and whether it is the key held down (#2897).
    var onKey: (LookPickerKey, _ repeated: Bool) -> Void = { _, _ in }
    /// Whether the rename field is open: ← → then move its caret.
    var naming: () -> Bool = { false }
    /// Whether the puddle plays: any key or click ends it at once.
    var revealing: () -> Bool = { false }
    var onInterrupt: () -> Void = {}
    var onClose: () -> Void = {}

    override var canBecomeKey: Bool { true }

    #if DEBUG
        /// Tests only: a headless panel is never key.
        var keyedForTesting: Bool?
    #endif

    private var holdsKeys: Bool {
        #if DEBUG
            if let keyedForTesting { return keyedForTesting }
        #endif
        return isKeyWindow
    }

    /// While key, its own ⌘ chords first (⌘S), then the File and
    /// Edit chords handed on (⌘W, the field's edit chords), any
    /// other chord a KiwiDesk menu holds swallowed (gui.md, #2246).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard holdsKeys, event.type == .keyDown,
            event.modifierFlags.contains(.command)
        else { return super.performKeyEquivalent(with: event) }
        if let key = key(for: event) {
            onKey(key, event.isARepeat)
            return true
        }
        return super.performKeyEquivalent(with: event)
            || MainMenu.performPanelChord(event)
            || MainMenu.holdsChord(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onKey(.escape, false)
    }

    /// ⌘W closes, whatever the rename.
    override func performClose(_ sender: Any?) {
        onClose()
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
        case .keyDown:
            if revealing() { return onInterrupt() }
            if let key = key(for: event) {
                onKey(key, event.isARepeat)
                return
            }
        // A click ends the reveal at its release, which the close
        // holds for (#3209); the press itself lands on nothing.
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if revealing() { return }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if revealing() { return onInterrupt() }
        default:
            break
        }
        super.sendEvent(event)
    }

    /// What `event` means here; nil hands it on (the field's typing).
    func key(for event: NSEvent) -> LookPickerKey? {
        Self.key(
            keyCode: event.keyCode,
            character: event.charactersIgnoringModifiers,
            modifiers: event.modifierFlags,
            naming: naming()
        )
    }

    /// ⌘S is matched by the character the key types, so it follows
    /// the keyboard layout as a menu's ⌘S does.
    static func key(
        keyCode: UInt16,
        character: String?,
        modifiers: NSEvent.ModifierFlags,
        naming: Bool
    ) -> LookPickerKey? {
        let flags = modifiers.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        if flags == .command {
            return character?.lowercased() == "s" && !naming ? .save : nil
        }
        guard flags.isEmpty else { return nil }
        switch keyCode {
        case Self.returnKey, Self.enterKey:
            return naming ? .commitName : .wear
        case Self.escapeKey: return .escape
        case Self.leftArrow: return naming ? nil : .step(-1)
        case Self.rightArrow: return naming ? nil : .step(1)
        default: return nil
        }
    }

    static let returnKey: UInt16 = 36
    static let enterKey: UInt16 = 76
    static let escapeKey: UInt16 = 53
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
}
