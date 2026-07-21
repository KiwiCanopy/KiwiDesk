import Foundation

/// Keeps floating windows above the tiled plane by pinning their
/// window-server level (#418). A floating window inherently sits
/// "above tiled" — clicking or cmd-tabbing to a tiled window would
/// otherwise raise it over the float via macOS's own stacking. The
/// SkyLight level survives focus changes (the window server enforces
/// it), so nothing needs re-raising per focus event on this path.
///
/// The gate is `isFloating` alone (#418 tier model): a tiled-sticky
/// window is a normal layout participant (#414 v2) and must stay on
/// the tiled plane — never promoted.
extension KiwiCore {
    /// Reconciles every managed window's level to its float state,
    /// issuing SkyLight calls only for the delta since the last
    /// pass. Called from `retile()`, the convergence point every
    /// float change routes through (command, detection, float rule,
    /// create, remembered-override restore). A no-op when the fast
    /// path is unavailable — the AX re-raise fallback covers that
    /// case (`raiseFloatsIfFallback`).
    func enforceFloatLevels() {
        guard WindowLevel.isAvailable else { return }
        let floating = Set(
            state.windows.all
                .filter(\.isFloating)
                .map(\.id)
        )
        for id in floating.subtracting(floatLevelPromoted) {
            WindowLevel.set(WindowLevel.floating, of: id.raw)
        }
        // A window that turned tiled is restored to the normal
        // level; one that left (destroyed, untracked) no longer
        // exists at the server, so the same demote is a harmless
        // no-op. Either way it drops out of the promoted set.
        for id in floatLevelPromoted.subtracting(floating) {
            WindowLevel.set(WindowLevel.normal, of: id.raw)
        }
        floatLevelPromoted = floating
    }
}
