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
    /// How long the body waits between looks.
    static let applyHealPassDelay: Duration = .milliseconds(
        Int(sizeBoundProbeGraceSeconds * 1000) + 200
    )

    /// The longest an apply waits for its answers before the pass
    /// runs anyway, so a read that never lands cannot hold it.
    static let applyHealPassBound: Duration = .seconds(5)

    /// Arms the pass. `retile` calls it for every apply pass that
    /// runs, and the body re-arms through it while the apply's
    /// frames still land, carrying the first arm's `deadline` and
    /// whether the last look found every window at rest. An apply
    /// burst owes one pass, the slot being cancel-and-replace.
    func oweApplyHealPass(
        until deadline: ContinuousClock.Instant? = nil,
        restedAtLastLook: Bool = false
    ) {
        let deadline = deadline ?? .now + Self.applyHealPassBound
        deferred.schedule(.applyHealPass, after: Self.applyHealPassDelay) {
            [weak self] in
            self?.payApplyHealPass(
                until: deadline,
                restedAtLastLook: restedAtLastLook
            )
        }
    }

    /// The body: the pass runs once two looks a delay apart find no
    /// tracked window moving, so the settle probe, which reads a
    /// grace after each window's own settle, has read first — asked
    /// per window, the heal reading every answer — or once the
    /// deadline has passed.
    func payApplyHealPass(
        until deadline: ContinuousClock.Instant,
        restedAtLastLook: Bool
    ) {
        let rests = !applyFramesLanding()
        if ContinuousClock.now < deadline, !(rests && restedAtLastLook) {
            oweApplyHealPass(until: deadline, restedAtLastLook: rests)
            return
        }
        retile()
    }

    /// Whether some tracked window is still moving.
    func applyFramesLanding() -> Bool {
        state.windows.all.contains {
            tiler.animation.isAnimating(window: $0.id)
        }
    }
}
