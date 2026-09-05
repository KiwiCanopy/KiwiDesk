import CoreGraphics
import Foundation

/// Where KiwiDesk last PUT each window, and when (#1161). The
/// focus pipeline's placement-echo distrust reads it: some apps
/// answer being placed past a screen edge by clamping themselves
/// back and focusing themselves — the Android Emulator's Qt
/// shell, measured 2026-09-05 at 0.8–1.5 s after the pan — and
/// that report has the exact shape of a cmd-tab. Age-bounded and
/// never consumed, like every echo ledger (state-and-layout.md);
/// written at the two leaves every placement goes through
/// (`TilingEngine.applyFrame` / `setFrame`), so the retile, the
/// stash and every App-level placer stamp alike. A fifth record
/// of "where we put it" beside `InstantTargets` (cleared on the
/// first echo), the animation's target (dead at the settle), the
/// glide base and the learner's asks — kept because none of them
/// LIVES long enough: the bounce lands after every one of them
/// has retired, so merging this into any of them silently kills
/// the distrust.
struct PlacementLedger {
    /// How long after a placement a clickless focus of that
    /// window may still be the app's reaction to it. Sized past
    /// the measured 0.8–1.5 s with margin; a genuine cmd-tab
    /// onto a just-moved window inside it is the documented
    /// trade (accepted-limitations.md).
    static let echoWindow: TimeInterval = 2.0

    private var entries: [WindowID: (target: CGRect, at: Date)] =
        [:]

    /// Records a placement, pruning expired entries so windows
    /// that are placed once and never focused cannot accrete.
    mutating func stamp(
        _ id: WindowID,
        target: CGRect,
        at now: Date = Date()
    ) {
        entries = entries.filter {
            now.timeIntervalSince($0.value.at) < Self.echoWindow
        }
        entries[id] = (target, now)
    }

    /// The frame KiwiDesk gave `id` within the echo window, nil
    /// once past it. Read, never consumed.
    func recent(_ id: WindowID, at now: Date = Date()) -> CGRect? {
        guard let entry = entries[id],
            now.timeIntervalSince(entry.at) < Self.echoWindow
        else { return nil }
        return entry.target
    }

    /// Ids are reused: a gone window's placement must not reach
    /// the id's next tenant.
    mutating func forget(_ id: WindowID) {
        entries[id] = nil
    }

    /// Follows a native-tab re-key (#308).
    mutating func rekey(old: WindowID, new: WindowID) {
        guard let entry = entries.removeValue(forKey: old) else {
            return
        }
        entries[new] = entry
    }
}
