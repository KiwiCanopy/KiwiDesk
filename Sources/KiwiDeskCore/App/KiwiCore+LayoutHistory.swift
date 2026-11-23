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
    /// The last key fire's label and the moment its bracket opened,
    /// which its glide records under so the hold merges into the
    /// press whatever the key-repeat delay.
    var lastFire = (label: "", at: Date.distantPast)
    /// The glide ended inside a bracket — a refusal cue mid-frame —
    /// so it records once that bracket unwinds.
    var glideEnded = false
    /// The drag whose drop is running; its bracket stays open
    /// though the coordinator already forgot the gesture.
    var dropping: WindowID?
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
            // A new press ends the hold before it: two acts, two steps.
            self.endLayoutGlide()
            self.layoutHistory.lastFire = (label, self.wallClock())
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
        healOpenBrackets()
        guard !ledger.isOpen else {
            if !undoable { ledger.tainted = true }
            ledger.depth += 1
            let result = body()
            ledger.depth -= 1
            if ledger.depth == 0, ledger.glideEnded { endLayoutGlide() }
            return result
        }
        let open = LayoutHistoryLedger.Open(
            label: label,
            at: wallClock(),
            before: openingSnapshot()
        )
        ledger.depth = 1
        let result = body()
        ledger.depth = 0
        commitLayoutStep(open, undoable: undoable)
        return result
    }

    /// The snapshot an outermost bracket opens with, the flags a
    /// previous bracket may have left behind cleared.
    private func openingSnapshot() -> [SpaceID: SpaceArrangement] {
        layoutHistory.tookStep = false
        layoutHistory.tainted = false
        return layoutArrangements()
    }

    /// Drops a bracket whose end was missed — a glide no longer
    /// running, a drag the coordinator forgot with no drop running
    /// — which would otherwise hold every later step nested.
    private func healOpenBrackets() {
        let ledger = layoutHistory
        if ledger.glide != nil, !keys.holdGlide.isGliding,
            ledger.depth == 0
        {
            ledger.glide = nil
            ledger.glideEnded = false
        }
        ledger.gestures = ledger.gestures.filter { id, _ in
            id == ledger.dropping || drag.hasGesture(id)
        }
    }

    /// Opens `window`'s drag bracket at its first move.
    func beginLayoutGesture(_ window: WindowID) {
        guard layoutHistory.gestures[window] == nil else { return }
        let fresh = !layoutHistory.isOpen
        layoutHistory.gestures[window] = .init(
            label: "drag",
            at: wallClock(),
            before: fresh ? openingSnapshot() : layoutArrangements()
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
    /// refuses. A gesture the coordinator drops on its own is
    /// healed at the next bracket instead.
    func abandonLayoutGesture(_ window: WindowID) {
        layoutHistory.gestures[window] = nil
    }

    /// Opens the held key's glide bracket at its first frame, under
    /// the press's label and from the moment the glide began.
    func beginLayoutGlide() {
        let ledger = layoutHistory
        guard ledger.glide == nil else { return }
        let fresh = !ledger.isOpen
        ledger.glide = .init(
            label: ledger.lastFire.label,
            at: ledger.lastFire.at,
            before: fresh ? openingSnapshot() : layoutArrangements()
        )
    }

    /// Closes the glide bracket when the hold ends — once the
    /// command a refusal ended it inside has unwound.
    func endLayoutGlide() {
        let ledger = layoutHistory
        guard let open = ledger.glide else { return }
        guard ledger.depth == 0 else {
            ledger.glideEnded = true
            return
        }
        ledger.glide = nil
        ledger.glideEnded = false
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
