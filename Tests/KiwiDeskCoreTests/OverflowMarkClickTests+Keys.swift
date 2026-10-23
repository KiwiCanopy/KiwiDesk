import AppKit
import Testing

@testable import KiwiDeskCore

/// The overflow list's keyboard (#2563): arrows, Return, Escape, any
/// other key and a chord — split from the suite at the §2.1 ceiling.
extension OverflowMarkClickTests {
    @Test("Escape closes the list; the arrows walk its rows")
    func keysOnTheList() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let panel = rig.peek.panel
        #expect(panel.panel?.canBecomeKey == true)
        #expect(panel.morphKey(125))
        #expect(panel.body.hovered == 0)
        #expect(panel.morphKey(125))
        #expect(panel.body.hovered == 1)
        #expect(panel.morphKey(126))
        #expect(panel.body.hovered == 0)
        #expect(panel.morphKey(53))
        #expect(rig.peek.shown == nil)
    }

    /// A chord while the list is key never reaches KiwiDesk's menu:
    /// ⌘Q is the user's for the app beneath (gui.md).
    @Test("A chord closes the list and quits nothing")
    func chordIsSwallowed() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        let panel = try #require(rig.peek.panel.panel)
        let quit = try Self.key(12, "q", .command)
        // An arrow reaches the same door first and must pass on to
        // `keyDown`, which walks the rows.
        let down = try Self.key(125, "", [.numericPad, .function])
        #expect(!panel.performKeyEquivalent(with: down))
        #expect(rig.peek.shown != nil)
        #expect(panel.performKeyEquivalent(with: quit))
        #expect(rig.peek.shown == nil)
    }

    /// A key the list does not use closes it rather than beeping:
    /// the user is typing for the app beneath.
    @Test("Any other key closes the list")
    func otherKeyCloses() throws {
        let rig = Rig()
        defer { rig.close() }
        try rig.click()
        #expect(rig.peek.panel.morphKey(0))
        #expect(rig.peek.shown == nil)
    }

    static func key(
        _ code: UInt16,
        _ chars: String,
        _ flags: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: chars,
                charactersIgnoringModifiers: chars,
                isARepeat: false,
                keyCode: code
            )
        )
    }
}
