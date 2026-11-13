import Foundation

/// Key sequences for KeybindingManager (#1871): kept per layer
/// beside the Carbon table, answered by the keyboard tap.
extension KeybindingManager {
    /// Defined layer names in stable order for GUI import (#4): a
    /// layer holding only sequences is one too (#1871).
    public var definedLayers: [String] {
        let others = Set(pressLayers).union(sequences.keys)
            .filter { $0 != Self.defaultLayer }
            .sorted()
        return [Self.defaultLayer] + others
    }

    /// Defines `sequence` in `layer`, replacing one on the same
    /// leader there and releasing its refs.
    func defineSequence(_ sequence: KeySequence, in layer: String) {
        var held = sequences[layer] ?? []
        let replaced = held.filter { $0.leader == sequence.leader }
        held.removeAll { $0.leader == sequence.leader }
        held.append(sequence)
        sequences[layer] = held
        releaseSequences([layer: replaced])
        if currentLayer == layer { activate(layer) }
    }

    /// The sequences `layer` holds, in definition order.
    func sequences(for layer: String) -> [KeySequence] {
        sequences[layer] ?? []
    }

    /// New scroll keys reach a running tap alone, so an open
    /// sequence stays open; the next arming carries them too.
    func scrollKeysChanged(from old: KiwiHubKeys) {
        guard sequenceScrollKeys != old else { return }
        keyboardTap?.setSequenceScrollKeys(sequenceScrollKeys)
    }

    /// The shortcuts macOS answers and their live chords, read once
    /// per arming (#3173): the router's pass chords and the step-key
    /// warning share the snapshot.
    func systemChords() -> [(combo: KeyCombo, shortcut: SystemShortcut)] {
        if let answeredChords { return answeredChords }
        let read = SystemShortcuts.answered(reading: readSymbolicHotkey)
        answeredChords = read
        return read
    }

    func releaseSequences(_ held: [String: [KeySequence]]) {
        guard let lua else { return }
        for sequence in held.values.joined() {
            sequence.refs.forEach { lua.release(ref: $0) }
        }
    }

    /// An end key the tap answered: fires it as a Carbon press
    /// does, with no hold glide, since the tap reports no release.
    /// An end key is never disabled on a failure: the hint panel
    /// reads the stored tree, so a dropped key would be listed and
    /// beep. Its failure is logged at each press.
    func sequenceFire(ref: Int32) {
        guard !isSuspended else { return }
        // The router closed at the fire: an end key's own Space
        // switch must not close the next sequence already typed.
        firingEndKey = true
        defer { firingEndKey = false }
        firePress(id: nil) {
            if let error = call(ref: ref) {
                onLog("key sequence: end key failed: \(error)")
            }
        }
    }
}

/// What the keyboard tap decided for an open sequence, handed to
/// the main actor (#1871): the outcome and where the sequence then
/// stood, both read on the tap thread at the press.
struct KeySequenceDecision: Equatable, Sendable {
    var outcome: KeySequenceRouter.Outcome
    var progress: KeySequenceProgress?
    /// The epoch it was made in (`sequenceGeneration`): one made
    /// before newer rows or a main close is dropped.
    var generation: UInt64 = 0
}

extension KeybindingManager {
    /// Acts on one decision the tap made: the hint panel follows
    /// the path, an end key fires, an unbound key beeps.
    func sequenceDecided(_ decision: KeySequenceDecision) {
        guard decision.generation == sequenceGeneration else { return }
        switch decision.outcome {
        case .pass, .repeated:
            return
        case .stepped, .back:
            sequenceOpen = true
            onSequenceProgress(decision.progress)
        case .closed, .passed(closing: true):
            noteSequenceClosed()
        case .passed(closing: false):
            return
        case .scroll(let scroll):
            onSequenceScroll(scroll)
        case .fired(let ref):
            noteSequenceClosed()
            sequenceFire(ref: ref)
        case .unbound:
            beep()
        }
    }

    /// Closes an open sequence from the main actor — a click, a
    /// Space switch (#1871 ▸ hint panel). The tap reads the request
    /// at its next press, so the decision stays on its thread.
    func closeSequence() {
        // Asked even while the panel is shut: a leader may already be
        // on its way here.
        guard !firingEndKey, let keyboardTap,
            !sequences(for: currentLayer).isEmpty
        else { return }
        // A new epoch: whatever the tap decided before it is dropped.
        sequenceGeneration &+= 1
        keyboardTap.requestSequenceClose(generation: sequenceGeneration)
        noteSequenceClosed()
    }

    func noteSequenceClosed() {
        guard sequenceOpen else { return }
        sequenceOpen = false
        onSequenceProgress(nil)
    }
}
