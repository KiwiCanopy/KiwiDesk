import Foundation
import Testing

@testable import KiwiDesk

/// The one-time discovery flag (#331): persisted in
/// `UserDefaults`, isolated here in a scratch suite so the test
/// never touches the real domain.
@Suite("Onboarding discovery flag (#331)")
struct OnboardingDiscoveryTests {
    /// A distinct suite name per test: swift-testing runs the two
    /// cases concurrently, so a shared name would let one's
    /// `markShown` bleed into the other's read. The cleanup
    /// removes the domain *after* the test too — cleaning only
    /// before leaves a plist per suite name in
    /// `~/Library/Preferences` after every run (host residue,
    /// the machine-touch sweep's finding).
    private func scratch(
        _ name: String
    ) -> (defaults: UserDefaults, cleanup: () -> Void) {
        let suite = "org.kiwidesk.discovery.tests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (
            defaults,
            { defaults.removePersistentDomain(forName: suite) }
        )
    }

    @Test("a fresh install has not shown the discovery beat")
    func defaultsUnshown() {
        let (defaults, cleanup) = scratch("unshown")
        defer { cleanup() }
        #expect(!OnboardingDiscovery.hasShown(defaults))
    }

    @Test("markShown persists across reads")
    func marksShown() {
        let (defaults, cleanup) = scratch("marks")
        defer { cleanup() }
        OnboardingDiscovery.markShown(defaults)
        #expect(OnboardingDiscovery.hasShown(defaults))
    }
}
