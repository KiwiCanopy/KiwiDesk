import Foundation

/// Key sequences for KeybindingManager (#1871): kept per layer
/// beside the Carbon table, answered by the keyboard tap.
extension KeybindingManager {
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

    /// The leaders `layer`'s sequences take, so Carbon never also
    /// registers a press row on one: the sequence wins its chord.
    func sequenceLeaders(in layer: String) -> Set<KeyCombo> {
        Set(sequences(for: layer).map(\.leader))
    }

    func releaseSequences(_ held: [String: [KeySequence]]) {
        guard let lua else { return }
        for sequence in held.values.joined() {
            sequence.refs.forEach { lua.release(ref: $0) }
        }
    }

    /// An end key the tap answered: fires it as a Carbon press
    /// does, with no hold glide, since the tap reports no release.
    func sequenceFire(ref: Int32) {
        guard !isSuspended, let lua else { return }
        // The ref must still be one this layer's sequences hold:
        // a reload between the press and this hop released it.
        guard
            sequences(for: currentLayer).contains(where: {
                $0.refs.contains(ref)
            })
        else { return }
        let outer = holdGlide.beginFire()
        let wasFiring = isFiring
        isFiring = true
        if case .failure(let error) = lua.call(ref: ref) {
            onLog("key sequence: end key failed: \(error)")
        }
        isFiring = wasFiring
        holdGlide.cancelRun()
        holdGlide.restoreTally(outer)
    }
}
