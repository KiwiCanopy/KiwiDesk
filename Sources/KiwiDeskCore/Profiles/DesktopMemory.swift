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

    /// Each display's current native Space at the last
    /// `native_space_change` emit — diffed against the live
    /// snapshot to name the display whose Desktop switched.
    var lastDisplaySpaces: [String: SkyLight.SpaceID] = [:]
}
