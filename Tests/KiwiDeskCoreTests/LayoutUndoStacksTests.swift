import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure undo stacks (#3515): merging, the depth cap, and the
/// partner cut a linked step owes.
@Suite("Layout undo stacks (#3515)")
struct LayoutUndoStacksTests {
    private let one = SpaceID("1")
    private let two = SpaceID("2")
    private let now = Date(timeIntervalSince1970: 1000)

    private func arrangement(_ ids: [UInt32]) -> SpaceArrangement {
        let space = Space(id: SpaceID("x"), windows: ids.map(WindowID.init))
        return SpaceArrangement(
            space,
            sizing: SpaceSizing(
                key: SessionSizingKey(desktop: nil, arrangement: nil),
                ratios: SessionRatios()
            )
        )
    }

    private func record(
        _ stacks: inout LayoutUndoStacks,
        _ spaces: [SpaceID: ([UInt32], [UInt32])],
        label: String = "a",
        at offset: TimeInterval = 0
    ) {
        stacks.record(
            label: label,
            at: now.addingTimeInterval(offset),
            before: spaces.mapValues { arrangement($0.0) },
            after: spaces.mapValues { arrangement($0.1) },
            mergingWithin: 1
        )
    }

    private func undoCount(_ stacks: LayoutUndoStacks, _ space: SpaceID)
        -> Int
    {
        var copy = stacks
        var count = 0
        while case .ready(let step) = copy.candidate(.undo, of: space) {
            copy.take(step, from: .undo)
            count += 1
        }
        return count
    }

    @Test("taps of one label inside the gap merge; others do not")
    func merging() {
        var stacks = LayoutUndoStacks()
        record(&stacks, [one: ([1, 2, 3], [2, 1, 3])])
        record(&stacks, [one: ([2, 1, 3], [2, 3, 1])], at: 0.5)
        #expect(undoCount(stacks, one) == 1)
        record(&stacks, [one: ([2, 3, 1], [3, 2, 1])], label: "b", at: 0.6)
        #expect(undoCount(stacks, one) == 2)
        record(&stacks, [one: ([3, 2, 1], [1, 2, 3])], label: "b", at: 5)
        #expect(undoCount(stacks, one) == 3)
    }

    @Test("a merge back to the start leaves no step")
    func mergeToNothing() {
        var stacks = LayoutUndoStacks()
        record(&stacks, [one: ([1, 2], [2, 1])])
        record(&stacks, [one: ([2, 1], [1, 2])], at: 0.2)
        #expect(stacks.candidate(.undo, of: one) == .empty)
    }

    @Test("the depth caps each stack")
    func depthCap() {
        var stacks = LayoutUndoStacks()
        for index in 0..<(LayoutUndoStacks.depth + 5) {
            let even = index.isMultiple(of: 2)
            record(
                &stacks,
                [one: (even ? [1, 2] : [2, 1], even ? [2, 1] : [1, 2])],
                label: "\(index)"
            )
        }
        #expect(undoCount(stacks, one) == LayoutUndoStacks.depth)
    }

    @Test("clearing one side of a linked step cuts the partner")
    func partnerCut() {
        var stacks = LayoutUndoStacks()
        record(&stacks, [two: ([5], [6])], label: "old")
        record(&stacks, [one: ([1], []), two: ([6], [6, 1])], label: "m")
        record(&stacks, [two: ([6, 1], [1, 6])], label: "new")
        stacks.clear(one)
        // Space 2 keeps only the step above the linked one.
        #expect(undoCount(stacks, two) == 1)
        var after = stacks
        if case .ready(let top) = after.candidate(.undo, of: two) {
            after.take(top, from: .undo)
        }
        #expect(after.candidate(.undo, of: two) == .empty)
    }

    @Test("a cut cascades through a linked step below it")
    func cutCascades() {
        let three = SpaceID("3")
        var stacks = LayoutUndoStacks()
        record(&stacks, [two: ([5], []), three: ([], [5])], label: "far")
        record(&stacks, [one: ([1], []), two: ([], [1])], label: "m")
        stacks.clear(one)
        #expect(stacks.candidate(.undo, of: two) == .empty)
        #expect(stacks.candidate(.undo, of: three) == .empty)
    }

    @Test("a new change clears the redo of the Spaces it names")
    func recordClearsRedo() {
        var stacks = LayoutUndoStacks()
        record(&stacks, [one: ([1, 2], [2, 1])])
        guard case .ready(let step) = stacks.candidate(.undo, of: one)
        else {
            Issue.record("no step")
            return
        }
        stacks.take(step, from: .undo)
        #expect(stacks.candidate(.redo, of: one) == .ready(step))
        record(&stacks, [one: ([1, 2], [1, 3, 2])], label: "b", at: 5)
        #expect(stacks.candidate(.redo, of: one) == .empty)
    }

    @Test("a linked step not on top of a partner is blocked")
    func blocked() {
        var stacks = LayoutUndoStacks()
        record(&stacks, [one: ([1], []), two: ([], [1])], label: "m")
        record(&stacks, [two: ([1], [1])], label: "x")
        #expect(stacks.candidate(.undo, of: one) == .blocked)
    }
}
