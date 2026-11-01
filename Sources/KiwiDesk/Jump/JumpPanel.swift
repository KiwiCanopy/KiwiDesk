import AppKit
import KiwiDeskCore

/// Jump to window's key window (#1875). Borderless, so it opts
/// into key status and answers File ▸ Close itself (#1533). The
/// panel's keys are read here, ahead of the search field: an
/// arrow, Return or a ⌘ digit never reaches the field's editor,
/// and every other press types into it — save while an input
/// method composes, when every key is the composition's.
final class JumpPanel: NSPanel {
    var onCancel: () -> Void = {}
    /// A key press, and whether it is the key held down (#2897).
    var onKey: (JumpKey, _ repeated: Bool) -> Void = { _, _ in }
    var onModifiers: (NSEvent.ModifierFlags) -> Void = { _ in }
    /// The scope the keys are read for (#2229).
    var scope: () -> JumpScope = { .windows }
    /// Whether the field names a profile, so only ↩, Esc and ⇥
    /// are the panel's keys (#2359).
    var naming: () -> Bool = { false }
    /// Lua's alternatives to the navigation keys, read per press
    /// so a `kiwihub.set_key` takes effect at once (#2600).
    var keys: () -> KiwiHubKeys = { KiwiHubKeys() }

    override var canBecomeKey: Bool { true }

    #if DEBUG
        /// Tests only: a headless panel is never key. Production
        /// must not read this.
        var keyedForTesting: Bool?
    #endif

    /// Whether the panel holds the keyboard now.
    private var holdsKeys: Bool {
        #if DEBUG
            if let keyedForTesting { return keyedForTesting }
        #endif
        return isKeyWindow
    }

    /// While key, a ⌘ chord is the panel's own first; then the File
    /// and Edit chords are handed on (⌘W's Close, #1533, the edit
    /// chords); any other chord a KiwiDesk menu holds is swallowed,
    /// which AppKit would otherwise offer those menus — so ⌘Q, ⌘H
    /// or ⌘, aimed at the app in front never quits, hides or opens
    /// KiwiDesk (owner ruling 2026-10-13, #2246).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard holdsKeys, event.type == .keyDown,
            event.modifierFlags.contains(.command)
        else { return super.performKeyEquivalent(with: event) }
        if !composing,
            let key = JumpKey.of(
                keyCode: event.keyCode,
                modifiers: event.modifierFlags,
                scope: scope(),
                naming: naming(),
                keys: keys()
            )
        {
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
                    modifiers: event.modifierFlags,
                    scope: scope(),
                    naming: naming(),
                    keys: keys()
                )
            {
                onKey(key, event.isARepeat)
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }

    /// Whether the field's editor holds marked text: Return then
    /// commits it, Esc cancels it and the arrows pick a candidate.
    var composing: Bool {
        (firstResponder as? NSTextInputClient)?.hasMarkedText() == true
    }
}
