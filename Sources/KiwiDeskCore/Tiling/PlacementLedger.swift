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
/// stash and every App-level placer stamp alike, and RENEWED —
/// never re-stamped — by a distrust through `renew`, which ends
/// at a ceiling measured from the placement itself. A fifth record
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

    /// `placed` is when KiwiDesk put the window there; `stamped`
    /// is that, or the last renewal.
    private var entries:
        [WindowID: (target: CGRect, placed: Date, stamped: Date)] =
            [:]

    /// Records a placement, pruning expired entries so windows
    /// that are placed once and never focused cannot accrete.
    mutating func stamp(
        _ id: WindowID,
        target: CGRect,
        at now: Date = Date()
    ) {
        entries = entries.filter {
            now.timeIntervalSince($0.value.stamped) < Self.echoWindow
        }
        entries[id] = (target, now, now)
    }

    /// Extends a live entry's window from `now` — a distrust is
    /// proof the app is still reacting — but only while the
    /// PLACEMENT itself is younger than the window, so a chain
    /// of renewals ends at most `2 × echoWindow` after KiwiDesk
    /// last placed the window, whoever caused the reports
    /// (#1161, `PlacementLedgerTests`).
    mutating func renew(_ id: WindowID, at now: Date = Date()) {
        guard let entry = entries[id],
            now.timeIntervalSince(entry.stamped) < Self.echoWindow,
            now.timeIntervalSince(entry.placed) < Self.echoWindow
        else { return }
        entries[id] = (entry.target, entry.placed, now)
    }

    /// The frame KiwiDesk gave `id` within the echo window of its
    /// placement or last renewal, nil once past it. Read, never
    /// consumed.
    func recent(_ id: WindowID, at now: Date = Date()) -> CGRect? {
        guard let entry = entries[id],
            now.timeIntervalSince(entry.stamped) < Self.echoWindow
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
