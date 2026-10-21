import Foundation
import Testing

@testable import KiwiDesk

/// The one-time discovery flag (#331): persisted in
/// `UserDefaults`, isolated here in a scratch suite so the test
/// never touches the real domain.
@Suite("Onboarding discovery flag (#331)")
struct OnboardingDiscoveryTests {
    /// A distinct domain per test: swift-testing runs the cases
    /// concurrently, so a shared one would let one's `markShown`
    /// bleed into the other's read. `name` labels the call only.
    private func scratch(
        _ name: String
    ) -> (defaults: UserDefaults, cleanup: () -> Void) {
        let (defaults, suite) = makeScratchDefaults()
        return (defaults, { TestScratch.remove(suite) })
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

    @Test("trusted launch resumes unfinished discovery")
    func resumesOnlyWhenTrustedAndPending() {
        let (defaults, cleanup) = scratch("resume")
        defer { cleanup() }

        #expect(
            OnboardingDiscovery.shouldResume(
                isTrusted: true,
                defaults
            )
        )
        #expect(
            !OnboardingDiscovery.shouldResume(
                isTrusted: false,
                defaults
            )
        )
        OnboardingDiscovery.markShown(defaults)
        #expect(
            !OnboardingDiscovery.shouldResume(
                isTrusted: true,
                defaults
            )
        )
    }
}
