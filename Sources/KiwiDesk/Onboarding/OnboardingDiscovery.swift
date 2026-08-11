import Foundation

/// One-time gate for the shortcuts discovery page (#331).
///
/// Persisted in `UserDefaults`, NEVER the Accessibility trust
/// state. The wizard itself is gated on `permissions.isTrusted`
/// and reopens on any AX revoke, so gating discovery on trust
/// would re-pitch a user who briefly loses Accessibility months
/// later (a macOS update resets TCC) — which reads as the app
/// forgetting them. A dedicated persisted flag fires the beat
/// exactly once, for the genuine first-run grant.
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
