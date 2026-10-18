import Foundation

/// The Hyper key's layer (#1870): the remapped key arrives as
/// F18, a Carbon hotkey on F18 hears its press and release, and
/// the layer's `hyper+…` combos are registered BARE only while
/// it is held. No keyboard tap, so no Input Monitoring.
struct HyperLayer {
    /// The active layer's rows, registered on each press.
    var rows: [(KeyCombo, Int32)] = []
    /// The F18 registrations. They outlive a layer change: a
    /// re-activation mid-hold must not lose the release.
    var triggerIDs: Set<UInt32> = []
    /// The bare registrations of the current hold.
    var heldIDs: [UInt32] = []
    var isHeld = false
    /// Cancels the watchdog of the current hold.
    var cancelWatchdog: (() -> Void)?

    /// A hold past this ends as if released and is logged — a
    /// stuck layer would swallow its keys system-wide.
    static let maxHoldSeconds: TimeInterval = 30

    /// Every set of the four modifiers, the empty one first:
    /// Hyper combines with any of them (#1870), so the key arrives
    /// whichever are already down.
    static let triggerMasks: [HotkeyModifiers] = (0..<16).map { bits in
        var mask: HotkeyModifiers = []
        if bits & 1 != 0 { mask.insert(.command) }
        if bits & 2 != 0 { mask.insert(.option) }
        if bits & 4 != 0 { mask.insert(.control) }
        if bits & 8 != 0 { mask.insert(.shift) }
        return mask
    }
}

extension KeybindingManager {
    /// Takes the active layer's Hyper rows at the end of every
    /// `activate`. A registrar with no release channel arms
    /// nothing: a held layer that never hears its release
    /// swallows its keys.
    func armHyper(_ rows: [(KeyCombo, Int32)]) {
        hyper.rows = rows
        guard hyperEnabled, !rows.isEmpty else {
            disarmHyperTrigger()
            return
        }
        guard holdGlide.releaseCapable else {
            activationFailures.formUnion(rows.map(\.0))
            onLog("hyper: registrar reports no releases")
            return
        }
        if hyper.triggerIDs.isEmpty { registerHyperTrigger() }
        if hyper.triggerIDs.isEmpty {
            activationFailures.formUnion(rows.map(\.0))
            onLog("hyper: could not register the Hyper key")
        } else if hyper.isHeld {
            registerHeldRows()
        }
    }

    /// The `deactivate` half: the held bare keys go (their refs
    /// may be released), the trigger stays unless Hyper is off or
    /// the hotkeys are suspended for the recorder — which hears F18
    /// only because the suspend disarms it (#2414).
    func dropHyperRows() {
        unregisterHeldRows()
        hyper.rows = []
        if isSuspended || !hyperEnabled { disarmHyperTrigger() }
    }

    func disarmHyperTrigger() {
        hyperReleased()
        for id in hyper.triggerIDs { registrar.unregister(id: id) }
        hyper.triggerIDs = []
    }

    /// Hears every release: the trigger's ends the hold, any other
    /// goes to the glide (#1056).
    func routeRelease(id: UInt32) {
        if hyper.triggerIDs.contains(id) {
            hyperReleased()
        } else {
            holdGlide.released(id: id)
        }
    }

    func hyperPressed() {
        guard !hyper.isHeld, !isSuspended else { return }
        hyper.isHeld = true
        registerHeldRows()
        hyper.cancelWatchdog = hyperSchedule(HyperLayer.maxHoldSeconds) {
            [weak self] in
            guard let self, hyper.isHeld else { return }
            onLog("hyper: held past its bound, released")
            hyperReleased()
        }
    }

    func hyperReleased() {
        guard hyper.isHeld else { return }
        hyper.isHeld = false
        hyper.cancelWatchdog?()
        hyper.cancelWatchdog = nil
        unregisterHeldRows()
    }

    private func registerHyperTrigger() {
        for mask in HyperLayer.triggerMasks {
            let id = registrar.register(
                keyCode: HyperSourceKey.triggerKeyCode,
                modifiers: mask
            ) { [weak self] in
                self?.hyperPressed()
            }
            if let id { hyper.triggerIDs.insert(id) }
        }
    }

    private func registerHeldRows() {
        unregisterHeldRows()
        let before = Set(activeBindings.keys)
        for (combo, ref) in hyper.rows {
            if !registerPhysical(
                code: combo.keyCode,
                combo: combo,
                ref: ref
            ) {
                onLog("hyper: could not register a Hyper shortcut")
            }
            if let twin = KeypadKeys.keypadTwin(of: combo.keyCode) {
                _ = registerPhysical(code: twin, combo: combo, ref: ref)
            }
        }
        hyper.heldIDs = activeBindings.keys.filter {
            !before.contains($0)
        }
    }

    /// The bare keys vanish, so their own releases never come:
    /// end a glide on one here, as a release would.
    private func unregisterHeldRows() {
        for id in hyper.heldIDs {
            holdGlide.released(id: id)
            registrar.unregister(id: id)
            activeBindings[id] = nil
        }
        hyper.heldIDs = []
    }
}
