import Testing

@testable import KiwiDeskCore

/// The Sides pull-down's choices (#2614): each sided modifier on
/// its left key, its right key or either side; Hyper, the Hyper
/// key's own modifier and a single tap's either side refused.
@Suite("Picking a side after recording (#2614)")
struct KeyComboSidePickTests {
    private func combo(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    @Test("one modifier's side moves, the others keep theirs")
    func perModifier() throws {
        let chord = try combo("lctrl+ropt+j")
        #expect(chord.pickableSideKinds(hyperKey: nil) == [.control, .option])
        let either = try #require(
            chord.pickingSide(nil, of: .option, hyperKey: nil)
        )
        #expect(either.comboString() == "lctrl+option+j")
        let left = try #require(
            chord.pickingSide(.left, of: .option, hyperKey: nil)
        )
        #expect(left.comboString() == "lctrl+lopt+j")
        let right = try #require(
            try combo("cmd+h").pickingSide(.right, of: .command, hyperKey: nil)
        )
        #expect(right == (try combo("rcmd+h")))
    }

    @Test("Hyper takes no side; a single tap takes either too")
    func refusals() throws {
        let hyper = try combo("hyper+cmd+h")
        #expect(hyper.pickableSideKinds(hyperKey: nil).isEmpty)
        #expect(hyper.pickingSide(.left, of: .command, hyperKey: nil) == nil)
        let single = try combo("rcmd")
        // Either side by choice (#3259).
        #expect(
            single.pickingSide(nil, of: .command, hyperKey: nil)
                == (try combo("cmd"))
        )
        #expect(
            single.pickingSide(.left, of: .command, hyperKey: nil)
                == (try combo("lcmd"))
        )
        #expect(
            try combo("rcmd+rcmd").pickingSide(
                nil,
                of: .command,
                hyperKey: nil
            )
                == (try combo("cmd+cmd"))
        )
        // A modifier the chord does not hold has no side to pick.
        #expect(
            try combo("cmd+h").pickingSide(.left, of: .shift, hyperKey: nil)
                == nil
        )
    }

    @Test("the Hyper key's own modifier takes no side (#2601 ▸ 4)")
    func hyperKeyModifier() throws {
        let chord = try combo("cmd+opt+h")
        #expect(
            chord.pickableSideKinds(hyperKey: .rightCommand) == [.option]
        )
        #expect(
            chord.pickingSide(.right, of: .command, hyperKey: .rightCommand)
                == nil
        )
        #expect(!KeyCombo.takesSide(.command, hyperKey: .rightCommand))
        #expect(KeyCombo.takesSide(.option, hyperKey: .rightCommand))
        #expect(KeyCombo.takesSide(.command, hyperKey: nil))
    }
}
