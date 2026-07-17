import Testing

@testable import KiwiDeskCore

/// The pure decision behind `service start` (#341): a loaded-but-
/// idle job (registered, no pid — the state a quick-menu Quit
/// leaves behind) must be relaunched, not reported as already
/// running. The launchctl calls themselves mutate real launchd
/// state and aren't exercised here.
@Suite("Service start decision")
struct ServiceStartActionTests {
    @Test("Not loaded → bootstrap")
    func notLoaded() {
        #expect(
            ServiceManager.startAction(loaded: false, pid: nil)
                == .bootstrap
        )
        // A stray pid without a loaded job is still not loaded.
        #expect(
            ServiceManager.startAction(loaded: false, pid: 42)
                == .bootstrap
        )
    }

    @Test("Loaded with a running process → already running")
    func loadedRunning() {
        #expect(
            ServiceManager.startAction(loaded: true, pid: 4271)
                == .alreadyRunning
        )
    }

    @Test("Loaded but idle → kickstart (the quit-then-start case)")
    func loadedIdle() {
        #expect(
            ServiceManager.startAction(loaded: true, pid: nil)
                == .kickstart
        )
    }
}
