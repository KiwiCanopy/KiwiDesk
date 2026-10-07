import Foundation

/// Whether the user has asked KiwiDesk to start tiling (#2050).
///
/// Three states, not two: an explicit `false` is a first run
/// that has not pressed Start Tiling yet, while an ABSENT key
/// with Accessibility already granted is an install from before
/// the gate, which counts as started. A two-state flag would read
/// a first run that granted, closed the tour and relaunched as
/// one of those, and tile without asking — the #2050 report.
enum TilingConsent {
    static let key = "onboarding.tilingStarted"

    /// Whether this launch may start managing windows.
    static func hasStarted(
        isTrusted: Bool,
        _ defaults: UserDefaults = .standard
    ) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return isTrusted
        }
        return defaults.bool(forKey: key)
    }

    /// Settles the state at launch: a fresh install without the
    /// permission records `false`, so a later grant waits for
    /// Start Tiling; a trusted one predates the gate.
    static func seedAtLaunch(
        isTrusted: Bool,
        _ defaults: UserDefaults = .standard
    ) {
        guard defaults.object(forKey: key) == nil else { return }
        defaults.set(isTrusted, forKey: key)
    }

    /// Records the press; every later launch and re-grant starts
    /// on its own.
    static func markStarted(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }
}
