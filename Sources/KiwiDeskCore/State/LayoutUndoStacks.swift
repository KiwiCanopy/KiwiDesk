import Foundation

/// One layout undo step (#3515): every Space a change touched,
/// before and after. A step naming two Spaces is a move between
/// them and sits on both Spaces' stacks.
public struct LayoutStep: Sendable, Equatable {
    public let id: UInt64
    /// What recorded it; consecutive steps of one label inside the
    /// quiet gap merge, so a held or tapped key is one step.
    public var label: String
    public var stamp: Date
    public var before: [SpaceID: SpaceArrangement]
    public var after: [SpaceID: SpaceArrangement]

    public var spaces: Set<SpaceID> { Set(before.keys) }
}

/// The per-Space undo and redo stacks (#3515), session-only and
/// pure. A linked step is acted on only from the top of every
/// stack it names; removing it from one stack cuts each partner's
/// stack at it, since nothing below could validate.
public struct LayoutUndoStacks: Sendable {
    public enum Stack: Sendable { case undo, redo }

    /// Why a step can or cannot be taken from a Space now.
    public enum Candidate: Sendable, Equatable {
        case empty
        /// A linked step not on top of every partner's stack.
        case blocked
        case ready(LayoutStep)
    }

    /// Steps kept per Space and stack.
    public static let depth = 20

    private(set) var undo: [SpaceID: [LayoutStep]] = [:]
    private(set) var redo: [SpaceID: [LayoutStep]] = [:]
    private var nextID: UInt64 = 1

    public init() {}

    /// Records a change, merged into the step below it when that
    /// step names the same Spaces and label, ended within `gap`,
    /// and its after is this change's before. A new change clears
    /// the redo stacks of the Spaces it names.
    public mutating func record(
        label: String,
        at stamp: Date,
        before: [SpaceID: SpaceArrangement],
        after: [SpaceID: SpaceArrangement],
        mergingWithin gap: TimeInterval
    ) {
        let spaces = Set(before.keys)
        for space in spaces { clear(.redo, of: space) }
        if case .ready(var top) = candidate(.undo, of: spaces.first),
            top.spaces == spaces, top.label == label,
            stamp.timeIntervalSince(top.stamp) < gap,
            top.after == before
        {
            pop(.undo, top)
            guard top.before != after else { return }
            top.after = after
            top.stamp = stamp
            push(.undo, top)
            return
        }
        let step = LayoutStep(
            id: nextID,
            label: label,
            stamp: stamp,
            before: before,
            after: after
        )
        nextID += 1
        push(.undo, step)
    }

    /// The step on top of `space`'s stack, if every Space it names
    /// has it on top too.
    public func candidate(_ stack: Stack, of space: SpaceID?)
        -> Candidate
    {
        guard let space, let top = steps(stack)[space]?.last else {
            return .empty
        }
        let aligned = top.spaces.allSatisfy {
            steps(stack)[$0]?.last?.id == top.id
        }
        return aligned ? .ready(top) : .blocked
    }

    /// Moves `step` from the top of its undo stacks to its redo
    /// stacks, or back.
    public mutating func take(_ step: LayoutStep, from stack: Stack) {
        pop(stack, step)
        push(stack == .undo ? .redo : .undo, step)
    }

    /// Clears both of `space`'s stacks, cutting each partner of a
    /// linked step at it.
    public mutating func clear(_ space: SpaceID) {
        clear(.undo, of: space)
        clear(.redo, of: space)
    }

    /// Drops the stacks of every Space not in `live`.
    public mutating func prune(keeping live: Set<SpaceID>) {
        for space in Set(undo.keys).union(redo.keys)
        where !live.contains(space) {
            clear(space)
        }
    }

    private func steps(_ stack: Stack) -> [SpaceID: [LayoutStep]] {
        stack == .undo ? undo : redo
    }

    private mutating func edit(
        _ stack: Stack,
        _ body: (inout [SpaceID: [LayoutStep]]) -> Void
    ) {
        if stack == .undo { body(&undo) } else { body(&redo) }
    }

    private mutating func push(_ stack: Stack, _ step: LayoutStep) {
        var evicted: [UInt64] = []
        edit(stack) { stacks in
            for space in step.spaces {
                stacks[space, default: []].append(step)
                if let first = stacks[space]?.first,
                    stacks[space]!.count > Self.depth
                {
                    evicted.append(first.id)
                }
            }
        }
        cut(stack, at: Set(evicted))
    }

    private mutating func pop(_ stack: Stack, _ step: LayoutStep) {
        edit(stack) { stacks in
            for space in step.spaces where stacks[space]?.last == step {
                stacks[space]?.removeLast()
            }
        }
    }

    private mutating func clear(_ stack: Stack, of space: SpaceID) {
        guard let ids = steps(stack)[space]?.map(\.id), !ids.isEmpty
        else { return }
        cut(stack, at: Set(ids))
    }

    /// Removes each step in `ids`, and everything below it, from
    /// every stack holding it; the linked steps that removes are
    /// cut from their partners in turn.
    private mutating func cut(_ stack: Stack, at ids: Set<UInt64>) {
        var pending = ids
        var done: Set<UInt64> = []
        while let id = pending.popFirst() {
            done.insert(id)
            edit(stack) { stacks in
                for (space, list) in stacks {
                    let index = list.firstIndex { $0.id == id }
                    guard let index else { continue }
                    for removed in list[...index]
                    where !done.contains(removed.id) {
                        pending.insert(removed.id)
                    }
                    let kept = Array(list[(index + 1)...])
                    stacks[space] = kept.isEmpty ? nil : kept
                }
            }
        }
    }
}
