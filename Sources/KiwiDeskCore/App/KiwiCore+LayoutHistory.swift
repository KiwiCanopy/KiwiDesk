import Foundation

/// The layout undo recorder's state (#3515): the stacks, and the
/// one step being built while any act is open. One per core.
final class LayoutHistoryLedger {
    /// An act that holds the step open across turns.
    enum Owner: Hashable {
        case gesture(WindowID)
        case glide
    }

    /// What the open step does when its last act closes. A later,
    /// stronger answer wins: an undo inside it skips, an act that
    /// ended without its close discards, a config load clears.
    enum Disposition: Comparable {
        case record, skip, discard, clear
    }

    /// The step every open act shares.
    struct Pending {
        var label: String
        var at: Date
        var before: [SpaceID: SpaceArrangement]
        var disposition = Disposition.record
    }

    var history = LayoutUndoStacks()
    var pending: Pending?
    /// Synchronous brackets open on the stack now.
    var depth = 0
    /// Acts that span turns and are still open.
    var owners: Set<Owner> = []
    /// The last key fire's label and stamp, which its glide takes,
    /// so the hold merges into the press whatever the repeat delay.
    var lastFire = (label: "", at: Date.distantPast)
    /// Counts gestures, so two drags or reorders inside the quiet
    /// gap stay two steps.
    private var gestureCount = 0

    /// A label no earlier gesture shared: `base` and a count.
    func gestureLabel(_ base: String) -> String {
        gestureCount += 1
        return "\(base) \(gestureCount)"
    }

    /// Raises the open step's disposition to at least `answer`.
    func raise(_ answer: Disposition) {
        guard let current = pending?.disposition, answer > current
        else { return }
        pending?.disposition = answer
    }
}

/// Recording layout undo steps (#3515). Any user act — a command,
/// a key's fire and its glide, a drag, an App Bar reorder — opens
/// the one pending step if none is, snapshotting every Space; the
/// step commits when the last open act closes. A changed Space
/// that kept its members and sizing key is a plain step, two that
/// trade members one linked step; anything else clears those
/// Spaces' history, as does a change no act saw, which the next
/// undo finds.
extension KiwiCore {
    /// Taps of one label closer than this are one step.
    static let layoutUndoQuietGap: TimeInterval = 1.0

    /// Each key's fire is one step under its own label, its glide
    /// recording under the same. Wired at bootstrap, not with the
    /// machine seams: no OS is touched.
    func wireLayoutUndoScope() {
        keys.fireScope = { [weak self] label, fire in
            guard let self else { return fire() }
            // A new press ends the hold before it: two acts, two
            // steps.
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

    /// Runs `body` as one act named `label`. Not `undoable` — a
    /// config load — the step it is part of only clears.
    func recordingLayoutStep<T>(
        _ label: String,
        undoable: Bool = true,
        _ body: () -> T
    ) -> T {
        let ledger = layoutHistory
        openStep(label, at: wallClock())
        if !undoable { ledger.raise(.clear) }
        ledger.depth += 1
        let result = body()
        ledger.depth -= 1
        closeIfIdle()
        return result
    }

    /// Opens `window`'s drag at its first move.
    func beginLayoutGesture(_ window: WindowID) {
        let owner = LayoutHistoryLedger.Owner.gesture(window)
        guard !layoutHistory.owners.contains(owner) else { return }
        openStep(layoutHistory.gestureLabel("drag"), at: wallClock())
        layoutHistory.owners.insert(owner)
    }

    /// Closes `window`'s drag at its drop, `drop` running inside it
    /// so the step stays open though the coordinator already forgot
    /// the gesture.
    func endLayoutGesture(_ window: WindowID, drop: () -> Void) {
        let ledger = layoutHistory
        guard ledger.owners.contains(.gesture(window)) else {
            return drop()
        }
        ledger.depth += 1
        drop()
        ledger.owners.remove(.gesture(window))
        ledger.depth -= 1
        closeIfIdle()
    }

    /// Ends `window`'s drag with no drop: what it changed reads as
    /// unrecorded, so the next undo refuses.
    func abandonLayoutGesture(_ window: WindowID) {
        let owner = LayoutHistoryLedger.Owner.gesture(window)
        guard layoutHistory.owners.remove(owner) != nil else { return }
        layoutHistory.raise(.discard)
        closeIfIdle()
    }

    /// Opens the held key's glide at its first frame, under the
    /// press's label and stamp.
    func beginLayoutGlide() {
        guard !layoutHistory.owners.contains(.glide) else { return }
        let fire = layoutHistory.lastFire
        openStep(fire.label, at: fire.at)
        layoutHistory.owners.insert(.glide)
    }

    /// Closes the glide when the hold ends; inside a command (a
    /// refusal cue mid-frame) the step commits once it unwinds.
    func endLayoutGlide() {
        guard layoutHistory.owners.remove(.glide) != nil else { return }
        closeIfIdle()
    }

    /// Lets an undo or redo inside an open step skip recording it.
    func noteLayoutStepTaken() {
        layoutHistory.raise(.skip)
    }

    /// Opens the pending step if none is, after dropping an act
    /// whose end was missed — a glide no longer running, a drag the
    /// coordinator forgot — which discards the step it held.
    private func openStep(_ label: String, at stamp: Date) {
        let ledger = layoutHistory
        if ledger.depth == 0 {
            let stale = ledger.owners.filter { owner in
                switch owner {
                case .glide: return !keys.holdGlide.isGliding
                case .gesture(let id): return !drag.hasGesture(id)
                }
            }
            if !stale.isEmpty {
                ledger.owners.subtract(stale)
                ledger.raise(.discard)
                closeIfIdle()
            }
        }
        guard ledger.pending == nil else { return }
        ledger.pending = .init(
            label: label,
            at: stamp,
            before: layoutArrangements()
        )
    }

    /// Commits the pending step once no act holds it open.
    private func closeIfIdle() {
        let ledger = layoutHistory
        guard ledger.depth == 0, ledger.owners.isEmpty,
            let open = ledger.pending
        else { return }
        ledger.pending = nil
        guard open.disposition == .record || open.disposition == .clear
        else { return }
        let after = layoutArrangements()
        let changed = Set(open.before.keys).union(after.keys)
            .filter { open.before[$0] != after[$0] }
        guard !changed.isEmpty else { return }
        var history = ledger.history
        defer { ledger.history = history }
        history.prune(keeping: Set(after.keys))
        let old = open.before.filter { changed.contains($0.key) }
        let new = after.filter { changed.contains($0.key) }
        guard open.disposition == .record, Self.isUndoable(old, new)
        else {
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
