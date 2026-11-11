import Carbon.HIToolbox
import Foundation

/// The open-or-closed state of the layer's key sequences, and what
/// each key-down does to it (#1871). Pure: the keyboard tap holds
/// one behind its lock and decides on its own thread, so the first
/// key after a leader can never reach the front app
/// (input-and-animation.md).
struct KeySequenceRouter: Sendable {
    /// What a key-down did. `swallows` says whether the front app
    /// is kept from it.
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
        /// A macOS shortcut while open (#3173): it reaches macOS, and
        /// `closing` closes the sequence first.
        case passed(closing: Bool)
        /// A scroll key while open (#3175): the sheet moves a line or
        /// a page.
        case scroll(KeySequenceScroll)

        var swallows: Bool {
            switch self {
            case .pass, .passed: return false
            case .stepped, .back, .closed, .fired, .unbound, .repeated,
                .scroll:
                return true
            }
        }
    }

    private(set) var sequences: [KeySequence] = []
    /// The macOS shortcuts an open sequence lets through (#3173).
    private(set) var passing = SequencePassChords.none
    /// KiwiHub's second chords for ↑ ↓ Page Up Page Down (#3175):
    /// set apart from the sequences, so a change to them alone
    /// (`KeyboardTapHandle.setSequenceScrollKeys`) closes nothing.
    var scrollKeys = KiwiHubKeys()
    /// The open sequence, and the index of each step key taken.
    private var open: (sequence: Int, path: [Int])?

    /// Replaces the sequences and the macOS shortcuts they let
    /// through, closing any that is open: the step it stood on may
    /// be gone.
    mutating func setSequences(
        _ sequences: [KeySequence],
        passing: SequencePassChords = .none
    ) {
        self.sequences = sequences
        self.passing = passing
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
    /// While open: esc and ⌫, the leader, a step key, a scroll key
    /// (#3175), then a macOS shortcut's tier (#3173), else the beep.
    /// A repeat moves nothing but a scroll and a macOS shortcut.
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
        if isRepeat { return repeated(current, keyCode: keyCode, held: held) }
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
        else {
            return Self.scroll(keyCode: keyCode, held: held, keys: scrollKeys)
                ?? passOrBeep(keyCode: keyCode, held: held)
        }
        switch keys[index].action {
        case .run(let ref):
            open = nil
            return .fired(ref: ref)
        case .opens:
            open?.path.append(index)
            return .stepped
        }
    }

    /// A held key: a scroll repeats and a macOS shortcut passes;
    /// esc, ⌫, the leader and a step key stay still.
    private mutating func repeated(
        _ current: (sequence: Int, path: [Int]),
        keyCode: UInt32,
        held: HotkeyModifiers
    ) -> Outcome {
        let plain = held.unsided.isEmpty
        let fixed = [kVK_Escape, kVK_Delete].map(UInt32.init)
        let sequence = sequences[current.sequence]
        let keys = Self.keys(of: sequence, at: current.path)
        if plain && fixed.contains(keyCode)
            || Self.match([sequence.leader], keyCode: keyCode, held: held)
                != nil
            || Self.match(keys.map(\.combo), keyCode: keyCode, held: held)
                != nil
        {
            return .repeated
        }
        if let scroll = Self.scroll(
            keyCode: keyCode,
            held: held,
            keys: scrollKeys
        ) {
            return scroll
        }
        let pass = passOrBeep(keyCode: keyCode, held: held)
        return pass == .unbound ? .repeated : pass
    }

    /// KiwiHub's navigation keys as the sheet's scroll (#3175): the
    /// plain arrows and page keys, or the user's second chord for
    /// one, matched whole — no ⇧ strip.
    static func scroll(
        keyCode: UInt32,
        held: HotkeyModifiers,
        keys: KiwiHubKeys
    ) -> Outcome? {
        let builtIn: [UInt32: KiwiHubKey] = [
            UInt32(kVK_UpArrow): .up, UInt32(kVK_DownArrow): .down,
            UInt32(kVK_PageUp): .pageUp, UInt32(kVK_PageDown): .pageDown,
        ]
        let key =
            held.unsided.isEmpty
            ? builtIn[keyCode]
            : keys.key(
                for: KeyCombo(keyCode: keyCode, modifiers: held.unsided)
            )
        switch key {
        case .up: return .scroll(.step(-1))
        case .down: return .scroll(.step(1))
        case .pageUp: return .scroll(.page(-1))
        case .pageDown: return .scroll(.page(1))
        default: return nil
        }
    }

    /// A macOS shortcut no step key took: through to macOS, the
    /// sequence closed first where it takes the keyboard.
    private mutating func passOrBeep(
        keyCode: UInt32,
        held: HotkeyModifiers
    ) -> Outcome {
        if Self.match(passing.staysOpen, keyCode: keyCode, held: held) != nil {
            return .passed(closing: false)
        }
        if Self.match(passing.closes, keyCode: keyCode, held: held) != nil {
            open = nil
            return .passed(closing: true)
        }
        return .unbound
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
