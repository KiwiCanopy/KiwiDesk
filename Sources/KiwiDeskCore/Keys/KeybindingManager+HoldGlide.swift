import Foundation

/// Keybinding hold-to-glide integration and event routing (#1056, #1082).
extension KeybindingManager {
    /// Whether a held glide is applying right now.
    public var isGliding: Bool { holdGlide.isGliding }

    /// Whether a glide frame's own write is executing right now.
    public var isApplyingGlideStep: Bool {
        holdGlide.isApplyingGlideStep
    }

    /// Connects release event channel to `HoldGlide`
    /// (`HoldGlideEligibilitySeamTests`).
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

    /// Records command executed during hotkey press for glide eligibility.
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

    /// Notifies the glide of a size-limit refusal cue (#933) —
    /// heard during the press fire AND during the glide, which
    /// runs outside any fire. Stated residue (code review,
    /// 2026-08-29): the same `cueResizeRefusal` funnel serves the
    /// MOUSE end, so a mouse refusal during a glide ends the
    /// keyboard hold. Accepted — it needs a drag and a held chord
    /// at once, and the failure is a hold that stops early.
    public func noteResizeRefusal() {
        guard isFiring || holdGlide.isGliding else { return }
        holdGlide.noteRefusal()
    }

    /// Executes the key-down binding, then lets the ladder judge
    /// the fire's tally (#1056/#1082). `id` is CARRIED from the
    /// registration itself, and looked up for EXISTENCE only — the
    /// one question the table still answers honestly after a Lua
    /// body rebuilds the bindings: `bind` inside a body runs
    /// `deactivate`, minting fresh ids, so the release for THIS
    /// press's id will never arrive and a glide armed on it would
    /// run to `maxRunSeconds`. The glide re-issues the captured
    /// command and never looks anything up, so the question must
    /// be asked here — never re-deriving WHICH binding to act on.
    func pressFire(ref: Int32, combo: KeyCombo, id: UInt32?) {
        let outer = holdGlide.beginFire()
        fire(ref: ref, combo: combo)
        if let id, activeBindings[id] != nil {
            holdGlide.endFire(id: id)
        } else {
            holdGlide.cancelRun()
        }
        holdGlide.restoreTally(outer)
    }
}
