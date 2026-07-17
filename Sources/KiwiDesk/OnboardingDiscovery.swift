import Foundation

/// One-time gate for the post-setup discovery beat (#331): the
/// "you're ready" wizard card plus the menu-bar "look here"
/// popover, both keyed off this single flag.
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

    /// Records that the beat ran, so it never repeats.
    static func markShown(
        _ defaults: UserDefaults = .standard
    ) {
        defaults.set(true, forKey: key)
    }
}
