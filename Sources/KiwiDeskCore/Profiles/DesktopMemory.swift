import Foundation

/// Per-display native-Desktop bookkeeping for the switch paths
/// (#888) — a `DeferredTasks`-style satellite so `KiwiCore`'s
/// declaration stays under the file ceiling.
///
/// Both maps key by a display's SkyLight UUID (or the `"main"`
/// sentinel when no UUID resolves — the single-space fallback
/// still keys deterministically). The keying is deliberately
/// mode-independent: with "Displays have separate Spaces" on OR
/// off, an entry is (display, Mission Control number), so the
/// mode flip — which applies at the next login, after which this
/// in-session state starts empty anyway — collapses and expands
/// the keying with no migration in either direction.
@MainActor
final class DesktopMemory {
    /// The KiwiDesk Space each native Desktop showed last,
    /// restored when the main display returns to that Desktop.
    /// Keyed per display so a remembered Space never survives a
    /// change of WHICH screen is main: numbering under a
    /// different main display is a different fact, and reading
    /// it back would activate a Space the user never left there.
    var virtualSpaces: [String: [Int: SpaceID]] = [:]

    /// Each display's current native Space at the last reading —
    /// diffed against the live snapshot to name the display whose
    /// Desktop switched.
    ///
    /// **Seeded at boot** (`KiwiCore+BootSeams`), beside
    /// `lastDesktop`. Left empty, the session's first switch
    /// diffs against nothing, reads every display as changed, and
    /// the main-outranks tiebreak then attributes a secondary
    /// swipe to `monitor: 1` — the field `docs/cli.md` tells
    /// subscribers to key profile-selection off (review,
    /// 2026-08-18).
    var lastDisplaySpaces: [String: SkyLight.SpaceID] = [:]

    /// Seeds the per-display reading without treating it as a
    /// switch. One call site (boot); a switch re-stamps it
    /// through `switchedDisplays(in:)`.
    func seed(_ snapshot: DesktopSnapshot) {
        lastDisplaySpaces = snapshot.currentSpaces
    }
}
