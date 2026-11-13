import ApplicationServices
import Foundation

/// The instant set: one block per set inside the batched EUI hold
/// (#1508), or, latest-wins, at most one block per window waiting,
/// which writes the newest frame when it runs (#3266).
extension FrameApplier {
    /// Applies a frame instantly, with EUI held off around the
    /// set (#881) — one hold for a run of sets queued back to
    /// back, shared with the animation ref-count through
    /// `EnhancedUIHolds` (#1508). Position-only unless `setSize`.
    /// Callers must `animation.cancel(window:)` first (as
    /// `retile` and `stashInactive` do) so a window is never
    /// spring-animated and instant-set at once. `resend` writes
    /// the frame once more after `crossScreenResendDelay` unless a
    /// newer write reached the window first (#2187). `latestWins`
    /// merges into a set already waiting for the window, counted
    /// as coalesced; every other write retires a waiting one.
    func applyInstant(
        _ id: WindowID,
        _ frame: CGRect,
        setSize: Bool,
        resend: Bool = false,
        latestWins: Bool = false
    ) {
        // At enqueue, ahead of the element guard: the overlay sync
        // wants the commanded frame this same turn (#881).
        instantTargets.record(id, frame: frame, now: clock())
        scheduleLapseSweep(after: Self.echoGrace)
        recent.record(id, now: clock())  // as `apply`, #1254
        issued(id, frame)
        pendingResends[id] = resend && setSize ? frame : nil
        // A newer ask: a waiting grab frame never lands after it.
        if !latestWins { _ = latestInstants.take(id) }
        let band = edgeBand(frame, setSize: setSize)
        let run = sizeLedRuns[id]
        let lead = takeLead(id)
        // A held write owes no resend: it lands once, at the
        // slide's landing, on the screen it was sent to (#2524).
        if stageHeld(id, frame, setSize: setSize, band: band, lead: lead) {
            pendingResends[id] = nil
            return
        }
        guard let element = elementProvider(id) else { return }
        guard
            let pid = animatingPid[id] ?? Self.pid(of: element)
        else { return }
        // Our own window moves now, inside the caller's turn: the
        // main queue would run it only after that turn (#1956).
        if pid == getpid(), ownWindowMove(id, frame, setSize) {
            recentStamp(id)
            return
        }
        let asked = PendingFrames.Entry(
            element: element,
            frame: frame,
            setSize: setSize,
            band: band,
            lead: lead
        )
        if latestWins, latestInstants.put(id, asked) {
            meter.add(\.framesCoalesced)
            return
        }
        nonisolated(unsafe) let only = asked
        let store = latestInstants
        let recent = recent
        let clock = clock
        let writer = writer
        let holds = enhancedUI
        let waited = meter.queued()
        holds.noteQueued(
            pid,
            atRest: enhancedUIAtRest(pid),
            instant: true
        )
        queue(for: pid).async {
            waited()
            holds.beginInstant(pid, writer)
            if let entry = latestWins ? store.take(id) : only {
                if let lead = entry.lead {
                    lead.write(entry, writer)
                } else if entry.setSize {
                    EdgeBandWrite.write(
                        entry.frame,
                        entry.element,
                        nearEdgeOf: entry.band,
                        writer: writer
                    )
                } else {
                    writer.setPosition(entry.frame.origin, entry.element)
                }
            }
            holds.endInstant(pid, writer)
            recent.record(id, now: clock())  // as `apply`, #1254
        }
        if pendingResends[id] != nil {
            scheduleResend(crossScreenResendDelay) { [weak self] in
                self?.resendIfCurrent(id, frame, run: run)
            }
        }
    }
}
