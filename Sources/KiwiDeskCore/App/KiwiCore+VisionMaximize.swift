import Foundation

/// KiwiVision's maximize (#3064): while KiwiVision is on, the
/// focused tiled window fills its screen, or its height or width at
/// the Layout Defaults share. The verdict is derived in
/// `StateCoordinator+VisionFill`; this file mirrors what the look
/// asks into state and owes the plates their settle re-mask.
extension KiwiCore {
    /// `kiwivision.set_maximize(fill)`: a session value, as every
    /// app-wide verb's; the change's own pass lays it out.
    func setVisionMaximize(_ raw: String?) -> CommandResponse {
        guard let raw, let fill = VisionMaximize(rawValue: raw) else {
            return .expected(VisionMaximize.self)
        }
        setAppWide(persisting: false) { $0.visionMaximize = fill }
        return .ok()
    }

    /// What the look asks of state now: nil while KiwiVision is off
    /// or its maximize, through `VisionLook`, is Off.
    var askedVisionFill: VisionFill? {
        let fill = visionLook.maximize
        guard vision.isOn, fill != .off else { return nil }
        return VisionFill(
            axis: fill.axis,
            maximize: tiler.settings.maximize,
            fallbackShape: maximizeScreenShape(of: nil)
        )
    }

    /// Mirrors the asked fill into state at every door that can
    /// change it — on or off, a lens, a live value, the head of
    /// `retile()` for the Layout Defaults table — and, where it
    /// changed outside a pass, runs the pass that grows or returns
    /// the window, its retire naming them.
    func refillVision(retiling: Bool = true) {
        guard state.setVisionFill(askedVisionFill), retiling else {
            return
        }
        retileEndingMaximize([])
    }

    /// `StateCoordinator.retireEndedMaximize`, plus the settle
    /// re-mask a KiwiVision fill change owes: the window left is
    /// still shrinking when its leave fade masks its slot (#2417).
    func retireEndedFills() -> Set<WindowID> {
        let before = state.visionFill.drawn
        let changed = Set(state.retireEndedMaximize())
        if vision.isOn, state.visionFill.drawn != before {
            vision.owesSettleReshape = true
        }
        return changed
    }

    /// Pays the owed re-mask at the late resync, once the springs
    /// have ended and the windows report where they landed.
    func payVisionSettleReshape() {
        guard vision.owesSettleReshape else { return }
        vision.owesSettleReshape = false
        oweVisionReshape(list: false)
    }
}
