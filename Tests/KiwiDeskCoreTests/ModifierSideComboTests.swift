import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Sided modifiers in a chord (#2601): Lua spells a side `l`/`r`
/// before a modifier, a chord round-trips through its canonical
/// string, Carbon reads it either-side, and a key event's device
/// flags say which key was held.
@Suite("Modifier sides in a chord (#2601)")
struct ModifierSideComboTests {
    private func parse(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    @Test("every side token parses to its modifier and side")
    func tokens() throws {
        let cases: [(String, ModifierKind, ModifierSide)] = [
            ("lcmd", .command, .left), ("rcmd", .command, .right),
            ("lopt", .option, .left), ("ropt", .option, .right),
            ("lalt", .option, .left), ("ralt", .option, .right),
            ("lshift", .shift, .left), ("rshift", .shift, .right),
            ("lctrl", .control, .left), ("rctrl", .control, .right),
        ]
        for (token, kind, side) in cases {
            let combo = try parse("\(token)+h")
            #expect(combo.modifiers.contains(kind.plain), "\(token)")
            #expect(combo.modifiers.side(of: kind) == side, "\(token)")
            #expect(combo.modifiers.isSided)
        }
        #expect(try !parse("cmd+h").modifiers.isSided)
    }

    @Test(
        "a doubled modifier, a sided Hyper or a long side name: nothing"
    )
    func oneTokenPerModifier() {
        for text in [
            "lcmd+rcmd+h", "cmd+rcmd+h", "lalt+ropt+h", "cmd+command+h",
            "hyper+rcmd+k", "lcommand+h", "roption+h", "rcontrol+h",
        ] {
            #expect(KeyCombo.parse(text) == nil, "\(text)")
        }
    }

    @Test("a sided chord round-trips and is told from either-side")
    func roundTrip() throws {
        for text in ["rcmd+h", "lopt+space", "control+ropt+h", "shift+lcmd+k"]
        {
            let combo = try parse(text)
            let canonical = try #require(combo.comboString())
            #expect(KeyCombo.parse(canonical) == combo, "\(text)")
        }
        #expect(try parse("rcmd+h").comboString() == "rcmd+h")
        #expect(try parse("lcmd+h") != parse("rcmd+h"))
        #expect(try parse("rcmd+h") != parse("cmd+h"))
        #expect(try parse("rcmd+h").unsided == parse("cmd+h"))
        #expect(try parse("cmd+h").comboString() == "command+h")
    }

    @Test("Carbon registers a sided chord either-side")
    func carbonReadsEitherSide() throws {
        let sided = try parse("rcmd+h").modifiers
        #expect(sided.carbonMask == HotkeyModifiers.command.rawValue)
    }

    @Test("device flags name the held side")
    func heldSides() {
        let right = CGEventFlags(
            rawValue: CGEventFlags.maskCommand.rawValue | 0x10
        )
        let held = HotkeyModifiers.held(by: right)
        #expect(held.contains(.command))
        #expect(held.side(of: .command) == .right)
        let leftOpt = CGEventFlags(
            rawValue: CGEventFlags.maskAlternate.rawValue | 0x20
        )
        #expect(HotkeyModifiers.held(by: leftOpt).side(of: .option) == .left)
        let rightCtrl = CGEventFlags(
            rawValue: CGEventFlags.maskControl.rawValue | 0x2000
        )
        #expect(
            HotkeyModifiers.held(by: rightCtrl).side(of: .control) == .right
        )
        let leftShift = CGEventFlags(
            rawValue: CGEventFlags.maskShift.rawValue | 0x02
        )
        #expect(HotkeyModifiers.held(by: leftShift).side(of: .shift) == .left)
    }

    @Test("a sided row answers only its side; either-side answers both")
    func answers() throws {
        let right = HotkeyModifiers.held(
            by: CGEventFlags(
                rawValue: CGEventFlags.maskCommand.rawValue | 0x10
            )
        )
        let left = HotkeyModifiers.held(
            by: CGEventFlags(
                rawValue: CGEventFlags.maskCommand.rawValue | 0x08
            )
        )
        let rcmd = try parse("rcmd+h").modifiers
        let cmd = try parse("cmd+h").modifiers
        #expect(rcmd.answers(right))
        #expect(!rcmd.answers(left))
        #expect(cmd.answers(left) && cmd.answers(right))
        // Another modifier held is another chord.
        let both = right.union(.shift).union(.side(.left, of: .shift))
        #expect(!rcmd.answers(both))
    }

    @Test("the sided row wins on its side, either-side on the other")
    func matchPrefersTheSide() throws {
        let rows = [
            SideTapRow(
                keyCode: 4,
                modifiers: try parse("cmd+h").modifiers,
                id: 1
            ),
            SideTapRow(
                keyCode: 4,
                modifiers: try parse("rcmd+h").modifiers,
                id: 2
            ),
        ]
        let right = HotkeyModifiers.held(
            by: CGEventFlags(
                rawValue: CGEventFlags.maskCommand.rawValue | 0x10
            )
        )
        let left = HotkeyModifiers.held(
            by: CGEventFlags(
                rawValue: CGEventFlags.maskCommand.rawValue | 0x08
            )
        )
        #expect(SideTapRow.match(rows, keyCode: 4, held: right)?.id == 2)
        #expect(SideTapRow.match(rows, keyCode: 4, held: left)?.id == 1)
        #expect(SideTapRow.match(rows, keyCode: 5, held: left) == nil)
    }

    @Test("Carbon's registered chord forgets the side")
    func registeredIsEitherSide() throws {
        #expect(try parse("rcmd+h").registered == parse("cmd+h"))
        #expect(try parse("ctrl+lopt+h").registered == parse("ctrl+opt+h"))
    }

    @Test("a tie between rows breaks the same way whatever their order")
    func tieIsDeterministic() throws {
        let a = SideTapRow(
            keyCode: 4,
            modifiers: try parse("lcmd+opt+h").modifiers,
            id: 1
        )
        let b = SideTapRow(
            keyCode: 4,
            modifiers: try parse("cmd+lopt+h").modifiers,
            id: 2
        )
        let held = a.modifiers.union(b.modifiers)
        let first = SideTapRow.match([a, b], keyCode: 4, held: held)?.id
        let second = SideTapRow.match([b, a], keyCode: 4, held: held)?.id
        #expect(first != nil)
        #expect(first == second)
    }
}
