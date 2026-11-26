import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure undo stacks (#3515): merging, the depth cap, the
/// partner cut a linked step owes, and the rebase over a window
/// opening or closing (#3601).
@Suite("Layout undo stacks (#3515)")
struct LayoutUndoStacksTests {
    private let one = SpaceID("1")
    private let two = SpaceID("2")
    private let now = Date(timeIntervalSince1970: 1000)

    private func arrangement(_ ids: [UInt32]) -> SpaceArrangement {
        let space = Space(id: SpaceID("x"), windows: ids.map(WindowID.init))
        return SpaceArrangement(
            space,
            sessionSizes: SpaceSizing(
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
    private func windows(_ stacks: LayoutUndoStacks, _ space: SpaceID)
        -> [([UInt32], [UInt32])]
    {
        var copy = stacks
        var out: [([UInt32], [UInt32])] = []
        while case .ready(let step) = copy.candidate(.undo, of: space) {
            copy.take(step, from: .undo)
            out.append(
                (
                    step.before[space]?.windows.map(\.raw) ?? [],
                    step.after[space]?.windows.map(\.raw) ?? []
                )
            )
        }
        return out
    }

    @Test("a rebase that empties a step drops it alone")
    func rebaseDropsEmptiedStep() {
        var stacks = LayoutUndoStacks()
        record(&stacks, [one: ([1, 2, 3], [1, 3, 2])], label: "a")
        record(&stacks, [one: ([1, 3, 2], [3, 1, 2])], label: "b", at: 5)
        record(&stacks, [one: ([3, 1, 2], [2, 1, 3])], label: "c", at: 9)
        // Window 1 closes: "b" moved only it, so it changes nothing;
        // the steps on either side of it stay.
        stacks.rebase { _, side in side.removing(WindowID(1)) }
        let left = windows(stacks, one)
        #expect(left.map(\.0) == [[3, 2], [2, 3]])
        #expect(left.map(\.1) == [[2, 3], [3, 2]])
    }

    @Test("a rebase edits every copy of a linked step")
    func rebaseReachesThePartner() {
        var stacks = LayoutUndoStacks()
        record(
            &stacks,
            [one: ([1, 2], [2]), two: ([3], [3, 1])],
            label: "m"
        )
        stacks.rebase { _, side in side.removing(WindowID(3)) }
        guard case .ready(let step) = stacks.candidate(.undo, of: two)
        else {
            Issue.record("the linked step was lost")
            return
        }
        #expect(step.before[two]?.windows == [])
        #expect(step.after[two]?.windows == [WindowID(1)])
        #expect(stacks.candidate(.undo, of: one) == .ready(step))
    }

    @Test("history sits where each top step left the Space")
    func sits() {
        var stacks = LayoutUndoStacks()
        #expect(stacks.sits(one, at: arrangement([9])))
        record(&stacks, [one: ([1, 2], [2, 1])])
        #expect(stacks.sits(one, at: arrangement([2, 1])))
        #expect(!stacks.sits(one, at: arrangement([1, 2])))
        guard case .ready(let step) = stacks.candidate(.undo, of: one)
        else {
            Issue.record("no step")
            return
        }
        stacks.take(step, from: .undo)
        // The redo's before is where an undo left the Space.
        #expect(stacks.sits(one, at: arrangement([1, 2])))
        #expect(!stacks.sits(one, at: arrangement([2, 1])))
    }
    private func placed(
        _ ids: [UInt32],
        _ placement: SpawnPlacement,
        anchor: UInt32?
    ) -> [UInt32] {
        arrangement(ids).inserting(
            WindowID(9),
            placement: placement,
            anchor: anchor.map(WindowID.init),
            from: arrangement(ids + [9])
        ).windows.map(\.raw)
    }

    @Test("an opened window joins each step by its own placement")
    func insertByPlacement() {
        // The ruling's example: beside its anchor in either order.
        #expect(placed([1, 2, 3], .afterFocused, anchor: 1) == [1, 9, 2, 3])
        #expect(placed([2, 1, 3], .afterFocused, anchor: 1) == [2, 1, 9, 3])
        #expect(placed([1, 2, 3], .beforeFocused, anchor: 3) == [1, 2, 9, 3])
        #expect(placed([1, 2, 3], .first, anchor: 2) == [9, 1, 2, 3])
        #expect(placed([1, 2, 3], .last, anchor: 2) == [1, 2, 3, 9])
        // An anchor the step does not hold sends it to the end.
        #expect(placed([1, 2], .afterFocused, anchor: 5) == [1, 2, 9])
        #expect(placed([1, 2], .beforeFocused, anchor: 5) == [1, 2, 9])
    }

    @Test("a closed window hands its track break on in each step")
    func removeHandsTheBreak() {
        var side = arrangement([1, 2, 3])
        side.trackBreaks = [WindowID(1), WindowID(2)]
        let removed = side.removing(WindowID(2))
        #expect(removed.windows == [WindowID(1), WindowID(3)])
        #expect(removed.trackBreaks == [WindowID(1), WindowID(3)])
        #expect(side.removing(WindowID(7)) == side)
    }
}
