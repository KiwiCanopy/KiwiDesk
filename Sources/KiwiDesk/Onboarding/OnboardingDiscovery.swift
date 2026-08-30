import Foundation

/// One-time UserDefaults gate for the shortcuts discovery page (#331).
/// Persisted separately from AX trust so revoke/re-grant does not repeat it.
enum OnboardingDiscovery {
    static let key = "onboarding.discoveryShown"

    /// Whether the discovery beat has already been shown.
    static func hasShown(
        _ defaults: UserDefaults = .standard
    ) -> Bool {
        defaults.bool(forKey: key)
    }

    /// A trusted launch resumes discovery when permission was
    /// granted but the first-run window closed before this page.
    static func shouldResume(
        isTrusted: Bool,
        _ defaults: UserDefaults = .standard
    ) -> Bool {
        isTrusted && !hasShown(defaults)
    }

    /// Records that the beat ran, so it never repeats.
    static func markShown(
        _ defaults: UserDefaults = .standard
    ) {
        defaults.set(true, forKey: key)
    }
}
