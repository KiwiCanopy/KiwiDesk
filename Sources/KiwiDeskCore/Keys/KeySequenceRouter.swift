import Carbon.HIToolbox
import Foundation

/// The open-or-closed state of the layer's key sequences, and what
/// each key-down does to it (#1871). Pure: the keyboard tap holds
/// one behind its lock and decides on its own thread, so the first
/// key after a leader can never reach the front app
/// (input-and-animation.md).
struct KeySequenceRouter: Sendable {
    /// What a key-down did. Everything but `.pass` swallows it.
    enum Outcome: Equatable, Sendable {
        /// No sequence is open and the key is no leader.
        case pass
        /// A leader opened its sequence, or a step key opened the
        /// next step.
        case stepped
        /// ⌫ went back one step; at the first step it closes.
        case back
        /// esc, the leader again, or ⌫ at the first step.
        case closed
        /// An end key: the sequence closed and its ref fires.
        case fired(ref: Int32)
        /// No key of this step: the panel stays, and the GUI beeps.
        case unbound
        /// A key repeat while open: swallowed, nothing moves.
        case repeated
    }

    private(set) var sequences: [KeySequence] = []
    /// The open sequence, and the index of each step key taken.
    private var open: (sequence: Int, path: [Int])?

    /// Replaces the sequences, closing any that is open: the step
    /// it stood on may be gone.
    mutating func setSequences(_ sequences: [KeySequence]) {
        self.sequences = sequences
        open = nil
    }

    mutating func close() { open = nil }

    /// A tap leader, which the modifier-tap detector decided: opens
    /// its sequence, or closes it when it is the one open.
    mutating func openLeader(_ index: Int) -> Outcome {
        guard sequences.indices.contains(index) else { return .pass }
        if open?.sequence == index {
            open = nil
            return .closed
        }
        open = (index, [])
        return .stepped
    }

    var isOpen: Bool { open != nil }

    /// The open sequence's path, nil while closed.
    var progress: KeySequenceProgress? {
        guard let open else { return nil }
        let sequence = sequences[open.sequence]
        var keys = sequence.steps
        var path: [String] = []
        for index in open.path {
            path.append(keys[index].stored)
            if case .opens(let next) = keys[index].action { keys = next }
        }
        return KeySequenceProgress(leader: sequence.stored, path: path)
    }

    /// Decides one key-down. A step key matches only the chord
    /// recorded for it, held modifiers included (#1871 ▸ step keys).
    mutating func press(
        keyCode: UInt32,
        held: HotkeyModifiers,
        isRepeat: Bool
    ) -> Outcome {
        guard let current = open else {
            guard !isRepeat,
                let index = Self.match(
                    sequences.map { $0.leader.isTap ? nil : $0.leader },
                    keyCode: keyCode,
                    held: held
                )
            else { return .pass }
            open = (index, [])
            return .stepped
        }
        if isRepeat { return .repeated }
        let plain = held.unsided.isEmpty
        if plain, keyCode == UInt32(kVK_Escape) {
            open = nil
            return .closed
        }
        if plain, keyCode == UInt32(kVK_Delete) {
            guard !current.path.isEmpty else {
                open = nil
                return .closed
            }
            open?.path.removeLast()
            return .back
        }
        let sequence = sequences[current.sequence]
        if Self.match([sequence.leader], keyCode: keyCode, held: held) != nil {
            open = nil
            return .closed
        }
        let keys = Self.keys(of: sequence, at: current.path)
        guard
            let index = Self.match(
                keys.map(\.combo),
                keyCode: keyCode,
                held: held
            )
        else { return .unbound }
        switch keys[index].action {
        case .run(let ref):
            open = nil
            return .fired(ref: ref)
        case .opens:
            open?.path.append(index)
            return .stepped
        }
    }

    private static func keys(
        of sequence: KeySequence,
        at path: [Int]
    ) -> [KeySequence.Key] {
        var keys = sequence.steps
        for index in path {
            if case .opens(let next) = keys[index].action { keys = next }
        }
        return keys
    }

    /// The index of the chord a press answers, through the side
    /// tap's one matcher, a keypad digit standing for its twin.
    private static func match(
        _ combos: [KeyCombo?],
        keyCode: UInt32,
        held: HotkeyModifiers
    ) -> Int? {
        let rows = combos.enumerated().flatMap { index, combo in
            guard let combo else { return [SideTapRow]() }
            return
                ([combo.keyCode]
                + [KeypadKeys.keypadTwin(of: combo.keyCode)]
                .compactMap { $0 })
                .map {
                    SideTapRow(
                        keyCode: $0,
                        modifiers: combo.modifiers,
                        id: UInt32(index)
                    )
                }
        }
        return SideTapRow.match(rows, keyCode: keyCode, held: held)
            .map { Int($0.id) }
    }
}
