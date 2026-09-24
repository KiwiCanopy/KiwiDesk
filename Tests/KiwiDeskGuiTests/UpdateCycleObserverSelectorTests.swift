import Sparkle
import Testing

@testable import KiwiDesk

/// `SPUUpdaterDelegate`'s requirements are optional, so a
/// near-miss signature compiles and Sparkle never calls it. The
/// two the update window needs (#1542) are resolved the way
/// Sparkle resolves them, through the ObjC runtime.
@Suite("Update cycle observer answers Sparkle (#1542)")
struct UpdateCycleObserverSelectorTests {
    @Test("the observer answers the appcast and cycle-end selectors")
    func observerAnswersSparkle() {
        for selector in [
            "updater:didFinishLoadingAppcast:",
            "updater:didFinishUpdateCycleForUpdateCheck:error:",
        ] {
            #expect(
                UpdateCycleObserver.instancesRespond(
                    to: NSSelectorFromString(selector)
                ),
                "UpdateCycleObserver does not answer \(selector)"
            )
        }
    }
}
