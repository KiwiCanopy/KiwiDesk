import Foundation

/// The manager's hotkey-activation half, split out at the file
/// ceiling (§2.1): what is registered with the OS right now, and
/// the second registration a keypad twin adds beside it (#1074).
///
/// `activate` and `deactivate` themselves went from private to
/// module-internal to live here, as did `registrar` (a `let`) and
/// the SETTERS of `activeBindings` and `activationFailures`,
/// which this file writes. Nothing else was loosened: `layers`
/// and `suspended` stay private and are read through their
/// existing accessors (`bindings(for:)`, `isSuspended`), because
/// `layers` owns the Lua registry refs that `bind`, `defineLayer`,
/// `replaceLayers` and `reset` are careful to release — an
/// internal setter there would drop the compiler's enforcement of
/// that ownership for no gain. The same seam
/// `KeybindingManager+HoldGlide.swift` took for `holdGlide`.
extension KeybindingManager {
    func deactivate() {
        // The ids are about to vanish, so no release can ever
        // arrive to stop a live glide — end it here (#1056).
        holdGlide.cancelRun()
        for id in activeBindings.keys {
            registrar.unregister(id: id)
        }
        activeBindings = [:]
    }

    func activate(_ layer: String) {
        deactivate()
        activationFailures = []
        // A recorder is armed: keep the table current but
        // register nothing, so testing a shortcut can't fire.
        guard !isSuspended else { return }
        for (combo, ref) in bindings(for: layer) {
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
            // A keypad digit IS its number-row twin (#1074), so
            // one binding claims a SECOND physical key — but
            // only once the authored key has landed. Registering
            // the twin after the authored code was refused would
            // leave the keypad firing a binding the Settings
            // caption calls ungranted, so the report and the
            // keyboard would disagree. A twin's OWN refusal is
            // not the binding's — the shortcut still works from
            // the row — so it is never reported.
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
    }

    /// Registers ONE physical key for `combo` and records it as
    /// live. False when the OS refused the registration.
    ///
    /// Each physical key needs its OWN box: the handler carries
    /// its registration id through it, filled the moment
    /// `register` returns and never re-derived after the fire,
    /// where the Lua body may have rebuilt the table and minted
    /// fresh ids for the same ref+combo (#1056 review). A box
    /// shared between a key and its keypad twin would hand the
    /// second press the first's id, and the hold-glide ladder
    /// keys its whole run by that id.
    private func registerPhysical(
        code: UInt32,
        combo: KeyCombo,
        ref: Int32
    ) -> Bool {
        let box = RegistrationBox()
        let id = registrar.register(
            keyCode: code,
            modifiers: combo.modifiers
        ) { [weak self] in
            self?.pressFire(ref: ref, combo: combo, id: box.id)
        }
        guard let id else { return false }
        box.id = id
        activeBindings[id] = LiveBinding(ref: ref, combo: combo)
        return true
    }
}
