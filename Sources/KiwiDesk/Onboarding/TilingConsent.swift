import Foundation

/// Whether the user has asked KiwiDesk to start tiling (#2050).
///
/// Three states: an explicit `false` is a first run that has not
/// pressed Start Tiling; an absent key is an install from before
/// the gate, which counts as started once trusted.
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

    /// Settles the state at launch. A finished tour or a granted
    /// permission marks an install from before the gate; anything
    /// else is a first run, which waits for Start Tiling.
    static func seedAtLaunch(
        isTrusted: Bool,
        _ defaults: UserDefaults = .standard
    ) {
        guard defaults.object(forKey: key) == nil else { return }
        defaults.set(
            isTrusted || OnboardingDiscovery.hasShown(defaults),
            forKey: key
        )
    }

    /// Records the press; every later launch and re-grant starts
    /// on its own.
    static func markStarted(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }
}

/// Why window management is not running, if it is not — the one
/// value every surface narrating it reads (#2050).
enum CoreHold: Equatable {
    case running
    /// Accessibility is missing.
    case permissionMissing
    /// Granted, but Start Tiling was never pressed.
    case notStarted

    static func of(isTrusted: Bool, hasStarted: Bool) -> CoreHold {
        guard isTrusted else { return .permissionMissing }
        return hasStarted ? .running : .notStarted
    }
}
