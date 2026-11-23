import Foundation

/// The layout undo recorder's state (#3515): the stacks and the
/// brackets that are open. One per core.
final class LayoutHistoryLedger {
    /// An open bracket that spans turns: a drag or a held glide.
    struct Open {
        var label: String
        var at: Date
        var before: [SpaceID: SpaceArrangement]
    }

    var history = LayoutUndoStacks()
    /// Open `recordingLayoutStep` brackets; only the outermost
    /// records, so a key's Lua body is one step.
    var depth = 0
    /// Each open drag, keyed by the dragged window.
    var gestures: [WindowID: Open] = [:]
    /// The held key's glide, from its first frame to its end.
    var glide: Open?
    /// The last key fire's label, which its glide records under so
    /// the hold merges into the press.
    var lastFireLabel = ""
    /// An undo or redo ran inside the open bracket: its change is
    /// the stacks' own, so the bracket records nothing.
    var tookStep = false
    /// A bracket that may not be undone ran inside the open one —
    /// a config load inside `reload_config` — so the whole step
    /// only clears.
    var tainted = false

    /// Whether a bracket is open around the code running now.
    var isOpen: Bool { depth > 0 || !gestures.isEmpty || glide != nil }
}

/// Recording layout undo steps (#3515). A step is taken around a
/// user act — a command, a key's fire and its glide, a drag, an
/// App Bar reorder — by snapshotting every Space before and
/// diffing after. A changed Space that kept its members and its
/// sizing key is a plain step; two that trade members are one
/// linked step; anything else clears those Spaces' history, as
/// does a change no bracket saw, which the next undo finds.
extension KiwiCore {
    /// Taps of one label closer than this are one step.
    static let layoutUndoQuietGap: TimeInterval = 1.0

    /// Each key's fire is one step under its own label (#3515), its
    /// glide recording under the same. Wired at bootstrap, not
    /// with the machine seams: no OS is touched.
    func wireLayoutUndoScope() {
        keys.fireScope = { [weak self] label, fire in
            guard let self else { return fire() }
            self.layoutHistory.lastFireLabel = label
            self.recordingLayoutStep(label, fire)
        }
    }

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
    /// another bracket, it records nothing itself. Not `undoable`,
    /// it only clears the history of every Space it changed — a
    /// config load.
    func recordingLayoutStep<T>(
        _ label: String,
        undoable: Bool = true,
        _ body: () -> T
    ) -> T {
        let ledger = layoutHistory
        // A glide whose end was missed must not hold every later
        // step nested.
        if ledger.glide != nil, !keys.holdGlide.isGliding {
            ledger.glide = nil
        }
        guard !ledger.isOpen else {
            if !undoable { ledger.tainted = true }
            ledger.depth += 1
            defer { ledger.depth -= 1 }
            return body()
        }
        let open = LayoutHistoryLedger.Open(
            label: label,
            at: wallClock(),
            before: layoutArrangements()
        )
        ledger.depth = 1
        ledger.tookStep = false
        ledger.tainted = false
        defer { ledger.depth = 0 }
        let result = body()
        commitLayoutStep(open, undoable: undoable)
        return result
    }

    /// Opens `window`'s drag bracket at its first move.
    func beginLayoutGesture(_ window: WindowID) {
        guard layoutHistory.gestures[window] == nil else { return }
        layoutHistory.gestures[window] = .init(
            label: "drag",
            at: wallClock(),
            before: layoutArrangements()
        )
    }

    /// Closes `window`'s drag bracket at its drop.
    func endLayoutGesture(_ window: WindowID) {
        let ledger = layoutHistory
        guard let open = ledger.gestures.removeValue(forKey: window)
        else { return }
        commitLayoutStep(open, undoable: true)
    }

    /// Drops `window`'s drag bracket on an end no drop follows;
    /// whatever it changed reads as unrecorded, so the next undo
    /// refuses.
    func abandonLayoutGesture(_ window: WindowID) {
        layoutHistory.gestures[window] = nil
    }

    /// Opens the held key's glide bracket at its first frame, under
    /// the press's label and from the moment the glide began.
    func beginLayoutGlide() {
        let ledger = layoutHistory
        guard ledger.glide == nil else { return }
        ledger.glide = .init(
            label: ledger.lastFireLabel,
            at: wallClock(),
            before: layoutArrangements()
        )
    }

    /// Closes the glide bracket when the hold ends.
    func endLayoutGlide() {
        guard let open = layoutHistory.glide else { return }
        layoutHistory.glide = nil
        commitLayoutStep(open, undoable: true)
    }

    private func commitLayoutStep(
        _ open: LayoutHistoryLedger.Open,
        undoable: Bool
    ) {
        let ledger = layoutHistory
        let undoable = undoable && !ledger.tainted
        ledger.tainted = false
        guard !ledger.tookStep else {
            ledger.tookStep = false
            return
        }
        let after = layoutArrangements()
        let changed = Set(open.before.keys).union(after.keys)
            .filter { open.before[$0] != after[$0] }
        guard !changed.isEmpty else { return }
        var history = ledger.history
        defer { ledger.history = history }
        history.prune(keeping: Set(after.keys))
        let old = open.before.filter { changed.contains($0.key) }
        let new = after.filter { changed.contains($0.key) }
        guard undoable, Self.isUndoable(old, new) else {
            changed.forEach { history.clear($0) }
            return
        }
        history.record(
            label: open.label,
            at: open.at,
            before: old,
            after: new,
            mergingWithin: Self.layoutUndoQuietGap
        )
    }

    /// One Space that kept its members, or two that traded them —
    /// every Space on both sides with its sizing key unchanged,
    /// since a step across a Desktop or arrangement change would
    /// put one arrangement's sizes under the other's.
    static func isUndoable(
        _ before: [SpaceID: SpaceArrangement],
        _ after: [SpaceID: SpaceArrangement]
    ) -> Bool {
        guard (1...2).contains(before.count),
            Set(before.keys) == Set(after.keys),
            before.allSatisfy({
                after[$0.key]?.sizing.key == $0.value.sizing.key
            })
        else { return false }
        func members(_ side: [SpaceID: SpaceArrangement]) -> [WindowID] {
            side.values.flatMap(\.windows)
        }
        let old = members(before)
        let new = members(after)
        return old.count == new.count && Set(old) == Set(new)
    }
}
