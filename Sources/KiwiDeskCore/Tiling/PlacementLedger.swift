import CoreGraphics
import Foundation

/// Where KiwiDesk last PUT each window, and when — and when a
/// focus command last LEFT it (#1161). The focus pipeline's
/// placement-echo distrust reads it: some apps answer being
/// placed past a screen edge, or losing focus to our raise, by
/// focusing themselves — the Android Emulator's Qt shell,
/// measured 2026-09-05 at 0.7–1.5 s after either — and that
/// report has the exact shape of a cmd-tab. Age-bounded and
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

    private struct Entry {
        var target: CGRect
        /// When KiwiDesk put the window there, or left it.
        var placed: Date
        /// `placed`, or the last renewal.
        var stamped: Date
        /// When a focus command last moved focus OFF the window;
        /// kept across a later placement, since the pan that
        /// follows a step is what moves the window.
        var displaced: Date?
    }

    private var entries: [WindowID: Entry] = [:]

    /// Records a placement, pruning expired entries so windows
    /// that are placed once and never focused cannot accrete.
    mutating func stamp(
        _ id: WindowID,
        target: CGRect,
        at now: Date = Date()
    ) {
        prune(at: now)
        entries[id] = Entry(
            target: target,
            placed: now,
            stamped: now,
            displaced: entries[id]?.displaced
        )
    }

    /// Records that a focus command moved focus off `id`, which
    /// sat at `frame` — the second event an app answers with a
    /// focus of its own. Restarts the window like a placement.
    mutating func noteDisplaced(
        _ id: WindowID,
        frame: CGRect,
        at now: Date = Date()
    ) {
        prune(at: now)
        entries[id] = Entry(
            target: entries[id]?.target ?? frame,
            placed: now,
            stamped: now,
            displaced: now
        )
    }

    private mutating func prune(at now: Date) {
        entries = entries.filter {
            now.timeIntervalSince($0.value.stamped) < Self.echoWindow
        }
    }

    /// Extends a live entry's window from `now` — a distrust is
    /// proof the app is still reacting — but only while the
    /// PLACEMENT itself is younger than the window, so a chain
    /// of renewals ends at most `2 × echoWindow` after KiwiDesk
    /// last placed the window, whoever caused the reports
    /// (#1161, `PlacementLedgerTests`).
    mutating func renew(_ id: WindowID, at now: Date = Date()) {
        guard let entry = entries[id],
            now.timeIntervalSince(entry.placed) < Self.echoWindow
        else { return }
        entries[id].map { _ in entries[id]?.stamped = now }
    }

    /// Whether a focus command moved focus off `id` inside its
    /// live window — the displacement itself no older than the
    /// renewal ceiling.
    func recentDisplacement(
        _ id: WindowID,
        at now: Date = Date()
    ) -> Bool {
        guard let entry = entries[id],
            let displaced = entry.displaced,
            now.timeIntervalSince(entry.stamped) < Self.echoWindow
        else { return false }
        return now.timeIntervalSince(displaced) < 2 * Self.echoWindow
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
