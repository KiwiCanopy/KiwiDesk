import AppKit
import Testing

@testable import KiwiDesk

/// Jump to window's in-panel keys (#1875 ▸ Ruling — keys): fixed,
/// read ahead of the search field, and nil for anything that
/// should type.
@Suite("Jump to window keys")
struct JumpKeyTests {
    private func key(
        _ code: UInt16,
        _ modifiers: NSEvent.ModifierFlags = []
    ) -> JumpKey? {
        JumpKey.of(keyCode: code, modifiers: modifiers)
    }

    @Test("arrows step one row, pages a page")
    func movement() {
        #expect(key(126) == .step(-1))
        #expect(key(125) == .step(1))
        #expect(key(116) == .page(-1))
        #expect(key(121) == .page(1))
        // AppKit flags an arrow `.function` and `.numericPad`;
        // neither may refuse it.
        #expect(key(125, [.function, .numericPad]) == .step(1))
        // A modified arrow belongs to the field's editor.
        #expect(key(126, .shift) == nil)
        #expect(key(126, .command) == nil)
        #expect(key(126, .option) == nil)
    }

    @Test("Return jumps, ⇧Return moves here")
    func pick() {
        #expect(key(36) == .pick(moveHere: false))
        #expect(key(76) == .pick(moveHere: false))
        #expect(key(36, .shift) == .pick(moveHere: true))
        #expect(key(36, .command) == nil)
        #expect(key(36, .control) == nil)
    }

    @Test("⌘1–9 pick by result, ⇧⌘ moves here, a keypad digit too")
    func quick() {
        #expect(key(18, .command) == .quick(0, moveHere: false))
        #expect(key(25, .command) == .quick(8, moveHere: false))
        #expect(key(20, [.command, .shift]) == .quick(2, moveHere: true))
        // Keypad 3 is the number row's 3 (`KeypadKeys`, #1074).
        #expect(key(85, .command) == .quick(2, moveHere: false))
        // ⌘0 is no result; a plain digit types.
        #expect(key(29, .command) == nil)
        #expect(key(18) == nil)
        #expect(key(18, [.command, .option]) == nil)
    }

    @Test("Esc is the escape, Tab stays in the field, letters type")
    func escapeTabAndTyping() {
        #expect(key(53) == .escape)
        #expect(key(48) == .swallow)
        #expect(key(48, .shift) == .swallow)
        #expect(key(48, .control) == .swallow)
        #expect(key(0) == nil)
        #expect(key(0, .shift) == nil)
    }
}
