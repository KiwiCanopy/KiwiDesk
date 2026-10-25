import Foundation

/// What the side tap last did (#2601), for the Settings row; the
/// GUI narrates it (#96).
public enum SideTapStatus: Equatable, Sendable {
    /// No sided shortcut needs it, or the switch is off.
    case off
    case running
    /// macOS refused the tap, which a missing Accessibility grant
    /// looks like; sided shortcuts fire from neither side.
    case refused
}

/// The side tap's rows for KeybindingManager (#2601): every
/// either-side shortcut stays a Carbon hotkey, and only the chords
/// a sided shortcut names move to the tap while the switch is on.
extension KeybindingManager {
    /// The either-side chords whose rows the tap answers: those a
    /// sided row in `layer` names, while the switch is on. An
    /// either-side row on such a chord moves with it, so its press
    /// on the other side never races Carbon.
    func tappedChords(in layer: String) -> Set<KeyCombo> {
        guard modifierSides else { return [] }
        return Set(
            bindings(for: layer).map(\.0)
                .filter {
                    $0.modifiers.isSided && !$0.modifiers.contains(.hyper)
                }
                .map(\.unsided)
        )
    }

    /// Hands the tap its rows, building it for the first and
    /// stopping it with the last, so no row means no tap.
    func armSideTap(_ rows: [(KeyCombo, Int32)]) {
        guard !rows.isEmpty else {
            sideTap?.stop()
            sideTap = nil
            sideTapStatus = .off
            return
        }
        var tapRows: [SideTapRow] = []
        for (combo, ref) in rows {
            var codes = [combo.keyCode]
            // A keypad digit is its number-row twin (#1074).
            if let twin = KeypadKeys.keypadTwin(of: combo.keyCode) {
                codes.append(twin)
            }
            for code in codes {
                nextSideID &+= 1
                sideBindings[nextSideID] = LiveBinding(ref: ref, combo: combo)
                tapRows.append(
                    SideTapRow(
                        keyCode: code,
                        modifiers: combo.modifiers,
                        id: nextSideID
                    )
                )
            }
        }
        if sideTap == nil {
            sideTap = makeSideTap(
                { [weak self] id in
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self?.sideFire(id) }
                    }
                },
                { [weak self] line in
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self?.onLog(line) }
                    }
                }
            )
            onLog(
                sideTap == nil
                    ? "modifier side tap: refused by macOS (Accessibility?)"
                    : "modifier side tap: installed"
            )
        }
        sideTapStatus = sideTap == nil ? .refused : .running
        sideTap?.setRows(tapRows)
    }

    /// A press the tap answered: fires the binding as a Carbon
    /// press does, with no hold glide, since the tap reports no
    /// release.
    func sideFire(_ id: UInt32) {
        guard !isSuspended, let live = sideBindings[id] else { return }
        pressFire(ref: live.ref, combo: live.combo, id: nil)
    }
}
