import AppKit
import CoreGraphics
import Foundation

/// The #677 answer channels that cannot ride an event, and the
/// one narration point every channel shares.
///
/// A REFUSED size produces no notification — macOS only reports
/// a size that changed — and a monocle probe does not even move
/// the window, so an ask can be answered by silence. Waiting
/// for echoes therefore starved the ladder (device QA,
/// 2026-08-18: "several focus changes until it realigns"). The
/// settle probe closes that: a grace after a probing window's
/// animation settles, its frame is read back directly — the
/// `StrandDetector` shape, promoted from QA logger to
/// production answer channel — and the observation runs at
/// delivery. A first refusal additionally re-asks once on its
/// own, so a single visit to a layout completes the whole
/// ladder: dance, probe, confirm, place.
extension KiwiCore {
    /// Grace before the read-back, past the applier's echo
    /// grace so a legitimately-late final echo is not misread —
    /// the `StrandDetector`'s number and argument.
    static let sizeBoundProbeGraceSeconds = 0.6

    /// Wired to `AnimationEngine.onWindowSettled` in Bootstrap.
    /// Gated on the learner still wanting an answer for this
    /// window's last ask AND the state frame not already
    /// showing compliance — so the overwhelmingly common settle
    /// (a complying window whose echo landed) schedules
    /// nothing.
    func scheduleSizeBoundProbe(_ id: WindowID) {
        guard
            let current = state.windows[id]?.frame.size,
            tiler.wantsAnswerProbe(id, currentSize: current)
        else { return }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.sizeBoundProbeGraceSeconds
        ) { [weak self] in
            self?.runSizeBoundProbe(id)
        }
    }

    /// The probe body — named so a test drives it without
    /// waiting out the grace (the `runBorderResync` precedent).
    /// The read rides the #618 coalescer's per-app queues under
    /// its own kind, so it never coalesces against live echoes,
    /// and one stalled app delays only its own probe.
    func runSizeBoundProbe(_ id: WindowID) {
        guard let element = eventLoop.element(for: id),
            let pid = state.windows[id]?.pid
        else { return }
        eventLoop.frameReads.request(
            .settleProbe,
            window: id,
            element: element,
            pid: pid
        ) { [weak self] frame in
            self?.observeSizeAnswer(
                id,
                size: frame.size,
                channel: "settle probe"
            )
        }
    }

    /// One observation, whatever the channel — the settle
    /// probe, a moved echo, a resized echo. A confirmation
    /// places the residue immediately and says so in the log: a
    /// learned bound changes real geometry, and a silent change
    /// is the #611 class of failure. A first refusal (a fresh
    /// candidate) re-asks once, so the ladder completes without
    /// waiting for the user to cause another retile; an updated
    /// candidate does NOT re-ask, which is what keeps a slow
    /// complying app's catch-up from looping probes.
    func observeSizeAnswer(
        _ id: WindowID,
        size: CGSize,
        channel: String
    ) {
        let hadCandidate =
            tiler.candidateSizeBound(for: id) != nil
        if tiler.observeEchoAnswer(id, size: size) {
            onLog(
                "size bound confirmed for window \(id.raw) at "
                    + "\(Int(size.width))x\(Int(size.height)) "
                    + "(\(channel)); placing residue"
            )
            retile()
            return
        }
        if !hadCandidate,
            tiler.candidateSizeBound(for: id) != nil
        {
            onLog(
                "size bound candidate for window \(id.raw) "
                    + "(\(channel)); probing once more"
            )
            retile()
        }
    }
}
