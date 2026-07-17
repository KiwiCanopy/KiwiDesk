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
    /// `markShown` bleed into the other's read.
    private func scratch(_ name: String) -> UserDefaults {
        let suite = "org.kiwidesk.discovery.tests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("a fresh install has not shown the discovery beat")
    func defaultsUnshown() {
        #expect(!OnboardingDiscovery.hasShown(scratch("unshown")))
    }

    @Test("markShown persists across reads")
    func marksShown() {
        let defaults = scratch("marks")
        OnboardingDiscovery.markShown(defaults)
        #expect(OnboardingDiscovery.hasShown(defaults))
    }
}
