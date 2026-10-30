import Foundation

/// The ordinary pass an explicit apply owes (#2785). An apply's
/// pass probes past learned bounds, so the split floor heal stands
/// down on it (#1055), and the apply has just reseeded the session
/// ratios (#458). Where every bound is already learned, no answer
/// to the probe retiles, so nothing ran the heal and the split
/// kept the configured ratio over windows whose minimums fit.
/// One `.event` pass, once the apply's frames have landed and the
/// settle probe has read them, runs the heal on what they answered.
extension KiwiCore {
    /// After the settle probe's grace, so its read lands first.
    static let applyHealPassDelay: Duration = .milliseconds(
        Int(sizeBoundProbeGraceSeconds * 1000) + 200
    )

    /// Arms the pass. Called by `retile` for every apply pass that
    /// runs; an apply burst owes one pass, the slot being
    /// cancel-and-replace.
    func oweApplyHealPass() {
        deferred.schedule(.applyHealPass, after: Self.applyHealPassDelay) {
            [weak self] in
            self?.payApplyHealPass()
        }
    }

    /// The body. It waits out any animation still landing the
    /// apply's frames — a global precondition, since the heal reads
    /// every member's answer — by re-arming at its own delay.
    func payApplyHealPass() {
        guard tiler.animation.activeCount == 0 else {
            oweApplyHealPass()
            return
        }
        retile()
    }
}
