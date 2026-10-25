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
        sideBindings = [:]
        sideTap?.setRows([])
    }

    func activate(_ layer: String) {
        deactivate()
        activationFailures = []
        noteHyperShortcuts()
        guard !isSuspended else {
            armSideTap([])
            return
        }
        var hyperRows: [(KeyCombo, Int32)] = []
        var sideRows: [(KeyCombo, Int32)] = []
        let tapped = tappedChords(in: layer)
        for (combo, ref) in bindings(for: layer) {
            // A Hyper combo registers only while the key is held.
            if combo.modifiers.contains(.hyper) {
                hyperRows.append((combo, ref))
                continue
            }
            if tapped.contains(combo.unsided) {
                sideRows.append((combo, ref))
                continue
            }
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
        armHyper(hyperRows)
        armSideTap(sideRows)
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
