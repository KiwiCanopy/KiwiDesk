import Foundation

/// The manager's half of hold-to-repeat (#1056), split out at
/// the file ceiling: the release-channel wiring, the two fire
/// wrappers that bracket a binding run for the `HoldRepeat`
/// ladder, and the passthroughs `KiwiCore` feeds. The ladder
/// itself — eligibility, timing, the refusal stop — lives on
/// `HoldRepeat`.
extension KeybindingManager {
    /// Called once from `init`. The repeat engine arms only
    /// when the registrar can report releases — without that
    /// channel a run would never stop. The press-only
    /// registrar fakes across the test trees stay valid by not
    /// conforming to `HotkeyReleaseReporting`; that the
    /// PRODUCTION default registrar does conform — and so keeps
    /// the feature alive — is pinned by `HoldRepeatSeamTests`,
    /// since every suite here hands in a conforming fake and
    /// would stay green with the live channel lost.
    func wireHoldRepeat(registrar: HotkeyRegistrar) {
        if let reporting =
            registrar as? HotkeyReleaseReporting
        {
            holdRepeat.releaseCapable = true
            reporting.onRelease = { [weak self] id in
                self?.holdRepeat.released(id: id)
            }
        }
        holdRepeat.fire = { [weak self] id in
            self?.fireRepeatTick(id: id)
        }
        holdRepeat.onOverrun = { [weak self] in
            self?.onLog(
                "hold-repeat: run exceeded its bound and was "
                    + "force-ended (release event lost?)"
            )
        }
    }

    /// `KiwiCore.execute` reports every command run inside a
    /// hotkey fire, so the repeat engine can decide eligibility
    /// from what the press actually did — a binding's body is
    /// opaque Lua, so this is the one honest signal.
    public func noteCommand(_ name: String, succeeded: Bool) {
        guard isFiring else { return }
        holdRepeat.noteCommand(name, succeeded: succeeded)
    }

    /// A size-limit refusal cue fired (#933): a held run
    /// stops, so the pill flashes once per hold. Gated on
    /// `isFiring` like `noteCommand` — the same cue funnels
    /// serve the mouse resize end, and a mouse refusal is not
    /// this keyboard run's wall (its own next tick will find
    /// the wall itself if there is one).
    public func noteResizeRefusal() {
        guard isFiring else { return }
        holdRepeat.noteRefusal()
    }

    /// A physical key-down fire: runs the binding, then lets
    /// the repeat engine decide from the fire's own tally
    /// whether holding the chord repeats it. `id` is the
    /// registration the press arrived on, carried from the
    /// registration itself (`RegistrationBox`) — never looked
    /// up after the fire, where the Lua body may have rebuilt
    /// the bindings.
    func pressFire(ref: Int32, combo: KeyCombo, id: UInt32?) {
        let outer = holdRepeat.beginFire()
        fire(ref: ref, combo: combo)
        if let id {
            holdRepeat.endFire(id: id, press: true)
        } else {
            // A press with no id cannot arm, but it is still a
            // new press: the previous run ends — latest wins,
            // unconditionally.
            holdRepeat.cancelRun()
        }
        holdRepeat.restoreTally(outer)
    }

    /// One repeat tick: re-runs the held binding and extends or
    /// ends the run from the tick's own tally.
    func fireRepeatTick(id: UInt32) {
        guard let binding = activeBindings[id] else {
            holdRepeat.cancelRun()
            return
        }
        let outer = holdRepeat.beginFire()
        fire(ref: binding.ref, combo: binding.combo)
        holdRepeat.endFire(id: id, press: false)
        holdRepeat.restoreTally(outer)
    }
}
