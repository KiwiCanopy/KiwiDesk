import Foundation

/// What the keyboard tap last did (#2601, #1872), for the sides
/// row, which narrates it while the switch is on (#96). A refused
/// tap's modifier-tap rows are told through `activationFailures`.
public enum SideTapStatus: Equatable, Sendable {
    /// No row needs it: no sided chord with the switch on, and no
    /// modifier tap.
    case off
    case running
    /// macOS refused the tap, which a missing Accessibility grant
    /// looks like; its chords fall back to Carbon either-side. A
    /// tap macOS disabled as slow turns itself back on, so this is
    /// the one trouble the Settings row narrates.
    case refused
}

/// The keyboard tap's rows for KeybindingManager, as
/// `KeyboardTapArming` sorts them (#3278): every either-side
/// shortcut stays a Carbon hotkey, only the chords a sided shortcut
/// or leader names move to the tap while the switch is on (#2601),
/// and every modifier tap rides it (#1872).
extension KeybindingManager {
    /// Hands the keyboard tap its rows per consumer, building it for
    /// the first consumer, rebuilding it when the set of consumers
    /// changes and stopping it with the last, so no row means no
    /// tap. False where rows wanted a tap macOS refused.
    func armKeyboardTap(
        _ arming: KeyboardTapArming<Int32, KeySequence>
    ) -> Bool {
        tapBindings = [:]
        sequenceGeneration &+= 1
        answeredChords = nil
        let sequences = arming.leaders.map(\.1)
        let rows = KeyboardTapRows(
            sides: sideTapRows(arming.sides),
            taps: arming.rows(for: .modifierTaps).map { combo, armed in
                switch armed {
                case .row(let ref):
                    ModifierTapRow(
                        combo: combo,
                        id: liveTapID(combo, ref),
                        opensKiwiHubSide: kiwiHubSideRefs.contains(ref)
                    )
                // A tap leader is detected as any tap is (#1871).
                case .leader(let index, _):
                    ModifierTapRow(
                        combo: combo,
                        id: KeyboardTap.leaderID(index)
                    )
                }
            },
            sequences: sequences,
            sequencePassing: sequences.isEmpty
                ? .none : .of(systemChords()),
            sequenceScrollKeys: sequenceScrollKeys,
            sequenceGeneration: sequenceGeneration
        )
        let wanted = rows.consumers
        guard !wanted.isEmpty else {
            dropKeyboardTap()
            sideTapStatus = .off
            return true
        }
        guard !keyboardTapRefused else {
            tapBindings = [:]
            dropKeyboardTap()
            sideTapStatus = .refused
            return false
        }
        if keyboardTap?.consumers != wanted {
            dropKeyboardTap()
            keyboardTap = makeKeyboardTap(
                wanted,
                { [weak self] id in
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self?.tapFire(id) }
                    }
                },
                { [weak self] line in
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self?.onLog(line) }
                    }
                }
            )
            keyboardTap?.holdTaps(modifierTapHold)
            onLog(
                keyboardTap == nil
                    ? "keyboard tap: refused by macOS (Accessibility?)"
                    : "keyboard tap: installed"
            )
        }
        guard let keyboardTap else {
            keyboardTapRefused = true
            tapBindings = [:]
            sideTapStatus = .refused
            return false
        }
        keyboardTap.setRows(rows)
        sideTapStatus = .running
        return true
    }

    private func dropKeyboardTap() {
        keyboardTap?.stop()
        keyboardTap = nil
    }

    /// The side rows, a keypad digit with its number-row twin
    /// (#1074).
    private func sideTapRows(_ rows: [(KeyCombo, Int32)]) -> [SideTapRow] {
        rows.flatMap { combo, ref in
            var codes = [combo.keyCode]
            if let twin = KeypadKeys.keypadTwin(of: combo.keyCode) {
                codes.append(twin)
            }
            return codes.map {
                SideTapRow(
                    keyCode: $0,
                    modifiers: combo.modifiers,
                    id: liveTapID(combo, ref)
                )
            }
        }
    }

    private func liveTapID(_ combo: KeyCombo, _ ref: Int32) -> UInt32 {
        nextTapID &+= 1
        // Ids from `KeyboardTap.leaderBase` up are the sequences'.
        if nextTapID >= KeyboardTap.leaderBase { nextTapID = 1 }
        tapBindings[nextTapID] = LiveBinding(ref: ref, combo: combo)
        return nextTapID
    }

    /// Asks macOS for the tap again — at `KiwiCore.start()`, the
    /// door a granted Accessibility comes through.
    func retryKeyboardTap() {
        guard keyboardTapRefused else { return }
        keyboardTapRefused = false
        activate(currentLayer)
    }

    /// A press or tap the keyboard tap answered: fires the binding
    /// as a Carbon press does, with no hold glide, since the tap
    /// reports no release.
    func tapFire(_ id: UInt32) {
        if id == KeyboardTap.sequenceFireID {
            keyboardTap?.drainSequenceDecisions().forEach(sequenceDecided)
            return
        }
        guard !isSuspended, let live = tapBindings[id] else { return }
        pressFire(ref: live.ref, combo: live.combo, id: nil)
    }
}

extension KeybindingManager {
    /// Releases one binding's ref and its KiwiHub side mark, since
    /// Lua reuses a freed ref for the next binding (#1229).
    func releaseBinding(_ ref: Int32) {
        lua?.release(ref: ref)
        kiwiHubSideRefs.remove(ref)
    }
}
