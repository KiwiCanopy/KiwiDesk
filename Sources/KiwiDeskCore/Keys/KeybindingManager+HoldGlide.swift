import Foundation

/// The manager's half of hold-to-glide (#1056, retimed #1082),
/// split out at the file ceiling: the release-channel wiring, the
/// fire bracket that hands the ladder one press's tally, and the
/// passthroughs `KiwiCore` feeds. The ladder itself —
/// eligibility, the initial delay, the per-frame glide — lives on
/// `HoldGlide`.
extension KeybindingManager {
    /// Whether a held glide is applying right now. Read by the
    /// refusal gate below and by `KiwiCore.resizeWritesAnimated`,
    /// both of which need the state at a moment when `isFiring`
    /// is false — the glide re-issues its command outside any
    /// binding fire.
    public var isGliding: Bool { holdGlide.isGliding }

    /// Whether a glide frame's own write is executing right now
    /// — the per-WRITE question, which `isGliding` (the hold's
    /// lifetime) answers wrongly. The distinction is argued on
    /// `HoldGlide.isApplyingGlideStep`.
    public var isApplyingGlideStep: Bool {
        holdGlide.isApplyingGlideStep
    }

    /// Called once from `init`. The glide arms only when the
    /// registrar can report releases — without that channel a
    /// hold would never stop. The press-only registrar fakes
    /// across the test trees stay valid by not conforming to
    /// `HotkeyReleaseReporting`; that the PRODUCTION default
    /// registrar does conform — and so keeps the feature alive —
    /// is pinned by `HoldGlideEligibilitySeamTests`, since every suite here
    /// hands in a conforming fake and would stay green with the
    /// live channel lost.
    func wireHoldGlideChannels(registrar: HotkeyRegistrar) {
        if let reporting =
            registrar as? HotkeyReleaseReporting
        {
            holdGlide.releaseCapable = true
            reporting.onRelease = { [weak self] id in
                self?.holdGlide.released(id: id)
            }
        }
        holdGlide.onOverrun = { [weak self] in
            self?.onLog(
                "hold-glide: run exceeded its bound and was "
                    + "force-ended (release event lost?)"
            )
        }
    }

    /// `KiwiCore.execute` reports every command run inside a
    /// hotkey fire, so the glide can decide eligibility from what
    /// the press actually did — a binding's body is opaque Lua,
    /// so this is the one honest signal — and can capture the
    /// arguments it will re-issue.
    public func noteCommand(
        _ name: String,
        args: [JSONValue],
        succeeded: Bool
    ) {
        guard isFiring else { return }
        holdGlide.noteCommand(
            name,
            args: args,
            succeeded: succeeded
        )
    }

    /// A size-limit refusal cue fired (#933): a held run stops,
    /// so the pill flashes once per hold. Heard during the press
    /// fire AND during the glide, which runs outside any fire —
    /// the gate is those two states rather than none.
    ///
    /// The residue that widening buys, stated rather than left
    /// implied (code review, 2026-08-29): the same
    /// `cueResizeRefusal` funnel serves the MOUSE resize end, so
    /// for the glide's duration a mouse refusal now passes this
    /// gate and ends the keyboard hold. Accepted — it needs a
    /// drag and a held chord at once, and the failure is a hold
    /// that stops early rather than one that cannot stop — but it
    /// is a real widening, and the pre-#1082 comment here claimed
    /// the gate excluded exactly this.
    public func noteResizeRefusal() {
        guard isFiring || holdGlide.isGliding else { return }
        holdGlide.noteRefusal()
    }

    /// A physical key-down fire: runs the binding, then lets the
    /// ladder decide from the fire's own tally whether holding
    /// the chord glides it. `id` is the registration the press
    /// arrived on, CARRIED from the registration itself
    /// (`RegistrationBox`) rather than re-derived after the fire,
    /// where the Lua body may have rebuilt the bindings.
    ///
    /// It is looked up here for EXISTENCE only, which is the
    /// opposite question and the one thing the table can still
    /// answer honestly after a rebuild: does the id that will
    /// deliver the release still exist?
    /// A body that REBOUND mid-fire arms nothing, and the test
    /// is that its own registration survived: `bind` inside a
    /// body runs `deactivate`, which mints fresh ids for the
    /// same ref and combo, so the physical release for the id
    /// this press arrived on will never be delivered — and a
    /// glide whose stop channel is gone would run to
    /// `maxRunSeconds` (#1056, re-homed by #1082). Under the
    /// repeat ladder this was caught one layer down, because a
    /// tick looked its registration up in order to re-fire the
    /// binding; the glide re-issues the captured command instead
    /// and never looks anything up, so the question has to be
    /// asked HERE. Existence only — never re-deriving WHICH
    /// binding to act on from a rebuilt table.
    func pressFire(ref: Int32, combo: KeyCombo, id: UInt32?) {
        let outer = holdGlide.beginFire()
        fire(ref: ref, combo: combo)
        if let id, activeBindings[id] != nil {
            holdGlide.endFire(id: id)
        } else {
            // A press with no id — or one whose registration the
            // body replaced — cannot arm, but it is still a new
            // press: the previous run ends, latest wins,
            // unconditionally.
            holdGlide.cancelRun()
        }
        holdGlide.restoreTally(outer)
    }
}
