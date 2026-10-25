import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Lua's alternatives to KiwiHub's navigation keys (#2600): each
/// does its built-in key's move, the built-in keys keep working,
/// and a naming field keeps every press but its own.
@Suite("KiwiHub key alternatives")
struct JumpKeyAlternativeTests {
    private static let n: UInt16 = 45
    private static let p: UInt16 = 35
    private static let d: UInt16 = 2
    private static let u: UInt16 = 32
    private static let f: UInt16 = 3
    private static let b: UInt16 = 11

    private static var keys: KiwiHubKeys {
        var keys = KiwiHubKeys()
        keys.down = "control+n"
        keys.up = "control+p"
        keys.pageDown = "control+d"
        keys.pageUp = "control+u"
        keys.right = "control+f"
        keys.left = "control+b"
        return keys
    }

    private func key(
        _ code: UInt16,
        _ modifiers: NSEvent.ModifierFlags = .control,
        scope: JumpScope = .windows,
        naming: Bool = false
    ) -> JumpKey? {
        JumpKey.of(
            keyCode: code,
            modifiers: modifiers,
            scope: scope,
            naming: naming,
            keys: Self.keys
        )
    }

    @Test("each alternative does its built-in key's move, on every side")
    func moves() {
        for scope in JumpScope.allCases {
            #expect(key(Self.n, scope: scope) == .step(1))
            #expect(key(Self.p, scope: scope) == .step(-1))
            #expect(key(Self.d, scope: scope) == .page(1))
            #expect(key(Self.u, scope: scope) == .page(-1))
        }
    }

    @Test("← and → move only in View; elsewhere they type")
    func sidesOnlyInView() {
        #expect(key(Self.f, scope: .view) == .side(1))
        #expect(key(Self.b, scope: .view) == .side(-1))
        #expect(key(Self.f, scope: .windows) == nil)
        #expect(key(Self.b, scope: .shortcuts) == nil)
    }

    @Test("⇧ held still moves; another modifier does not match")
    func modifiers() {
        #expect(key(Self.n, [.control, .shift]) == .step(1))
        #expect(key(Self.n, [.control, .option]) == nil)
        #expect(key(Self.n, []) == nil)
    }

    @Test("the built-in keys keep working beside the alternatives")
    func builtInsStay() {
        #expect(key(125, []) == .step(1))
        #expect(key(121, []) == .page(1))
        #expect(key(36, []) == .pick(moveHere: false))
    }

    @Test("a naming field keeps the press")
    func namingKeeps() {
        #expect(key(Self.n, scope: .view, naming: true) == nil)
    }
}
