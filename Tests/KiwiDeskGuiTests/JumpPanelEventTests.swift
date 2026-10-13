import AppKit
import Testing

@testable import KiwiDesk

/// The panel reads its keys ahead of the search field (#1875) —
/// save while an input method composes, when Return commits the
/// composition, Esc cancels it and the arrows pick a candidate.
@Suite("Jump to window panel events")
@MainActor
struct JumpPanelEventTests {
    private func keyDown(_ code: UInt16, _ characters: String) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: code
        )!
    }

    private func panel() -> (JumpPanel, NSTextView) {
        let panel = JumpPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        let field = NSTextView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 40)
        )
        panel.contentView?.addSubview(field)
        panel.makeFirstResponder(field)
        return (panel, field)
    }

    @Test("Return and the arrows reach the panel, not the field")
    func panelReadsItsKeys() {
        let (panel, _) = panel()
        var keys: [JumpKey] = []
        panel.onKey = { keys.append($0) }
        panel.sendEvent(keyDown(36, "\r"))
        panel.sendEvent(keyDown(125, ""))
        #expect(keys == [.pick(moveHere: false), .step(1)])
    }

    @Test("while an input method composes, every key is the field's")
    func compositionKeepsItsKeys() {
        let (panel, field) = panel()
        var keys: [JumpKey] = []
        panel.onKey = { keys.append($0) }
        field.setMarkedText(
            "にほ",
            selectedRange: NSRange(location: 2, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(panel.composing)
        panel.sendEvent(keyDown(36, "\r"))
        #expect(keys.isEmpty)
    }

    @Test("modifier changes reach the panel")
    func modifiersReachThePanel() {
        let (panel, _) = panel()
        var flags: [NSEvent.ModifierFlags] = []
        panel.onModifiers = { flags.append($0) }
        let event = NSEvent.keyEvent(
            with: .flagsChanged,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 55
        )!
        panel.sendEvent(event)
        #expect(flags.map { $0.contains(.command) } == [true])
    }

    /// AppKit offers a ⌘ key to the menus before `keyDown`, and
    /// KiwiDesk's "Settings… ⌘," took ⌘, from the Shortcuts and
    /// Layouts sides (#2246): the panel claims its own chord there.
    @Test("⌘, reaches a side before the app menu's Settings…")
    func commandCommaIsTheSides() {
        let (panel, _) = panel()
        var keys: [JumpKey] = []
        panel.onKey = { keys.append($0) }
        let comma = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: ",",
            charactersIgnoringModifiers: ",",
            isARepeat: false,
            keyCode: 43
        )!
        for scope in [JumpScope.shortcuts, .layouts] {
            panel.scope = { scope }
            #expect(panel.performKeyEquivalent(with: comma))
        }
        #expect(keys == [.settings, .settings])
        // Windows answers no ⌘, of its own.
        panel.scope = { .windows }
        _ = panel.performKeyEquivalent(with: comma)
        #expect(keys.count == 2)
    }
}
