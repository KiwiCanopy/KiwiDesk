import Testing

@testable import KiwiDeskCore

/// What the runtime tree keeps of a stored sequence (#1871): keys
/// the tap cannot answer are skipped and named, and a key one step
/// holds twice keeps the last, its loser's refs released.
@Suite("Key sequence build")
struct KeySequenceBuildTests {
    private final class Refs {
        var next: Int32 = 1
        var released: [Int32] = []
    }

    private func build(_ steps: [KeyBinding], leader: String = "ctrl+k")
        -> (KeySequence?, [String], Refs)
    {
        let refs = Refs()
        let result = KeySequence.build(
            .sequence(combo: leader, steps: steps),
            compile: { _ in
                defer { refs.next += 1 }
                return refs.next
            },
            release: { refs.released.append($0) }
        )
        return (result.sequence, result.skipped, refs)
    }

    @Test("a tap, Hyper, esc or ⌫ step key is skipped and named")
    func unanswerableStepKeys() {
        let (sequence, skipped, _) = build([
            KeyBinding(combo: "cmd+cmd", lua: "a()"),
            KeyBinding(combo: "hyper+h", lua: "b()"),
            KeyBinding(combo: "escape", lua: "c()"),
            KeyBinding(combo: "delete", lua: "d()"),
            KeyBinding(combo: "shift+escape", lua: "e()"),
        ])
        #expect(skipped == ["cmd+cmd", "hyper+h", "escape", "delete"])
        #expect(sequence?.steps.map(\.stored) == ["shift+escape"])
    }

    @Test("a Hyper leader builds nothing")
    func hyperLeader() {
        let (sequence, skipped, _) = build([], leader: "hyper+k")
        #expect(sequence == nil)
        #expect(skipped == ["hyper+k"])
    }

    @Test("a chord held twice in a step keeps the last, releasing the first")
    func duplicateReleases() {
        let (sequence, skipped, refs) = build([
            .sequence(
                combo: "w",
                steps: [KeyBinding(combo: "h", lua: "a()")]
            ),
            KeyBinding(combo: "w", lua: "b()"),
        ])
        #expect(refs.released == [1])
        #expect(skipped == ["w"])
        #expect(sequence?.steps.map(\.action) == [.run(ref: 2)])
        #expect(sequence?.pruned.steps?.map(\.lua) == ["b()"])
    }

    @Test("the pruned tree keeps each kept key's stored row")
    func prunedKeepsRows() {
        var row = KeyBinding(combo: "t", lua: "x()", kind: .navigation)
        row.desc = "Do it"
        let (sequence, _, _) = build([row, KeyBinding(combo: "bad+", lua: "")])
        #expect(sequence?.pruned.steps == [row])
    }
}
