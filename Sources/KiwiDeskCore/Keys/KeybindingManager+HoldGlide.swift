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

    /// Notifies glide manager of resize limit refusal cue (#933, 2026-08-29).
    public func noteResizeRefusal() {
        guard isFiring || holdGlide.isGliding else { return }
        holdGlide.noteRefusal()
    }

    /// Executes key-down binding and arms glide if chord is held (#1056,
    /// #1082).
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
