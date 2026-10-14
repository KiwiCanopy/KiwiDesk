import Foundation

/// The Hyper key's layer (#1870): the remapped key arrives as
/// F18, a Carbon hotkey on F18 hears its press and release, and
/// the layer's `hyper+…` combos are registered BARE only while
/// it is held. No keyboard tap, so no Input Monitoring.
struct HyperLayer {
    /// The armed layer's rows, registered on each press.
    var rows: [(KeyCombo, Int32)] = []
    /// The F18 registrations, one per modifier set, so a press
    /// made while another modifier is down still arrives.
    var triggerIDs: Set<UInt32> = []
    /// The bare registrations of the current hold.
    var heldIDs: [UInt32] = []
    var isHeld = false
    /// Ends a hold whose release never arrived.
    var watchdog: DispatchWorkItem?

    /// A hold past this ends as if released and is logged — a
    /// stuck layer would swallow its keys system-wide.
    static let maxHoldSeconds: TimeInterval = 30
}

extension KeybindingManager {
    /// Registers the trigger for `rows` when the Hyper key is on;
    /// called at the end of every `activate`.
    /// A registrar with no release channel arms nothing: a held
    /// layer that never hears its release swallows its keys.
    func armHyper(_ rows: [(KeyCombo, Int32)]) {
        guard hyperEnabled, !rows.isEmpty else { return }
        guard holdGlide.releaseCapable else {
            activationFailures.formUnion(rows.map(\.0))
            onLog("hyper: registrar reports no releases")
            return
        }
        hyper.rows = rows
        for mask in Self.triggerMasks {
            let id = registrar.register(
                keyCode: HyperSourceKey.triggerKeyCode,
                modifiers: mask
            ) { [weak self] in
                self?.hyperPressed()
            }
            if let id { hyper.triggerIDs.insert(id) }
        }
        if hyper.triggerIDs.isEmpty {
            activationFailures.formUnion(rows.map(\.0))
            onLog("hyper: could not register the Hyper key")
        }
    }

    /// Drops the trigger and any held layer; part of `deactivate`.
    func disarmHyper() {
        hyperReleased()
        for id in hyper.triggerIDs { registrar.unregister(id: id) }
        hyper = HyperLayer()
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
        let watchdog = DispatchWorkItem { [weak self] in
            guard let self, hyper.isHeld else { return }
            onLog("hyper: held past its bound, released")
            hyperReleased()
        }
        hyper.watchdog = watchdog
        DispatchQueue.main.asyncAfter(
            deadline: .now() + HyperLayer.maxHoldSeconds,
            execute: watchdog
        )
    }

    func hyperReleased() {
        guard hyper.isHeld else { return }
        hyper.isHeld = false
        hyper.watchdog?.cancel()
        hyper.watchdog = nil
        // The bare keys vanish, so their own releases never come:
        // end a glide on one here, as a release would.
        for id in hyper.heldIDs {
            holdGlide.released(id: id)
            registrar.unregister(id: id)
            activeBindings[id] = nil
        }
        hyper.heldIDs = []
    }

    /// Every set of the four modifiers, the empty one first.
    static let triggerMasks: [HotkeyModifiers] = (0..<16).map { bits in
        var mask: HotkeyModifiers = []
        if bits & 1 != 0 { mask.insert(.command) }
        if bits & 2 != 0 { mask.insert(.option) }
        if bits & 4 != 0 { mask.insert(.control) }
        if bits & 8 != 0 { mask.insert(.shift) }
        return mask
    }
}
