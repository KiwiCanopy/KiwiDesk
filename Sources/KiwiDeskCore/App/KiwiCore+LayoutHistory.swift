import Foundation

/// The layout undo recorder's state (#3515): the stacks and the
/// brackets that are open. One per core.
final class LayoutHistoryLedger {
    var history = LayoutUndoStacks()
    /// Open `recordingLayoutStep` brackets; only the outermost
    /// records, so a key's Lua body is one step.
    var depth = 0
    /// Each open drag's arrangement at its first move, keyed by
    /// the dragged window.
    var gestures: [WindowID: [SpaceID: SpaceArrangement]] = [:]
    /// An undo or redo ran inside the open bracket: its change is
    /// the stacks' own, so the bracket records nothing.
    var tookStep = false
}

/// Recording layout undo steps (#3515). A step is taken around a
/// user act — a command, a key's fire, a drag, an App Bar
/// reorder — by snapshotting every Space before and diffing after.
/// One changed Space is a plain step; two that trade members are a
/// linked move; anything else clears those Spaces' history, as
/// does a change no bracket saw, which the next undo finds.
extension KiwiCore {
    /// Taps of one label closer than this are one step.
    static let layoutUndoQuietGap: TimeInterval = 1.0

    /// Every Space's arrangement now.
    func layoutArrangements() -> [SpaceID: SpaceArrangement] {
        let sizing = sessionSizingOfEverySpace()
        var out: [SpaceID: SpaceArrangement] = [:]
        for space in state.workspaces.allSpaces {
            guard let sized = sizing[space.id] else { continue }
            out[space.id] = SpaceArrangement(space, sizing: sized)
        }
        return out
    }

    /// Runs `body` as one undo step named `label`; nested inside
    /// another bracket or an open drag, it records nothing itself.
    func recordingLayoutStep<T>(_ label: String, _ body: () -> T) -> T {
        let ledger = layoutHistory
        guard ledger.depth == 0, ledger.gestures.isEmpty else {
            ledger.depth += 1
            defer { ledger.depth -= 1 }
            return body()
        }
        let before = layoutArrangements()
        ledger.depth = 1
        defer { ledger.depth = 0 }
        let result = body()
        commitLayoutStep(label, before: before)
        return result
    }

    /// Opens `window`'s drag bracket at its first move.
    func beginLayoutGesture(_ window: WindowID) {
        guard layoutHistory.gestures[window] == nil else { return }
        layoutHistory.gestures[window] = layoutArrangements()
    }

    /// Closes `window`'s drag bracket at its drop.
    func endLayoutGesture(_ window: WindowID) {
        let ledger = layoutHistory
        guard let before = ledger.gestures.removeValue(forKey: window)
        else { return }
        commitLayoutStep("drag", before: before)
    }

    /// Drops `window`'s drag bracket on an abnormal end; whatever
    /// it changed reads as unrecorded, so the next undo refuses.
    func abandonLayoutGesture(_ window: WindowID) {
        layoutHistory.gestures[window] = nil
    }

    private func commitLayoutStep(
        _ label: String,
        before: [SpaceID: SpaceArrangement]
    ) {
        if layoutHistory.tookStep {
            layoutHistory.tookStep = false
            return
        }
        let after = layoutArrangements()
        let changed = Set(before.keys).union(after.keys)
            .filter { before[$0] != after[$0] }
        guard !changed.isEmpty else { return }
        var history = layoutHistory.history
        defer { layoutHistory.history = history }
        history.prune(keeping: Set(after.keys))
        let old = before.filter { changed.contains($0.key) }
        let new = after.filter { changed.contains($0.key) }
        guard Self.isUndoable(old, new) else {
            changed.forEach { history.clear($0) }
            return
        }
        history.record(
            label: label,
            at: wallClock(),
            before: old,
            after: new,
            mergingWithin: Self.layoutUndoQuietGap
        )
    }

    /// One Space that kept its members, or two that traded them —
    /// every Space present on both sides.
    static func isUndoable(
        _ before: [SpaceID: SpaceArrangement],
        _ after: [SpaceID: SpaceArrangement]
    ) -> Bool {
        guard (1...2).contains(before.count),
            Set(before.keys) == Set(after.keys)
        else { return false }
        func members(_ side: [SpaceID: SpaceArrangement]) -> [WindowID] {
            side.values.flatMap(\.windows)
        }
        let old = members(before)
        let new = members(after)
        return old.count == new.count && Set(old) == Set(new)
    }
}
