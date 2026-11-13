import Testing

@testable import KiwiDeskCore

/// Which consumer each row of a layer reaches (#3278): the one
/// sort the manager arms from and the side reach reads.
@Suite("Keyboard tap arming (#3278)")
struct KeyboardTapArmingTests {
    private func combo(_ text: String) throws -> KeyCombo {
        try #require(KeyCombo.parse(text))
    }

    private func arm(
        _ rows: [String],
        leaders: [String] = [],
        sides: Bool = true
    ) throws -> KeyboardTapArming<String, String> {
        KeyboardTapArming(
            rows: try rows.map { (try combo($0), $0) },
            leaders: try leaders.map { (try combo($0), $0) },
            distinguishingSides: sides
        )
    }

    @Test("each row goes to one consumer, in its order")
    func sortsRows() throws {
        let arming = try arm(
            ["ctrl+k", "cmd+cmd", "hyper+h", "rcmd+j", "cmd+j", "opt+l"],
            leaders: ["ctrl+k", "lopt+lopt"]
        )
        #expect(arming.heldByLeader.map(\.1) == ["ctrl+k"])
        #expect(arming.taps.map(\.1) == ["cmd+cmd"])
        #expect(arming.hyper.map(\.1) == ["hyper+h"])
        #expect(arming.sides.map(\.1) == ["rcmd+j", "cmd+j"])
        #expect(arming.carbon.map(\.1) == ["opt+l"])
        #expect(arming.chordLeaders.map(\.1) == ["ctrl+k"])
        #expect(arming.tapLeaders.map(\.index) == [1])
        #expect(arming.tapLeaders.map(\.leader) == ["lopt+lopt"])
    }

    /// A sided chord leader names its chord as a sided row does, so
    /// the either-side row beside it moves onto the tap.
    @Test("a sided chord leader moves its either-side twin to the tap")
    func sidedLeaderTaps() throws {
        let on = try arm(["cmd+h"], leaders: ["lcmd+h"])
        #expect(on.sides.map(\.1) == ["cmd+h"])
        #expect(on.carbon.isEmpty)
        let off = try arm(["cmd+h"], leaders: ["lcmd+h"], sides: false)
        #expect(off.sides.isEmpty)
        #expect(off.carbon.map(\.1) == ["cmd+h"])
        // A tap leader is no chord: the row stays Carbon's.
        let tap = try arm(["cmd+h"], leaders: ["lcmd+lcmd"])
        #expect(tap.carbon.map(\.1) == ["cmd+h"])
    }

    /// The manager arms the tap from the sort: an either-side row
    /// beside a sided chord leader is a side row, not Carbon's.
    @Test("the manager arms what the sort says")
    @MainActor
    func managerArmsTheSort() throws {
        let manager = KeybindingManager(registrar: NoopHotkeyRegistrar())
        manager.onLog = { _ in }
        var made: [FakeKeyboardTap] = []
        manager.makeKeyboardTap = { consumers, _, _ in
            let tap = FakeKeyboardTap(consumers)
            made.append(tap)
            return tap
        }
        manager.modifierSides = true
        manager.bind(try combo("cmd+h"), ref: 1)
        manager.defineSequence(
            KeySequence(
                leader: try combo("lcmd+h"),
                stored: "lcmd+h",
                steps: []
            ),
            in: KeybindingManager.defaultLayer
        )
        let tap = try #require(made.last)
        #expect(tap.rows.map(\.modifiers) == [try combo("cmd+h").modifiers])
        #expect(tap.sequences.map(\.leader) == [try combo("lcmd+h")])
        #expect(manager.activeBindings.isEmpty)
        #expect(manager.activationFailures.isEmpty)
    }
}
