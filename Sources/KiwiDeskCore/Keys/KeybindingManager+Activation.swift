import Foundation

/// Hotkey activation and OS registration for KeybindingManager
/// (`KeypadKeys`, #1074).
extension KeybindingManager {
    func deactivate() {
        holdGlide.cancelRun()
        for id in activeBindings.keys {
            registrar.unregister(id: id)
        }
        activeBindings = [:]
    }

    func activate(_ layer: String) {
        deactivate()
        activationFailures = []
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

    /// Registers physical key for combo (`KeypadKeys`, #1056).
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
