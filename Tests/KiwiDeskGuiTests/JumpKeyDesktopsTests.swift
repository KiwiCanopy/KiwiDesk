import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktops side's own keys (#1229): ⌘↓ ⌘↑ open and leave a
/// Space, ↩ reads its modifier (⇧ a window moves, ⌥ Swap here, ⌃
/// and follow, ⌘ pick up), and Lua's alternatives reach them — on
/// that side alone, every other side keeping its keys.
@Suite("Desktops side keys")
struct JumpKeyDesktopsTests {
    private static let up: UInt16 = 126
    private static let down: UInt16 = 125
    private static let o: UInt16 = 31
    private static let j: UInt16 = 38

    private static var keys: KiwiHubKeys {
        var keys = KiwiHubKeys()
        keys.openSpace = "control+o"
        keys.follow = "control+command+j"
        return keys
    }

    private func key(
        _ code: UInt16,
        _ modifiers: NSEvent.ModifierFlags,
        scope: JumpScope = .desktops
    ) -> JumpKey? {
        JumpKey.of(
            keyCode: code,
            modifiers: modifiers,
            scope: scope,
            naming: false,
            keys: Self.keys
        )
    }

    @Test("⌘↓ and ⌘↑ open and leave a Space on Desktops only")
    func openAndLeave() {
        #expect(key(Self.down, .command) == .openSpace)
        #expect(key(Self.up, .command) == .leaveSpace)
        #expect(key(Self.down, []) == .step(1))
        for scope in [JumpScope.windows, .shortcuts, .view] {
            #expect(key(Self.down, .command, scope: scope) == .step(1))
        }
    }

    @Test("↩ reads its modifier on Desktops")
    func returnTable() {
        let ret = JumpKey.returnKey
        #expect(key(ret, []) == .pick(moveHere: false))
        #expect(key(ret, .shift) == .pick(moveHere: true))
        #expect(key(ret, .option) == .swapHere)
        #expect(key(ret, .control) == .follow)
        #expect(key(ret, .command) == .pickUp)
        #expect(key(ret, [.control, .option]) == .dead)
        // Elsewhere ⌃↩ and ⌘↩ stay what they were.
        #expect(key(ret, .control, scope: .windows) == .dead)
        #expect(key(ret, .command, scope: .view) == nil)
    }

    @Test("Lua's alternatives reach the side's keys there alone")
    func alternatives() {
        #expect(key(Self.o, .control) == .openSpace)
        #expect(key(Self.o, .control, scope: .windows) == nil)
        #expect(key(Self.j, [.control, .command]) == .follow)
    }
}
