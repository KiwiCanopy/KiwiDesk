import CoreGraphics
import Foundation

/// The `.windowResized` side effects — the ring and mark follow,
/// the stash and size-bound bookkeeping, and the gesture or
/// unsolicited-resize hand-off. Split from `KiwiCore+Events.swift`
/// (350-line ceiling, §2); called only from `handle`.
extension KiwiCore {
    func handleWindowResized(
        _ id: WindowID,
        frame: CGRect,
        previous preEventFrame: CGRect?
    ) {
        borders.follow(
            id,
            windowFrame: frame,
            source: .axEcho,
            pin: nil
        )
        stickyMarks.follow(
            id,
            windowFrame: frame,
            source: .axEcho,
            pin: nil
        )
        // Same policy as .windowMoved above: a genuine
        // user resize takes the window over.
        if !tiler.didRecentlySetFrame(id),
            !tiler.looksStashed(frame)
        {
            tiler.forgetStash(id)
        }
        // #677: an echo of our own set is the app's ANSWER
        // to the last ask — observe it now rather than at
        // the next retile, and place the residue (the
        // re-pack, the centering) the moment a bound is
        // confirmed. The confirmation edge fires once per
        // learned entry, so this retile cannot loop on its
        // own echoes.
        var unsolicited = false
        if tiler.askEchoLikely(id) {
            observeSizeAnswer(
                id,
                size: frame.size,
                channel: .resizeEcho
            )
            tiler.clearInstantTarget(id)  // as :104, #881
        } else if !tiler.ledgerExplainsResize(
            id,
            size: frame.size
        ) {
            unsolicited = true
            // A genuine resize stales the learned bound:
            // the user or the app itself changed the size —
            // System Settings switching panes moves its
            // fixed width — so the next retile must probe
            // fresh rather than skip on a dead answer. A
            // size the ledger already predicted is exempt:
            // that is a LATE echo of our own ask (#618's
            // read queue can outlast the applier's grace),
            // and wiping on it erased the learning over and
            // over (device QA, 2026-08-18).
            if tiler.sizeBound(for: id) != nil {
                onLog(
                    "size bound staled by a genuine "
                        + "resize of window \(id.raw)"
                )
            }
            tiler.forgetSizeBound(id)
        }
        // Resize gestures share the drag pipeline (same
        // settle debounce). Only mouse-driven resizes
        // count; a resize nobody asked for — a zoom, an
        // app re-sizing itself — is corrected now (#1358).
        // `validated` lets the trailing events of a fast
        // resize (classified via the recent press near a
        // slot edge) start the gesture even after the
        // release.
        if isResizeGesture(id) {
            drag.windowMoved(
                id,
                frame: frame,
                validated: true,
                previous: preEventFrame
            )
        } else if unsolicited {
            correctUnsolicitedResize(id, frame: frame)
        }
    }
}
