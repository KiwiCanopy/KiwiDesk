import Foundation

/// Hotkey activation and OS registration for KeybindingManager
/// (`KeypadKeys`, #1074).
extension KeybindingManager {
    func deactivate() {
        // The ids are about to vanish, so no release can ever
        // arrive to stop a live glide — end it here (#1056).
        holdGlide.cancelRun()
        dropHyperRows()
        for id in activeBindings.keys {
            registrar.unregister(id: id)
        }
        activeBindings = [:]
        // The tap answers nothing while suspended, or it would
        // swallow the sided press the recorder reads (#2601).
        tapBindings = [:]
        keyboardTap?.setRows(.empty)
        // New rows close the tap's open sequence; the panel follows.
        noteSequenceClosed()
    }

    func activate(_ layer: String) {
        deactivate()
        activationFailures = []
        noteHyperShortcuts()
        guard !isSuspended else {
            _ = armKeyboardTap(.empty)
            return
        }
        // Either-side rows first, so a pair collapsing onto one
        // Carbon chord keeps the same one every launch (#2601).
        let rows = bindings(for: layer).sorted {
            ($0.key.modifiers.isSided ? 1 : 0, $0.key.comboString() ?? "")
                < (
                    $1.key.modifiers.isSided ? 1 : 0,
                    $1.key.comboString() ?? ""
                )
        }
        let arming = KeyboardTapArming(
            rows: rows.map { ($0.key, $0.value) },
            leaders: sequences(for: layer).map { ($0.leader, $0) },
            distinguishingSides: modifierSides
        )
        // A sequence's leader takes its chord (#1871).
        for (combo, _) in arming.heldByLeader {
            activationFailures.insert(combo)
            onLog("keybinding: a key sequence's leader holds a chord")
        }
        for (combo, ref) in arming.carbon {
            guard
                registerPhysical(
                    code: combo.keyCode,
                    combo: combo,
                    ref: ref
                )
            else {
                activationFailures.insert(combo)
                onLog(
                    "keybinding conflict: could not "
                        + "register a shortcut in layer "
                        + "'\(layer)'"
                )
                continue
            }
            // A keypad digit IS its number-row twin (#1074) — but
            // register the twin only once the authored key landed,
            // or the keypad fires a binding the Settings caption
            // calls ungranted. A twin's OWN refusal is never
            // reported as the binding's: the shortcut still works
            // from the row.
            if let twin = KeypadKeys.keypadTwin(
                of: combo.keyCode
            ) {
                _ = registerPhysical(
                    code: twin,
                    combo: combo,
                    ref: ref
                )
            }
        }
        armHyper(arming.hyper)
        if !armKeyboardTap(arming) {
            activationFailures.formUnion(arming.taps.map(\.0))
            // A leader has no Carbon fallback: the tap is its door.
            activationFailures.formUnion(arming.leaders.map(\.0))
            // No tap: the chord falls back to Carbon either-side,
            // as with the switch off, and a collapse is refused.
            for (combo, ref) in arming.sides {
                guard
                    registerPhysical(
                        code: combo.keyCode,
                        combo: combo,
                        ref: ref
                    )
                else {
                    activationFailures.insert(combo)
                    continue
                }
                if let twin = KeypadKeys.keypadTwin(of: combo.keyCode) {
                    _ = registerPhysical(code: twin, combo: combo, ref: ref)
                }
            }
        }
    }

    /// Registers ONE physical key for combo. Each physical key
    /// needs its OWN box: the handler carries its registration id,
    /// filled when `register` returns and never re-derived after
    /// the fire (#1056 review) — a box shared with the keypad twin
    /// would hand the second press the first's id, and hold-glide
    /// keys its whole run by that id (`KeypadKeys`).
    /// A Hyper combo registers bare: its modifiers less `hyper`.
    func registerPhysical(
        code: UInt32,
        combo: KeyCombo,
        ref: Int32
    ) -> Bool {
        // A modifier tap is no key Carbon can register (#1872).
        guard !combo.isTap else { return false }
        let box = RegistrationBox()
        let id = registrar.register(
            keyCode: code,
            modifiers: combo.modifiers.subtracting(.hyper)
        ) { [weak self] in
            self?.pressFire(ref: ref, combo: combo, id: box.id)
        }
        guard let id else { return false }
        box.id = id
        activeBindings[id] = LiveBinding(ref: ref, combo: combo)
        return true
    }
}
