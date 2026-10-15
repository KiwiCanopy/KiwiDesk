import Foundation
import Testing

@testable import KiwiDeskCore

/// A test core never boots (#2294): `start()` resets the boot
/// latches and then refuses, with an issue, before anything it
/// would re-arm reaches the machine.
@MainActor
@Suite("Test core start tripwire (#2294)")
struct TestCoreStartTripwireTests {
    @Test("a test core's start refuses after its reset")
    func startRefuses() {
        let core = makeTestCore()
        core.boot.reachedReady = true
        core.boot.publishRestore(.placing(placed: 0, total: 1))
        withKnownIssue { core.start() }
        #expect(!core.boot.reachedReady)
        #expect(core.restorePhase == .none)
        #expect(core.bootPhase == .idle)
        #expect(!core.eventLoop.isRunning)
    }

    /// The control: production's default admits the boot.
    @Test("a bare boot run admits its start")
    func productionAdmits() {
        #expect(BootRun().admitsStart())
    }
}
