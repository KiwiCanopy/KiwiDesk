import Testing

@testable import KiwiDeskCore

/// The Sides pull-down's choices (#2614): each sided modifier on
/// its left key, its right key or either side, Hyper and a single
/// tap's either side refused.
@Suite("Picking a side after recording (#2614)")
struct KeyComboSidePickTests {
    private func combo(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    @Test("one modifier's side moves, the others keep theirs")
    func perModifier() throws {
        let chord = try combo("lctrl+ropt+j")
        #expect(chord.pickableSideKinds == [.control, .option])
        let either = try #require(chord.pickingSide(nil, of: .option))
        #expect(either.comboString() == "lctrl+option+j")
        let left = try #require(chord.pickingSide(.left, of: .option))
        #expect(left.comboString() == "lctrl+lopt+j")
        let plain = try combo("cmd+h")
        let right = try #require(plain.pickingSide(.right, of: .command))
        #expect(right == (try combo("rcmd+h")))
    }

    @Test("Hyper takes no side; a single tap keeps one")
    func refusals() throws {
        #expect(try combo("hyper+cmd+h").pickableSideKinds.isEmpty)
        #expect(
            try combo("hyper+cmd+h").pickingSide(.left, of: .command) == nil
        )
        let single = try combo("rcmd")
        #expect(single.pickingSide(nil, of: .command) == nil)
        #expect(single.pickingSide(.left, of: .command) == (try combo("lcmd")))
        let double = try combo("rcmd+rcmd")
        #expect(
            double.pickingSide(nil, of: .command) == (try combo("cmd+cmd"))
        )
        // A modifier the chord does not hold has no side to pick.
        #expect(try combo("cmd+h").pickingSide(.left, of: .shift) == nil)
    }
}
