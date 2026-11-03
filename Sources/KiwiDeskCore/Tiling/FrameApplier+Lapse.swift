import Foundation

/// The instant lead's lapse sweep (#2882): one sweep for every
/// lead owed, one `instantLeadLapsed` call per sweep that found a
/// lead lapsed unanswered.
extension FrameApplier {
    func scheduleLapseSweep(after delay: TimeInterval) {
        guard !lapseSweepPending else { return }
        lapseSweepPending = true
        scheduleLapse(delay + Self.lapseMargin) { [weak self] in
            self?.sweepLapses()
        }
    }

    /// Reports the leads whose grace passed unanswered, in one call,
    /// and sweeps again for the ones still standing.
    private func sweepLapses() {
        lapseSweepPending = false
        let sweep = instantTargets.sweepLapses(
            within: Self.echoGrace,
            now: clock()
        )
        if sweep.lapsed { instantLeadLapsed() }
        if let next = sweep.nextIn { scheduleLapseSweep(after: next) }
    }
}
